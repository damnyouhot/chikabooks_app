import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'models/character.dart';
import 'notifiers/job_filter_notifier.dart';
import 'pages/admin/admin_dashboard_page.dart';
import 'pages/caring_page.dart';
import 'pages/growth/growth_page.dart';
import 'pages/job_page.dart';
import 'pages/store/store_tab.dart' as store;
import 'providers/character_status_provider.dart';
import 'services/ebook_service.dart';
import 'services/job_service.dart';
import 'services/store_service.dart';

// StorePage wrapper
class StorePage extends StatelessWidget {
  const StorePage({super.key});
  @override
  Widget build(BuildContext context) => const store.StoreTab();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 중복 초기화 에러 무시
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') {
      rethrow;
    }
  }

  // 네이버 맵 SDK 초기화
  await NaverMapSdk.instance.initialize(clientId: '3amqdx6zuh');

  runApp(
    MultiProvider(
      providers: [
        StreamProvider<User?>.value(
          value: FirebaseAuth.instance.authStateChanges(),
          initialData: null,
        ),
        ChangeNotifierProvider(create: (_) => JobFilterNotifier()),
        ChangeNotifierProvider(create: (_) => CharacterStatusProvider()),
        Provider(create: (_) => JobService()),
        Provider(create: (_) => EbookService()),
        Provider(create: (_) => StoreService()),
      ],
      child: const ChikabooksApp(),
    ),
  );
}

// 베이지톤 컬러 테마
class AppColors {
  static const Color background = Color(0xFFF5F0E8); // 옅은 베이지
  static const Color cardBg = Color(0xFFFAF6F0);
  static const Color accent = Color(0xFFD4A574); // 따뜻한 브라운
  static const Color accentDark = Color(0xFF8B6914);
  static const Color textPrimary = Color(0xFF4A4A4A);
  static const Color textSecondary = Color(0xFF7A7A7A);
  static const Color gold = Color(0xFFFFD700);
}

class ChikabooksApp extends StatelessWidget {
  const ChikabooksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '치과책방',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.amber,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'NotoSansKR',
        fontFamilyFallback: const ['Apple SD Gothic Neo', 'Roboto'],
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.accentDark,
          unselectedItemColor: AppColors.textSecondary,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    if (user == null) return const SignInPage();

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future:
          FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final doc = snap.data;
        final data = doc?.data();
        final role = data?['role'] as String? ?? '';

        if (doc != null && !doc.exists) {
          final defaultChar = Character(id: user.uid);
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set(defaultChar.toJson());
        }

        return role == 'admin' ? const AdminDashboardPage() : const MyHome();
      },
    );
  }
}

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    final googleSignIn = GoogleSignIn(scopes: ['email']);

    return Scaffold(
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: const Text('Google로 로그인'),
          onPressed: () async {
            try {
              final googleUser = await googleSignIn.signIn();
              if (googleUser == null) return;

              final googleAuth = await googleUser.authentication;
              if (googleAuth.idToken == null) return;

              final credential = GoogleAuthProvider.credential(
                accessToken: googleAuth.accessToken,
                idToken: googleAuth.idToken,
              );
              await FirebaseAuth.instance.signInWithCredential(credential);
            } catch (e) {
              debugPrint('로그인 실패: $e');
            }
          },
        ),
      ),
    );
  }
}

class MyHome extends StatefulWidget {
  const MyHome({super.key});
  @override
  State<MyHome> createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHome> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _initialized = false;

  // 4탭 구조: 홈, 스토어, 성장, 구직
  static const _pages = [
    CaringPage(), // 홈 (아이소메트릭 집)
    StorePage(), // 스토어
    GrowthPage(), // 성장
    JobPage(), // 구직
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCharacterStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 앱 라이프사이클 변경 감지
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final provider = context.read<CharacterStatusProvider>();
    if (state == AppLifecycleState.paused) {
      provider.onAppPause();
    } else if (state == AppLifecycleState.resumed) {
      provider.onAppResume();
    }
  }

  Future<void> _initializeCharacterStatus() async {
    if (!_initialized) {
      await context.read<CharacterStatusProvider>().initialize();
      _initialized = true;
    }
  }

  void _onTap(int idx) => setState(() => _selectedIndex = idx);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.accentDark,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: '홈'),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_rounded),
            label: '스토어',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up_rounded),
            label: '성장',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.work_rounded), label: '구직'),
        ],
      ),
    );
  }
}
