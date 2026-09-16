import 'package:flame/game.dart';
import 'package:flutter/widgets.dart' show EdgeInsets;

import '../core/constants/game_constants.dart';
import '../input/mobile/mobile_input_provider.dart';
import '../input/mobile/skill_button_component.dart';
import 'abilities/ability_data.dart';
import 'arena/arena_component.dart';
import 'hud/boss_health_bar.dart';
import 'hud/hud_component.dart';
import 'items/item_data.dart';
import 'items/item_shop_roller.dart';
import 'player/character_class.dart';
import 'player/player.dart';
import 'spawning/spawn_director.dart';
import 'systems/audio/sfx_player.dart';
import 'systems/effects/camera_shaker.dart';
import 'upgrades/upgrade_data.dart';
import 'upgrades/upgrade_roller.dart';
import 'waves/wave_manager.dart';

/// Root game instance: arena, joystick-controlled player, camera-follow,
/// collision detection, wave-driven enemy spawning, and the HUD/game-over/
/// level-up/shop overlay hooks.
///
/// Level-ups no longer interrupt combat: XP keeps accumulating mid-wave,
/// and pending level-up choices only get shown once the wave clears,
/// immediately followed by the shop — both during the same breather that
/// already existed for pacing (see WaveManager.onWaveCleared). This keeps
/// a wave itself uninterrupted while still giving the player a real,
/// unhurried decision point between waves.
class RoughlikeGame extends FlameGame with HasCollisionDetection {
  RoughlikeGame({
    required this.characterClass,
    this.topInset = 0,
    this.bottomInset = 0,
  });

  final CharacterClassData characterClass;

  /// Device safe-area insets (status bar / gesture-nav strip), in logical
  /// pixels — passed in from GameScreen since the game canvas renders
  /// full-bleed (no ambient SafeArea) so wave-end overlay backgrounds can
  /// cover true edge-to-edge instead of stopping short and showing the
  /// arena in the gap. Screen-fixed HUD elements (joystick, skill button,
  /// HUD text, boss bar) add these back in themselves.
  final double topInset;
  final double bottomInset;

  late final Player player;
  late final MobileInputProvider inputProvider;
  late final WaveManager waveManager;
  final CameraShaker _cameraShaker = CameraShaker();

  int killCount = 0;

  void shakeCamera({double intensity = 6, double duration = 0.2}) {
    _cameraShaker.shake(intensity: intensity, duration: duration);
  }
  int _pendingLevelUps = 0;
  List<UpgradeData> currentUpgradeChoices = const [];
  List<ItemData> currentShopOffers = const [];

  /// One free reroll per level-up screen (resets each time a new choice
  /// set is presented, including the next pick in a stacked multi-level-up).
  static const int maxLevelUpRerolls = 1;
  int levelUpRerollsUsed = 0;

  /// Limited, gold-costed shop reroll — resets each time the shop opens.
  static const int maxShopRefreshes = 3;
  static const int shopRefreshCost = 20;
  int shopRefreshesUsed = 0;

  void registerKill() => killCount++;

  void onPlayerDeath() {
    _pendingLevelUps = 0;
    overlays.remove('levelUp');
    overlays.remove('shop');
    pauseEngine();
    overlays.add('gameOver');
    SfxPlayer.gameOver();
  }

  /// Called by Player once PlayerExperience reports one or more levels
  /// gained. No pause here — the run keeps going; the choice is presented
  /// once the wave clears (see [_onWaveCleared]).
  void onLevelUp(int count) {
    if (count > 0) {
      _pendingLevelUps += count;
    }
  }

  /// WaveManager.onWaveCleared hook: the wave just fully cleared and
  /// entered its breather. Pause and present whatever's pending — level-ups
  /// first (one at a time if several stacked up), then the shop.
  void _onWaveCleared() {
    pauseEngine();
    if (_pendingLevelUps > 0) {
      _presentNextLevelUp();
    } else {
      _presentShop();
    }
  }

  void _presentNextLevelUp() {
    levelUpRerollsUsed = 0;
    currentUpgradeChoices = rollUpgradeChoices(player);
    if (currentUpgradeChoices.isEmpty) {
      // Nothing left to offer (catalog exhausted) — consume silently
      // instead of showing an empty choice screen.
      _pendingLevelUps = _pendingLevelUps > 0 ? _pendingLevelUps - 1 : 0;
      if (_pendingLevelUps > 0) {
        _presentNextLevelUp();
      } else {
        _presentShop();
      }
      return;
    }
    overlays.add('levelUp');
    SfxPlayer.levelUp();
  }

  /// Consumes the level-up screen's one free reroll, if any is left.
  void rerollLevelUpChoices() {
    if (levelUpRerollsUsed >= maxLevelUpRerolls) {
      return;
    }
    levelUpRerollsUsed++;
    currentUpgradeChoices = rollUpgradeChoices(player);
  }

  void chooseUpgrade(UpgradeData upgrade) {
    player.upgrades.apply(upgrade, player);
    overlays.remove('levelUp');
    SfxPlayer.upgradePick();
    _pendingLevelUps = _pendingLevelUps > 0 ? _pendingLevelUps - 1 : 0;
    if (_pendingLevelUps > 0) {
      _presentNextLevelUp();
    } else {
      _presentShop();
    }
  }

  void _presentShop() {
    shopRefreshesUsed = 0;
    currentShopOffers = rollShopOffers(player);
    overlays.add('shop');
  }

  /// Spends [shopRefreshCost] gold to reroll the current offers, up to
  /// [maxShopRefreshes] times per visit. No-ops (silently) once gold or
  /// refreshes run out — the button just goes disabled, see ShopOverlay.
  void refreshShop() {
    if (shopRefreshesUsed >= maxShopRefreshes || !player.currency.spend(shopRefreshCost)) {
      return;
    }
    shopRefreshesUsed++;
    currentShopOffers = rollShopOffers(player);
  }

  void closeShop() {
    overlays.remove('shop');
    resumeEngine();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final arena = ArenaComponent();
    world.add(arena);

    inputProvider = MobileInputProvider();

    player = Player(
      position: GameConstants.arenaSize / 2,
      inputProvider: inputProvider,
      arenaSize: GameConstants.arenaSize,
      characterClass: characterClass,
      ability: AbilityCatalog.spearThrow,
    );
    world.add(player);

    waveManager = WaveManager(onWaveCleared: _onWaveCleared);
    world.add(waveManager);
    world.add(
      SpawnDirector(waveManager: waveManager, arenaSize: GameConstants.arenaSize),
    );

    camera.follow(player);
    camera.viewfinder.add(_cameraShaker);
    inputProvider.joystick.margin = EdgeInsets.only(left: 36, bottom: 36 + bottomInset);
    camera.viewport.add(inputProvider.joystick);
    camera.viewport.add(
      SkillButtonComponent(
        onActivate: player.abilities.activate,
        fallbackDirection: () => player.facingDirection,
        margin: EdgeInsets.only(right: 36, bottom: 36 + bottomInset),
      ),
    );
    camera.viewport.add(HudComponent(topInset: topInset));
    camera.viewport.add(BossHealthBar(topInset: topInset));
  }
}
