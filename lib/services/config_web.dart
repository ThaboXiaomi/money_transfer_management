class AppConfig {
  static const useBackend = true;
  static String backendBase = 'http://localhost:8000';

  static Future<void> init({int port = 8000}) async {
    final uri = Uri.base;
    final host = uri.host.isNotEmpty ? uri.host : 'localhost';
    final scheme = uri.scheme.isNotEmpty ? uri.scheme : 'http';
    final p = uri.hasPort && uri.port != 0 ? uri.port : port;
    backendBase = '$scheme://$host:$p';
  }
}
