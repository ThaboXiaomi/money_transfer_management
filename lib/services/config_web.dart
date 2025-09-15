import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const useBackend = true;
  // Default backend base points to port 8000 for local development.
  // This prevents web dev server (different port) from being used as the API host.
  static String backendBase = 'http://localhost:8000';

  // Currency settings (defaults for South African Rand)
  static String currencyCode = 'ZAR';
  static String currencySymbol = 'R';
  // If true, symbol appears after amount (e.g., "100.00 R"); if false, before ("R100.00")
  static bool currencySymbolAfter = false;
  static int currencyDecimals = 2;

  static String formatCurrency(num value) {
    final amt = value.toStringAsFixed(currencyDecimals);
    return currencySymbolAfter ? '$amt $currencySymbol' : '$currencySymbol$amt';
  }

  static Future<void> init({int port = 8000}) async {
    final uri = Uri.base;
    final host = uri.host.isNotEmpty ? uri.host : 'localhost';
    final scheme = uri.scheme.isNotEmpty ? uri.scheme : 'http';
    // Force port to backend port to avoid using the frontend dev server port
    backendBase = '$scheme://$host:$port';
  }

  /// Load persisted app settings (currency, etc.) from SharedPreferences
  static Future<void> load() async {
    try {
      // shared_preferences works on web as a wrapper over window.localStorage
      // ignore: depend_on_referenced_packages
      final prefs = await SharedPreferences.getInstance();
      currencyCode = prefs.getString('currencyCode') ?? currencyCode;
      currencySymbol = prefs.getString('currencySymbol') ?? currencySymbol;
      currencySymbolAfter =
          prefs.getBool('currencySymbolAfter') ?? currencySymbolAfter;
      currencyDecimals = prefs.getInt('currencyDecimals') ?? currencyDecimals;
    } catch (_) {}
  }

  /// Persist app settings to SharedPreferences
  static Future<void> save() async {
    try {
      // ignore: depend_on_referenced_packages
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currencyCode', currencyCode);
      await prefs.setString('currencySymbol', currencySymbol);
      await prefs.setBool('currencySymbolAfter', currencySymbolAfter);
      await prefs.setInt('currencyDecimals', currencyDecimals);
    } catch (_) {}
  }
}
