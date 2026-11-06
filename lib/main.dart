import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/database/erp_provider.dart';
import 'screens/main_layout.dart';
import 'screens/license_lock_screen.dart';
import 'core/licensing/license_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ERPProvider(),
      child: const AbaadApp(),
    ),
  );
}

class AbaadApp extends StatefulWidget {
  const AbaadApp({super.key});

  @override
  State<AbaadApp> createState() => _AbaadAppState();
}

class _AbaadAppState extends State<AbaadApp> {
  final _licenseService = LicenseService();
  bool? _licensed;

  @override
  void initState() {
    super.initState();
    _checkLicense();
  }

  Future<void> _checkLicense() async {
    final expiry = await _licenseService.getValidExpiry();
    if (mounted) setState(() => _licensed = expiry != null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Abaad (أبعاد)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _licensed == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _licensed!
          ? const ExcludeSemantics(child: MainLayout())
          : LicenseLockScreen(
              onActivated: () => setState(() => _licensed = true),
            ),
    );
  }
}
