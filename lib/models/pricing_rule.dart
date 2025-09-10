class PricingRule {
  final String id;
  final List<String> countries;
  final double minAmount;
  final double maxAmount;
  final String feeType; // 'fixed' or 'percent'
  final double feeAmount;
  final bool active;
  final int priority;

  PricingRule({
    required this.id,
    required this.countries,
    required this.minAmount,
    required this.maxAmount,
    required this.feeType,
    required this.feeAmount,
    this.active = true,
    this.priority = 0,
  });
}
