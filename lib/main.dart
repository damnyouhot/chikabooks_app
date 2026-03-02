import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/config/app_initializer.dart';
import 'core/config/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  await AppInitializer.initialize();

  // ignore: avoid_print
  print('🔥 Firebase projectId = ${Firebase.app().options.projectId}');
  // ignore: avoid_print
  print('🔥 Firebase appId     = ${Firebase.app().options.appId}');

  runApp(AppProviders(child: const ChikabooksApp()));
}

class ChikabooksApp extends StatelessWidget {
  const ChikabooksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '치과책방',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
      // iOS/Android 텍스트 크기 통일 (시스템 폰트 크기 설정 무시)
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        );
      },
    );
  }
}
