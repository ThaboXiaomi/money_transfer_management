class SupportTicket {
  final String id;
  final String userId;
  final String subject;
  final String status;
  final String priority;
  final List<Map<String, dynamic>>
  messages; // {authorId,text,attachments,createdAt}
  final String? assignedTo;

  SupportTicket({
    required this.id,
    required this.userId,
    required this.subject,
    this.status = 'open',
    this.priority = 'normal',
    required this.messages,
    this.assignedTo,
  });
}
