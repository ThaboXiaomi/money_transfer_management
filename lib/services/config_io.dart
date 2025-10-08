import 'dart:io'
    show InternetAddress, NetworkInterface, InternetAddressType, Platform;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const useBackend = true;
  // default remains emulator-friendly but init() will try other candidates
  static String backendBase = 'http://10.0.2.2:8000';
  // Currency settings (defaults for South African Rand)
  static String currencyCode = 'ZAR';
  static String currencySymbol = 'R';
  // If true, symbol appears after amount (e.g., "100.00 R"); if false, before ("R100.00")
  static bool currencySymbolAfter = false;
  static int currencyDecimals = 2;
  // Minimum password strength required (0.0 - 1.0). Default 0.6 = Strong
  static double passwordMinStrength = 0.6;
  // Theme preference
  static bool darkMode = false;
  // Notifier so UI can listen and rebuild when theme changes
  static final ValueNotifier<bool> themeNotifier = ValueNotifier<bool>(
    darkMode,
  );

  static String formatCurrency(num value) {
    final amt = value.toStringAsFixed(currencyDecimals);
    return currencySymbolAfter ? '$amt $currencySymbol' : '$currencySymbol$amt';
  }

  static Future<void> init({int port = 8000}) async {
    try {
      // Helper: probe a URI quickly; returns true if reachable
      Future<bool> _probe(String url) async {
        try {
          final uri = Uri.parse(url);
          final resp = await http.get(uri).timeout(const Duration(seconds: 1));
          return resp.statusCode >= 200 && resp.statusCode < 500;
        } catch (_) {
          return false;
        }
      }

      // Build candidate list depending on platform
      final List<String> candidates = <String>[];
      if (Platform.isAndroid) {
        candidates.add('http://10.0.2.2:$port'); // emulator
        candidates.add('http://localhost:$port');
        candidates.add('http://127.0.0.1:$port');
        candidates.add('https://10.0.2.2:$port');
        candidates.add('https://localhost:$port');
      } else if (Platform.isIOS) {
        candidates.add('http://localhost:$port');
        candidates.add('https://localhost:$port');
      } else {
        // Desktop / other: include discovered LAN addresses plus localhost
        candidates.add('http://localhost:$port');
        candidates.add('http://127.0.0.1:$port');
        try {
          final ifaces = await NetworkInterface.list(
            type: InternetAddressType.IPv4,
            includeLoopback: false,
          );
          for (final iface in ifaces) {
            for (final addr in iface.addresses) {
              final a = addr.address;
              if (a.isNotEmpty &&
                  !a.startsWith('127.') &&
                  !a.startsWith('::1')) {
                candidates.add('http://$a:$port');
                candidates.add('https://$a:$port');
              }
            }
          }
        } catch (_) {
          // ignore interface discovery errors
        }
      }

      // Try each candidate until one responds
      for (final c in candidates) {
        if (await _probe(c)) {
          backendBase = c;
          // persist discovered backend so subsequent runs are faster
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('backendDetected', backendBase);
          } catch (_) {}
          return;
        }
      }

      // If none succeeded, try to fall back to any previously detected value
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved =
            prefs.getString('backendOverride') ??
            prefs.getString('backendDetected');
        if (saved != null && saved.isNotEmpty) {
          backendBase = saved;
          return;
        }
      } catch (_) {}

      // leave default (emulator-friendly) if nothing else
      backendBase = 'http://10.0.2.2:$port';
      debugPrint(
        'AppConfig: no backend candidate responded; using default $backendBase',
      );
    } catch (e) {
      // keep default and log
      debugPrint('AppConfig.init error: $e');
    }
  }

  /// Load persisted app settings (currency, etc.) from SharedPreferences
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      currencyCode = prefs.getString('currencyCode') ?? currencyCode;
      currencySymbol = prefs.getString('currencySymbol') ?? currencySymbol;
      currencySymbolAfter =
          prefs.getBool('currencySymbolAfter') ?? currencySymbolAfter;
      currencyDecimals = prefs.getInt('currencyDecimals') ?? currencyDecimals;
      passwordMinStrength =
          prefs.getDouble('passwordMinStrength') ?? passwordMinStrength;
      darkMode = prefs.getBool('darkMode') ?? darkMode;
      themeNotifier.value = darkMode;
    } catch (_) {}
  }

  /// Persist app settings to SharedPreferences
  static Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currencyCode', currencyCode);
      await prefs.setString('currencySymbol', currencySymbol);
      await prefs.setBool('currencySymbolAfter', currencySymbolAfter);
      await prefs.setInt('currencyDecimals', currencyDecimals);
      await prefs.setDouble('passwordMinStrength', passwordMinStrength);
      await prefs.setBool('darkMode', darkMode);
    } catch (_) {}
  }
}
