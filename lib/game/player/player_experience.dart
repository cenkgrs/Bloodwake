/// Tracks collected XP and level. Plain data holder, not a Flame component
/// — nothing needs to run per-frame here.
class PlayerExperience {
  int level = 1;
  int totalXp = 0;
  int xpIntoLevel = 0;

  /// XP needed to go from the current [level] to the next one. Linear on
  /// purpose — a prototype doesn't need a tuned curve yet, just a working
  /// one.
  int get xpRequiredForNextLevel => 20 + (level - 1) * 15;

  /// Adds XP and returns how many levels were gained (usually 0 or 1; more
  /// if a single big XP gain crosses several thresholds at once). The
  /// caller decides what a level-up means — this class only tracks numbers.
  int addXp(int amount) {
    totalXp += amount;
    xpIntoLevel += amount;
    var levelsGained = 0;
    while (xpIntoLevel >= xpRequiredForNextLevel) {
      xpIntoLevel -= xpRequiredForNextLevel;
      level++;
      levelsGained++;
    }
    return levelsGained;
  }
}
