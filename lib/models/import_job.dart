class ImportJob {
  final String id;
  final String fileName;
  final String recordType;
  final int totalRows;
  final int processed;
  final List<Map<String, dynamic>> errors;
  final String status;
  final DateTime startedAt;
  final DateTime? finishedAt;

  ImportJob({
    required this.id,
    required this.fileName,
    required this.recordType,
    required this.totalRows,
    required this.processed,
    required this.errors,
    this.status = 'pending',
    required this.startedAt,
    this.finishedAt,
  });
}
