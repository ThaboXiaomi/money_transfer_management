class SettlementBatch {
  final String id;
  final List<int> transferIds;
  final double totalAmount;
  final String currency;
  final String status;
  final DateTime createdAt;
  final DateTime? settledAt;
  final String? reconciledBy;

  SettlementBatch({
    required this.id,
    required this.transferIds,
    required this.totalAmount,
    required this.currency,
    this.status = 'pending',
    required this.createdAt,
    this.settledAt,
    this.reconciledBy,
  });
}
