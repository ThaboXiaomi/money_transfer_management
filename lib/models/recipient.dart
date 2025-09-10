class Recipient {
  final int? id;
  final String ownerId;
  final String name;
  final String phone;
  final String country;
  final String? bankName;
  final String? bankAccount;
  final String? iban;
  final String? address;

  Recipient({
    this.id,
    required this.ownerId,
    required this.name,
    required this.phone,
    required this.country,
    this.bankName,
    this.bankAccount,
    this.iban,
    this.address,
  });
}
