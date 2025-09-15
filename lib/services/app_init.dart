import 'config.dart';
import 'package:flutter/foundation.dart';

class AppInit {
  /// Initialize the AppConfig. You can pass [port] to change the
  /// backend port or an [overrideBackend] to force a specific URL.
  static Future<void> init({int port = 8000, String? overrideBackend}) async {
    if (overrideBackend != null && overrideBackend.isNotEmpty) {
      AppConfig.backendBase = overrideBackend;
      debugPrint(
        'AppConfig.backendBase overridden -> ${AppConfig.backendBase}',
      );
      return;
    }

    await AppConfig.init(port: port);
    // load persisted settings (currency etc.) if present
    try {
      await AppConfig.load();
    } catch (_) {}
    debugPrint('AppConfig.backendBase -> ${AppConfig.backendBase}');
  }

  /// Programmatically set the backend base at runtime.
  static void setBackendBase(String url) {
    if (url.isNotEmpty) {
      AppConfig.backendBase = url;
      debugPrint('AppConfig.backendBase manually set -> $url');
    }
  }
}
