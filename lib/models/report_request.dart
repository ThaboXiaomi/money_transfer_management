class ReportRequest {
  final String id;
  final String userId;
  final String type;
  final Map<String, dynamic>? filters;
  final String status;
  final String? fileUrl;
  final DateTime requestedAt;
  final DateTime? completedAt;

  ReportRequest({
    required this.id,
    required this.userId,
    required this.type,
    this.filters,
    this.status = 'pending',
    this.fileUrl,
    required this.requestedAt,
    this.completedAt,
  });
}
