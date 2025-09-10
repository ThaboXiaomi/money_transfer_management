class KYCRecord {
  final String id;
  final String userId;
  final List<Map<String, String>> documents; // [{type,url}]
  final String status; // pending/approved/rejected
  final String? reviewerId;
  final DateTime? reviewedAt;
  final String? notes;

  KYCRecord({
    required this.id,
    required this.userId,
    required this.documents,
    this.status = 'pending',
    this.reviewerId,
    this.reviewedAt,
    this.notes,
  });
}
