import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../notifiers/job_filter_notifier.dart';
import '../../services/ebook_service.dart';
import '../../services/job_service.dart';
import '../../services/store_service.dart';

/// 앱 전역 Provider 설정
class AppProviders extends StatelessWidget {
  final Widget child;

  const AppProviders({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        StreamProvider<User?>.value(
          value: FirebaseAuth.instance.authStateChanges(),
          initialData: null,
        ),
        ChangeNotifierProvider(create: (_) => JobFilterNotifier()),
        Provider(create: (_) => JobService()),
        Provider(create: (_) => EbookService()),
        Provider(create: (_) => StoreService()),
      ],
      child: child,
    );
  }
}








