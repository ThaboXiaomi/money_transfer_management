class Sender {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? dob;
  final String? address;
  final String kycStatus;
  final Map<String, dynamic>? metadata;

  Sender({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.dob,
    this.address,
    this.kycStatus = 'unknown',
    this.metadata,
  });
}
