import 'package:flame/components.dart';

class GameConstants {
  GameConstants._();

  static final Vector2 arenaSize = Vector2(2400, 2400);

  static const double playerRadius = 18;
  static const double playerBaseMoveSpeed = 220;

  /// Max simultaneously-owned weapons. Once reached, weapon-unlock upgrades
  /// stop being offered — see UpgradeCatalog's unlock entries.
  static const int maxWeaponSlots = 4;

  /// Max items the shop will sell one run. Currently equal to the item
  /// catalog's size — raise this if the catalog grows past it.
  static const int maxItemSlots = 8;
}
