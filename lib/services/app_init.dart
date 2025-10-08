import 'config.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppInit {
  /// Initialize the AppConfig. You can pass [port] to change the
  /// backend port or an [overrideBackend] to force a specific URL.
  static Future<void> init({int port = 8000, String? overrideBackend}) async {
    // If an explicit override was provided, persist it for future runs
    if (overrideBackend != null && overrideBackend.isNotEmpty) {
      AppConfig.backendBase = overrideBackend;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('backendOverride', overrideBackend);
      } catch (_) {}
      debugPrint(
        'AppConfig.backendBase overridden -> ${AppConfig.backendBase}',
      );
      return;
    }

    // Initialize AppConfig (this will probe common candidates and may load
    // a previously detected or persisted backend address).
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
      // persist the manual override so it survives restarts (fire-and-forget)
      Future<void>(() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('backendOverride', url);
        } catch (_) {}
      });
      debugPrint('AppConfig.backendBase manually set -> $url');
    }
  }
}
