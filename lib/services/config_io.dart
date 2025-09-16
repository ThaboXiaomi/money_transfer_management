import 'dart:io'
    show InternetAddress, NetworkInterface, InternetAddressType, Platform;
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const useBackend = true;
  static String backendBase = 'http://10.0.2.2:8000';
  // Currency settings (defaults for South African Rand)
  static String currencyCode = 'ZAR';
  static String currencySymbol = 'R';
  // If true, symbol appears after amount (e.g., "100.00 R"); if false, before ("R100.00")
  static bool currencySymbolAfter = false;
  static int currencyDecimals = 2;
  // Minimum password strength required (0.0 - 1.0). Default 0.6 = Strong
  static double passwordMinStrength = 0.6;

  static String formatCurrency(num value) {
    final amt = value.toStringAsFixed(currencyDecimals);
    return currencySymbolAfter ? '$amt $currencySymbol' : '$currencySymbol$amt';
  }

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
    } catch (_) {}
  }
}
