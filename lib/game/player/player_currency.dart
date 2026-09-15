/// Run-scoped gold, earned from EnemyData.goldReward on kill and spent in
/// the wave-end shop. Plain data holder, same pattern as PlayerExperience —
/// resets with the run, unlike a future cross-run meta-currency.
class PlayerCurrency {
  int gold = 0;

  void add(int amount) => gold += amount;

  bool spend(int amount) {
    if (amount > gold) {
      return false;
    }
    gold -= amount;
    return true;
  }
}
