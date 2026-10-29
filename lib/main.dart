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
      child: const AbaadApp(),
    ),
  );
}

class AbaadApp extends StatelessWidget {
  const AbaadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Abaad (أبعاد)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const ExcludeSemantics(child: MainLayout()),
    );
  }
}
