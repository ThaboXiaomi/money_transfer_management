class Transfer {
  final int? id;
  final String agentName;
  final String? agentId;
  final String senderNumber;
  final String receiverNumber;
  final double amount; // amount sent locally (ZAR or LSL)
  final double charge; // additional charge
  final double agentFee; // portion of charge for agent
  final String screenshotPath;
  final String status; // pending/sent/complete
  final String? txRef;
  final String? destination;

  Transfer({
    this.id,
    required this.agentName,
    this.agentId,
    required this.senderNumber,
    required this.receiverNumber,
    required this.amount,
    required this.charge,
    required this.agentFee,
    required this.screenshotPath,
    this.status = 'pending',
    this.txRef,
    this.destination,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'agentName': agentName,
      'agentId': agentId,
      'senderNumber': senderNumber,
      'receiverNumber': receiverNumber,
      'amount': amount,
      'charge': charge,
      'agentFee': agentFee,
      'screenshotPath': screenshotPath,
      'status': status,
      'txRef': txRef,
      'destination': destination,
    };
  }

  factory Transfer.fromMap(Map<String, dynamic> m) => Transfer(
    id: m['id'] as int?,
    agentName: m['agentName'] as String,
    agentId: m['agentId'] != null ? (m['agentId'] as String) : null,
    senderNumber: m['senderNumber'] as String,
    receiverNumber: m['receiverNumber'] as String,
    amount: (m['amount'] as num).toDouble(),
    charge: (m['charge'] as num).toDouble(),
    agentFee: (m['agentFee'] as num).toDouble(),
    screenshotPath: m['screenshotPath'] as String,
    status: m['status'] as String,
    txRef: m['txRef'] != null ? (m['txRef'] as String) : null,
    destination: m['destination'] != null ? (m['destination'] as String) : null,
  );
}
