class Pricing {
  // Tiers sourced from provided image (SA -> Lesotho prices)
  // Returns charge in R (or relevant currency). For amounts >=10000 returns percent (4%) as amount*0.04
  static double getCharge(double amount) {
    final a = amount;
    if (a < 0) return 0.0;
    if (a <= 499) return 30.0;
    if (a <= 999) return 50.0;
    if (a <= 1499) return 60.0;
    if (a <= 1999) return 70.0;
    if (a <= 2499) return 90.0;
    if (a <= 2999) return 100.0;
    if (a <= 3499) return 110.0;
    if (a <= 3999) return 120.0;
    if (a <= 4499) return 130.0;
    if (a <= 4999) return 140.0;
    if (a <= 5499) return 160.0;
    if (a <= 5999) return 170.0;
    if (a <= 6499) return 180.0;
    if (a <= 6999) return 190.0;
    if (a <= 7499) return 220.0;
    if (a <= 7999) return 230.0;
    if (a <= 8499) return 250.0;
    if (a <= 8999) return 260.0;
    if (a <= 9499) return 280.0;
    if (a <= 9999) return 290.0;
    // 10,000 and above -> 4%
    return a * 0.04;
  }
}
