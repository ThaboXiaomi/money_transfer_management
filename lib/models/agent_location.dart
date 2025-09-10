class AgentLocation {
  final String agentId;
  final double lat;
  final double lng;
  final String address;
  final String openingHours;
  final List<String>? services;

  AgentLocation({
    required this.agentId,
    required this.lat,
    required this.lng,
    required this.address,
    this.openingHours = '',
    this.services,
  });
}
