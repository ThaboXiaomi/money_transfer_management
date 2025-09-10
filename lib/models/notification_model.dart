class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final String priority;
  final bool read;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.type = 'info',
    this.priority = 'normal',
    this.read = false,
    required this.createdAt,
  });
}
