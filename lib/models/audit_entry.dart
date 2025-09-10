class AuditEntry {
  final String id;
  final String actorId;
  final String action;
  final String resourceType;
  final String resourceId;
  final Map<String, dynamic>? dataDiff;
  final DateTime timestamp;

  AuditEntry({
    required this.id,
    required this.actorId,
    required this.action,
    required this.resourceType,
    required this.resourceId,
    this.dataDiff,
    required this.timestamp,
  });
}
