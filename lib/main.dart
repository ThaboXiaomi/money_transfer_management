import 'package:flutter/material.dart';
import 'package:money_transfer_management/screens/role_selection.dart';
import 'package:money_transfer_management/screens/dashboard.dart';
import 'package:money_transfer_management/screens/transfer_list.dart';
import 'package:money_transfer_management/screens/transfer_detail.dart';
import 'package:money_transfer_management/screens/create_transfer.dart';
import 'package:money_transfer_management/screens/recipients.dart';
import 'package:money_transfer_management/screens/sender_profile.dart';
import 'package:money_transfer_management/screens/agent_dashboard.dart';
import 'package:money_transfer_management/screens/agent_locator.dart';
import 'package:money_transfer_management/screens/pricing_editor.dart';
import 'package:money_transfer_management/screens/exchange_rates.dart';
import 'package:money_transfer_management/screens/settlements.dart';
import 'package:money_transfer_management/screens/audit_log.dart';
import 'package:money_transfer_management/screens/kyc_screen.dart';
import 'package:money_transfer_management/screens/notifications.dart';
import 'package:money_transfer_management/screens/reports.dart';
import 'package:money_transfer_management/screens/user_management.dart';
import 'package:money_transfer_management/screens/roles_editor.dart';
import 'package:money_transfer_management/screens/refunds.dart';
import 'package:money_transfer_management/screens/bulk_import.dart';
import 'package:money_transfer_management/screens/support.dart';
import 'package:money_transfer_management/services/app_init.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:money_transfer_management/services/config.dart';
import 'package:money_transfer_management/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Prevent google_fonts from trying to fetch fonts at runtime on devices
  // (avoids network/TLS handshake failures on some devices/networks).
  // The GoogleFonts.config object is final; set the flag on it instead of
  // reassigning the entire config object.
  GoogleFonts.config.allowRuntimeFetching = false;

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
    return ValueListenableBuilder<bool>(
      valueListenable: AppConfig.themeNotifier,
      builder: (context, dark, _) {
        return MaterialApp(
          title: 'Giant Money Transfer',
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: const RoleSelectionScreen(),
          routes: {
            '/role-selection': (c) => const RoleSelectionScreen(),
            '/dashboard': (c) => const DashboardScreen(),
            '/transfers': (c) => const TransferListScreen(),
            '/transfer-detail': (c) => const TransferDetailScreen(),
            '/create-transfer': (c) => const CreateTransferScreen(),
            '/recipients': (c) => const RecipientsScreen(),
            '/sender-profile': (c) => const SenderProfileScreen(),
            '/agent-dashboard': (c) => const AgentDashboardScreen(),
            '/agent-locator': (c) => const AgentLocatorScreen(),
            '/pricing': (c) => const PricingEditorScreen(),
            '/exchange-rates': (c) => const ExchangeRatesScreen(),
            '/settlements': (c) => const SettlementsScreen(),
            '/audit-log': (c) => const AuditLogScreen(),
            '/kyc': (c) => const KYCScreen(),
            '/notifications': (c) => const NotificationsScreen(),
            '/reports': (c) => const ReportsScreen(),
            '/users': (c) => const UserManagementScreen(),
            '/roles': (c) => const RolesEditorScreen(),
            '/refunds': (c) => const RefundsScreen(),
            '/bulk-import': (c) => const BulkImportScreen(),
            '/support': (c) => const SupportScreen(),
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
