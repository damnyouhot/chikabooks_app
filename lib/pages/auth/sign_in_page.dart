import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/apple_auth_service.dart';
import '../../services/email_auth_service.dart';
import '../../services/kakao_auth_service.dart';
import '../../services/naver_auth_service.dart';

/// 다중 소셜 로그인 페이지
/// Google / Apple / Kakao / Naver / Email 지원
class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final googleSignIn = GoogleSignIn(scopes: ['email']);
  bool _isLoading = false;

  /// Google 로그인
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
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
      debugPrint('Google 로그인 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google 로그인 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Apple 로그인
  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      final user = await AppleAuthService.signInWithApple();
      if (user == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Apple 로그인 실패')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 카카오 로그인
  Future<void> _signInWithKakao() async {
    setState(() => _isLoading = true);
    try {
      final user = await KakaoAuthService.signInWithKakao();
      if (user == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카카오 로그인 실패')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 네이버 로그인
  Future<void> _signInWithNaver() async {
    setState(() => _isLoading = true);
    try {
      final user = await NaverAuthService.signInWithNaver();
      if (user == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('네이버 로그인 실패')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 이메일/비밀번호 로그인 (다이얼로그)
  Future<void> _showEmailSignInDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSignUp = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isSignUp ? '이메일 회원가입' : '이메일 로그인'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: '이메일'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: '비밀번호'),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                setDialogState(() => isSignUp = !isSignUp);
              },
              child: Text(isSignUp ? '로그인으로 전환' : '회원가입으로 전환'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();
                final password = passwordController.text.trim();

                if (email.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('이메일과 비밀번호를 입력하세요')),
                  );
                  return;
                }

                User? user;
                if (isSignUp) {
                  user = await EmailAuthService.signUp(
                    email: email,
                    password: password,
                  );
                } else {
                  user = await EmailAuthService.signIn(
                    email: email,
                    password: password,
                  );
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  if (user == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isSignUp ? '회원가입 실패' : '로그인 실패'),
                      ),
                    );
                  }
                }
              },
              child: Text(isSignUp ? '회원가입' : '로그인'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 앱 로고/타이틀
                  const Icon(
                    Icons.medical_services,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '치카북스',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '치과 커뮤니티 & 구인구직 플랫폼',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // 로딩 표시
                  if (_isLoading)
                    const CircularProgressIndicator(color: Colors.white)
                  else
                    Column(
                      children: [
                        // Google 로그인
                        _buildLoginButton(
                          icon: Icons.g_mobiledata,
                          label: 'Google로 로그인',
                          color: Colors.white,
                          textColor: Colors.black87,
                          onPressed: _signInWithGoogle,
                        ),
                        const SizedBox(height: 12),

                        // Apple 로그인 (iOS만)
                        if (Platform.isIOS) ...[
                          _buildLoginButton(
                            icon: Icons.apple,
                            label: 'Apple로 로그인',
                            color: Colors.black,
                            textColor: Colors.white,
                            onPressed: _signInWithApple,
                          ),
                          const SizedBox(height: 12),
                        ],

                        // 카카오 로그인
                        _buildLoginButton(
                          icon: Icons.chat_bubble,
                          label: '카카오로 로그인',
                          color: const Color(0xFFFEE500),
                          textColor: Colors.black87,
                          onPressed: _signInWithKakao,
                        ),
                        const SizedBox(height: 12),

                        // 네이버 로그인
                        _buildLoginButton(
                          icon: Icons.language,
                          label: '네이버로 로그인',
                          color: const Color(0xFF03C75A),
                          textColor: Colors.white,
                          onPressed: _signInWithNaver,
                        ),
                        const SizedBox(height: 12),

                        // 이메일 로그인
                        _buildLoginButton(
                          icon: Icons.email,
                          label: '이메일로 로그인',
                          color: Colors.blueGrey,
                          textColor: Colors.white,
                          onPressed: _showEmailSignInDialog,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 로그인 버튼 위젯
  Widget _buildLoginButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: textColor),
        label: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }
}







