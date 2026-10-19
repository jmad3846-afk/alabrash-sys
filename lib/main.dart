import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/database/erp_provider.dart';
import 'screens/main_layout.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ERPProvider(),
      child: const MarbleGraniteERPApp(),
    ),
  );
}

class MarbleGraniteERPApp extends StatelessWidget {
  const MarbleGraniteERPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'برنامج أبعاد (Abaad) لإدارة الرخام والجرانيت',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const ExcludeSemantics(child: MainLayout()),
    );
  }
}
