import 'dart:io' show InternetAddress, NetworkInterface, InternetAddressType, Platform;

class AppConfig {
  static const useBackend = true;
  static String backendBase = 'http://10.0.2.2:8000';

  static Future<void> init({int port = 8000}) async {
    try {
      if (Platform.isAndroid) {
        backendBase = 'http://10.0.2.2:$port';
        return;
      }

      if (Platform.isIOS) {
        backendBase = 'http://localhost:$port';
        return;
      }

      // Desktop platforms: choose a non-loopback IPv4 address
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          final a = addr.address;
          if (a.isNotEmpty && !a.startsWith('127.') && !a.startsWith('::1')) {
            backendBase = 'http://$a:$port';
            return;
          }
        }
      }

      backendBase = 'http://localhost:$port';
    } catch (_) {
      // keep default
    }
  }
}
