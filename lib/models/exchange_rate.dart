class ExchangeRate {
  final String pair;
  final double rate;
  final String source;
  final DateTime validFrom;
  final DateTime? validTo;
  final DateTime lastUpdated;

  ExchangeRate({
    required this.pair,
    required this.rate,
    required this.source,
    required this.validFrom,
    this.validTo,
    required this.lastUpdated,
  });
}
