// 최종 경로: lib/main.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'models/character.dart';
import 'notifiers/job_filter_notifier.dart';
import 'services/ebook_service.dart';
import 'services/job_service.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import 'pages/admin/admin_dashboard_page.dart';
import 'pages/caring_page.dart';
import 'pages/growth/growth_page.dart';
import 'pages/job_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  const bool useEmulator = true;

  if (kDebugMode && useEmulator) {
    try {
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8081);
      await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
      debugPrint('🔥 Firebase Emulators connected');
    } catch (e) {
      debugPrint('❌ Error connecting to Firebase Emulators: $e');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => JobFilterNotifier()),
        Provider(create: (_) => JobService()),
        Provider(create: (_) => EbookService()),
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
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final user = authSnap.data;
        if (user == null) return const SignInPage();

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            final data = userSnap.data?.data();
            final role = data?['role'] as String? ?? '';

            if (userSnap.data?.exists == false) {
              final defaultChar = Character(id: user.uid);
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .set(defaultChar.toJson());
            }

            return role == 'admin'
                ? const AdminDashboardPage()
                : const MyHome();
          },
        );
      },
    );
  }
}

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: ['email'],
    );

    return Scaffold(
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: const Text('Google로 로그인'),
          onPressed: () async {
            final googleUser = await googleSignIn.signIn();
            if (googleUser == null) return;
            final googleAuth = await googleUser.authentication;
            if (googleAuth.idToken == null) return;
            final credential = GoogleAuthProvider.credential(
              accessToken: googleAuth.accessToken,
              idToken: googleAuth.idToken,
            );
            await FirebaseAuth.instance.signInWithCredential(credential);
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

  static final List<Widget> _pages = <Widget>[
    const CaringPage(),
    const GrowthPage(),
    const JobPage(),
  ];

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
