class Refund {
  final String id;
  final int transferId;
  final double amount;
  final String reason;
  final String status;
  final String initiatedBy;
  final DateTime? processedAt;

  Refund({
    required this.id,
    required this.transferId,
    required this.amount,
    required this.reason,
    this.status = 'pending',
    required this.initiatedBy,
    this.processedAt,
  });
}
