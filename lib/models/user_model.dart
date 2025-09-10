class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String status;
  final DateTime createdAt;
  final DateTime? lastLogin;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.status = 'active',
    required this.createdAt,
    this.lastLogin,
  });
}
