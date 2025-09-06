// lib/main.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart'; // ← NaverMap 플러그인
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'models/character.dart';
import 'notifiers/job_filter_notifier.dart';
import 'pages/admin/admin_dashboard_page.dart';
import 'pages/caring_page.dart';
import 'pages/growth/growth_page.dart';
import 'pages/job_page.dart';
import 'services/ebook_service.dart';
import 'services/job_service.dart';
import 'services/store_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Firebase 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint(
    '✅ Firebase initialized with projectId='
    '${DefaultFirebaseOptions.currentPlatform.projectId}',
  );

  // 2) Naver Map SDK 초기화 (Firebase 다음, runApp 이전)
  await NaverMapSdk.instance.initialize(
    clientId: '3amqdx6zuh', // ← 네이버 클라우드 플랫폼 "모바일용" Client ID
    onAuthFailed: (ex) {
      // 여기서 인증 실패 원인을 확인할 수 있습니다.
      debugPrint('❌ NaverMap auth failed: $ex');
    },
  );
  debugPrint('✅ NaverMap SDK initialized');

  // 3) 앱 실행
  runApp(
    MultiProvider(
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
      theme: ThemeData(
        primarySwatch: Colors.pink,
        fontFamily: 'NotoSansKR',
        fontFamilyFallback: const ['Apple SD Gothic Neo', 'Roboto'],
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

class _MyHomeState extends State<MyHome> {
  int _selectedIndex = 0;
  static const _pages = [CaringPage(), GrowthPage(), JobPage()];
  static const _titles = ['돌보기', '성장하기', '나아가기'];

  void _onTap(int idx) => setState(() => _selectedIndex = idx);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_selectedIndex])),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTap,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: '돌보기'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_graph), label: '성장하기'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: '나아가기'),
        ],
      ),
    );
  }
}
