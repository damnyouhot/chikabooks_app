import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/config/app_initializer.dart';
import 'core/config/app_providers.dart';
import 'core/theme/app_theme.dart';
import 'pages/auth/auth_gate.dart';

Future<void> main() async {
  await AppInitializer.initialize();

  // 🔥 Firebase 프로젝트 확인 (디버깅용)
  print('🔥 Firebase projectId = ${Firebase.app().options.projectId}');
  print('🔥 Firebase appId     = ${Firebase.app().options.appId}');

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
