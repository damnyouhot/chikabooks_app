// lib/main.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'models/character.dart';
import 'pages/home_page.dart';
import 'pages/job_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('✅ Firebase initialized with projectId=${DefaultFirebaseOptions.currentPlatform.projectId}');

  // 2) Naver Map (정식 초기화 방식)
  await FlutterNaverMap.init(
    clientId: '여기에_네이버맵_Client_ID',
    onAuthFailed: (ex) => debugPrint('❌ NaverMap auth failed: $ex'),
  );
  debugPrint('✅ NaverMap init done');

  runApp(const ChikabooksApp());
}

class ChikabooksApp extends StatelessWidget {
  const ChikabooksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        StreamProvider<User?>.value(
          value: FirebaseAuth.instance.authStateChanges(),
          initialData: null,
        ),
      ],
      child: MaterialApp(
        title: '치과책방',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.pink,
          fontFamily: 'NotoSansKR',
          fontFamilyFallback: const ['Apple SD Gothic Neo', 'Roboto'],
        ),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    if (user == null) return const _SignInStub(); // 최소 로그인 스텁

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final doc = snap.data;
        if (doc != null && !doc.exists) {
          final defaultChar = Character(id: user.uid);
          FirebaseFirestore.instance.collection('users').doc(user.uid).set(defaultChar.toJson());
        }
        return const _HomeShell();
      },
    );
  }
}

class _SignInStub extends StatelessWidget {
  const _SignInStub();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('로그인 화면 준비 중')),
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell();

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _index = 0;
  final _pages = const [HomePage(), JobPage()];
  final _titles = const ['홈', '나아가기'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: '나아가기'),
        ],
      ),
    );
  }
}
