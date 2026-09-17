$ErrorActionPreference = 'Stop'
$root = (Resolve-Path '.').Path
$source = Join-Path $root 'art/warrior/preview/motion'
$target = Join-Path $root 'assets/images/characters/warrior_rig_test'
foreach ($state in @('idle', 'run', 'sword_attack', 'recievehit', 'death')) {
  $destination = Join-Path $target $state
  New-Item -ItemType Directory -Path $destination -Force | Out-Null
  Copy-Item -Path (Join-Path $source $state '*.png') -Destination $destination -Force
}

$animatorPath = Join-Path $root 'lib/game/player/character_sprite_animator.dart'
$text = [System.IO.File]::ReadAllText($animatorPath)
if ($text.Contains('warrior_rig_test')) { throw 'Rig test is already installed.' }
$text = $text.Replace('  double _hitTimer = 0;', '  double _hitTimer = 0;' + "`r`n" + '  double _attackTimer = 0;')
$text = $text.Replace('    final folder = characterClass.spriteFolder;', @'
    if (characterClass.id == CharacterClass.warrior) {
      const testFolder = 'assets/images/characters/warrior_rig_test';
      animations = {
        _CharAnimState.idle: await _loadRigAnimation('$testFolder/idle', 6, 0.11),
        _CharAnimState.run: await _loadRigAnimation('$testFolder/run', 8, 0.075),
        _CharAnimState.attack: await _loadRigAnimation('$testFolder/sword_attack', 8, 0.075, loop: false),
        _CharAnimState.hit: await _loadRigAnimation('$testFolder/recievehit', 6, 0.06, loop: false),
        _CharAnimState.death: await _loadRigAnimation('$testFolder/death', 8, 0.12, loop: false),
      };
      current = _CharAnimState.idle;
      return;
    }
    final folder = characterClass.spriteFolder;
'@.TrimEnd())
$loader = @'
  Future<SpriteAnimation> _loadRigAnimation(
    String folder,
    int frameCount,
    double stepTime, {
    bool loop = true,
  }) async {
    final sprites = await Future.wait(List.generate(frameCount, (index) async {
      final bytes = await rootBundle.load('$folder/${index.toString().padLeft(2, '0')}.png');
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return Sprite(frame.image);
    }));
    return SpriteAnimation.spriteList(sprites, stepTime: stepTime, loop: loop);
  }

'@
$text = $text.Replace('  Future<SpriteAnimation> _loadAnimation(', $loader + '  Future<SpriteAnimation> _loadAnimation(')
$text = $text.Replace('  void triggerAttack() {}', @'
  void triggerAttack() {
    if (characterClass.id == CharacterClass.warrior && _attackTimer <= 0) {
      _attackTimer = 8 * 0.075;
    }
  }
'@.TrimEnd())
$text = $text.Replace('    final position = parent.position;', @'
    if (_attackTimer > 0) {
      _attackTimer -= dt;
      current = _CharAnimState.attack;
      _applyFacing();
      return;
    }

    final position = parent.position;
'@.TrimEnd())
if (-not $text.Contains('Future<SpriteAnimation> _loadRigAnimation(')) { throw 'Animator patch failed.' }
[System.IO.File]::WriteAllText($animatorPath, $text)

$pubspecPath = Join-Path $root 'pubspec.yaml'
$pubspec = [System.IO.File]::ReadAllText($pubspecPath)
$line = '    - assets/images/characters/warrior/'
if (-not $pubspec.Contains('warrior_rig_test')) {
  $assetLines = @('idle','run','sword_attack','recievehit','death') | ForEach-Object { "    - assets/images/characters/warrior_rig_test/$_/" }
  $added = $line + "`r`n" + ($assetLines -join "`r`n")
  $pubspec = $pubspec.Replace($line, $added)
  [System.IO.File]::WriteAllText($pubspecPath, $pubspec)
}
Write-Output 'Warrior rig test installed.'
