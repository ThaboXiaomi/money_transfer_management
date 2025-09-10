class DashboardSummary {
  final int totalTransfers;
  final int pending;
  final int completed;
  final double totalVolume;
  final double totalFees;
  final DateTime since;

  DashboardSummary({
    required this.totalTransfers,
    required this.pending,
    required this.completed,
    required this.totalVolume,
    required this.totalFees,
    required this.since,
  });
}
