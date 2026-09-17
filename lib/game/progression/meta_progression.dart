import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../player/player_stats.dart';
import 'equipment_catalog.dart';
import 'skill_tree.dart';

class MetaProgression extends ChangeNotifier {
  MetaProgression._();
  MetaProgression.inMemory();
  MetaProgression.forFile(File file) : _saveFile = file;
  static final instance = MetaProgression._();

  int essence = 0;
  final Map<String, int> _levels = {};
  final Set<String> _ownedEquipment = {};
  final List<Map<EquipmentSlot, String>> _loadouts = List.generate(
    3,
    (_) => {},
  );
  int activeLoadout = 0;
  File? _saveFile;
  Future<void> _saveQueue = Future<void>.value();

  int levelOf(SkillNode node) => _levels[node.id] ?? 0;
  bool ownsEquipment(EquipmentData item) => _ownedEquipment.contains(item.id);
  String? equippedId(EquipmentSlot slot, {int? loadout}) =>
      _loadouts[loadout ?? activeLoadout][slot];
  EquipmentData? equipped(EquipmentSlot slot, {int? loadout}) {
    final id = equippedId(slot, loadout: loadout);
    return id == null ? null : EquipmentCatalog.byId(id);
  }

  List<EquipmentData> ownedFor(EquipmentSlot slot) => EquipmentCatalog.all
      .where((item) => item.slot == slot && ownsEquipment(item))
      .toList();

  Future<bool> buyEquipment(EquipmentData item) async {
    if (ownsEquipment(item) || essence < item.cost) return false;
    essence -= item.cost;
    _ownedEquipment.add(item.id);
    notifyListeners();
    await _save();
    return true;
  }

  Future<bool> equip(EquipmentSlot slot, String? itemId, {int? loadout}) async {
    final index = loadout ?? activeLoadout;
    if (index < 0 || index >= _loadouts.length) return false;
    if (itemId != null) {
      final item = EquipmentCatalog.byId(itemId);
      if (item == null || item.slot != slot || !ownsEquipment(item)) {
        return false;
      }
      _loadouts[index][slot] = itemId;
    } else {
      _loadouts[index].remove(slot);
    }
    notifyListeners();
    await _save();
    return true;
  }

  Future<void> selectLoadout(int index) async {
    if (index < 0 || index >= _loadouts.length) return;
    activeLoadout = index;
    notifyListeners();
    await _save();
  }

  bool canBuy(SkillNode node) {
    final level = levelOf(node);
    if (level >= SkillNode.maxLevel || essence < node.costForLevel(level)) {
      return false;
    }
    final prerequisite = node.requires;
    return prerequisite == null || (_levels[prerequisite] ?? 0) > 0;
  }

  Future<void> load() async {
    try {
      if (_saveFile == null) {
        final directory = await getApplicationSupportDirectory();
        _saveFile = File('${directory.path}/bloodwake_progression.json');
      }
      if (!await _saveFile!.exists()) return;
      final decoded =
          jsonDecode(await _saveFile!.readAsString()) as Map<String, dynamic>;
      essence = ((decoded['essence'] as num?)?.toInt() ?? 0).clamp(
        0,
        1000000000,
      );
      final savedLevels = decoded['levels'] as Map<String, dynamic>? ?? {};
      _levels.clear();
      for (final node in SkillTree.nodes) {
        final value = (savedLevels[node.id] as num?)?.toInt() ?? 0;
        _levels[node.id] = value.clamp(0, SkillNode.maxLevel);
      }
      _ownedEquipment.clear();
      for (final id in (decoded['ownedEquipment'] as List<dynamic>? ?? [])) {
        if (id is String && EquipmentCatalog.byId(id) != null) {
          _ownedEquipment.add(id);
        }
      }
      for (final loadout in _loadouts) {
        loadout.clear();
      }
      final savedLoadouts = decoded['loadouts'] as List<dynamic>? ?? [];
      for (var i = 0; i < savedLoadouts.length && i < _loadouts.length; i++) {
        final entries = savedLoadouts[i];
        if (entries is! Map) continue;
        for (final slot in EquipmentSlot.values) {
          final id = entries[slot.name];
          final item = id is String ? EquipmentCatalog.byId(id) : null;
          if (item != null && item.slot == slot && ownsEquipment(item)) {
            _loadouts[i][slot] = id as String;
          }
        }
      }
      activeLoadout = ((decoded['activeLoadout'] as num?)?.toInt() ?? 0).clamp(
        0,
        _loadouts.length - 1,
      );
      notifyListeners();
    } catch (_) {
      // A missing or damaged local save starts fresh without blocking play.
    }
  }

  Future<bool> buy(SkillNode node) async {
    if (!canBuy(node)) return false;
    final level = levelOf(node);
    essence -= node.costForLevel(level);
    _levels[node.id] = level + 1;
    notifyListeners();
    await _save();
    return true;
  }

  int rewardForRun({required int wave, required int kills}) =>
      (wave * 2 + kills ~/ 5).clamp(2, 100000);

  Future<int> awardRun({required int wave, required int kills}) async {
    final reward = rewardForRun(wave: wave, kills: kills);
    essence += reward;
    notifyListeners();
    await _save();
    return reward;
  }

  void applyTo(PlayerStats stats) {
    for (final node in SkillTree.nodes) {
      final level = levelOf(node);
      if (level > 0) node.apply(stats, level);
    }
    for (final slot in EquipmentSlot.values) {
      equipped(slot)?.apply(stats);
    }
  }

  Future<void> _save() {
    final file = _saveFile;
    if (file == null) return Future<void>.value();
    _saveQueue = _saveQueue.then((_) async {
      try {
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsString(
          jsonEncode({
            'essence': essence,
            'levels': _levels,
            'ownedEquipment': _ownedEquipment.toList(),
            'loadouts': _loadouts
                .map(
                  (loadout) => {
                    for (final entry in loadout.entries)
                      entry.key.name: entry.value,
                  },
                )
                .toList(),
            'activeLoadout': activeLoadout,
          }),
          flush: true,
        );
        await temporary.rename(file.path);
      } catch (_) {
        // Keep the in-memory state and retry writing on the next change.
      }
    });
    return _saveQueue;
  }
}
