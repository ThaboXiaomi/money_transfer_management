import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:money_transfer_management/screens/role_selection.dart';
import 'package:money_transfer_management/services/app_init.dart';
import 'package:money_transfer_management/services/config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // initialize AppConfig (sets AppConfig.backendBase based on platform)
  AppInit.init().then((_) {
    // debug log the computed backend URL and start the app
    // ignore: avoid_print
    print('Backend base -> ${AppConfig.backendBase}');
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      useMaterial3: true,
    );
    return MaterialApp(
      title: 'Giant Money Transfer',
      theme: base.copyWith(
        textTheme: GoogleFonts.interTextTheme(base.textTheme),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          ),
        ),
      ),
      home: const RoleSelectionScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
