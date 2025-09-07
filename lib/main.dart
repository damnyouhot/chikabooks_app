// lib/main.dart  (전체 교체)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'models/character.dart';
import 'pages/caring_page.dart';
import 'pages/growth/growth_page.dart';
import 'pages/job_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('✅ Firebase initialized');

  // 최신 API (deprecated 아님)
  await FlutterNaverMap.init(
    clientId: '3amqdx6zuh',
    onAuthFailed: (ex) => debugPrint('❌ NaverMap auth failed: $ex'),
  );

  debugPrint('✅ NaverMap initialized');

  runApp(
    MultiProvider(
      providers: [
        StreamProvider<User?>.value(
          value: FirebaseAuth.instance.authStateChanges(),
          initialData: null,
        ),
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

        return role == 'admin' ? const _DummyAdmin() : const MyHome();
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

class _DummyAdmin extends StatelessWidget {
  const _DummyAdmin({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Admin Page (임시)')));
  }
}
