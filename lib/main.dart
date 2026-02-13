import 'package:flutter/material.dart';
import 'core/config/app_initializer.dart';
import 'core/config/app_providers.dart';
import 'core/theme/app_theme.dart';
import 'pages/auth/auth_gate.dart';

Future<void> main() async {
  await AppInitializer.initialize();

  runApp(
    AppProviders(
      child: const ChikabooksApp(),
    ),
  );
}

class ChikabooksApp extends StatelessWidget {
  const ChikabooksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '치과책방',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}
