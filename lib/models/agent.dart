class Agent {
  final String id;
  final String name;
  final String locationId;
  final String status;
  final double dailyVolume;
  final double commissionRate;

  Agent({
    required this.id,
    required this.name,
    required this.locationId,
    this.status = 'active',
    this.dailyVolume = 0.0,
    this.commissionRate = 0.0,
  });
}
