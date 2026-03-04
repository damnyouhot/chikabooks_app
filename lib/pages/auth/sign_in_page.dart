import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/apple_auth_service.dart';
import '../../services/email_auth_service.dart';
import '../../services/kakao_auth_service.dart';
import '../../services/naver_auth_service.dart';
import '../../services/sign_in_tracker.dart';

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
  String? _lastProvider;

  @override
  void initState() {
    super.initState();
    _loadLastProvider();
  }

  Future<void> _loadLastProvider() async {
    final p = await SignInTracker.getLocalLastProvider();
    if (mounted && p != null) setState(() => _lastProvider = p);
  }

  /// Google 로그인
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('🔑 Google 로그인 시작');

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('⚠️ Google 로그인 취소됨 (사용자가 취소)');
        return; // 사용자가 취소한 경우 - 스낵바 표시 안 함
      }

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        debugPrint('❌ Google idToken이 null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google 로그인 실패. 다시 시도해주세요.')),
          );
        }
        return; // ← 여기서 종료!
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      debugPrint('✅ Firebase Auth signInWithCredential 성공');

      // currentUser는 authStateChanges를 통해 비동기로 업데이트됨
      // 짧은 대기 후 재확인
      await Future.delayed(const Duration(milliseconds: 200));

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('❌ Firebase Auth currentUser가 여전히 null (비정상)');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google 로그인 실패. 다시 시도해주세요.')),
          );
        }
        return; // ← 여기서 종료!
      }

      // ✅ 성공 시에만 이 줄까지 도달
      debugPrint('✅ Google 로그인 성공: ${currentUser.uid} (${currentUser.email})');
      debugPrint(
        '✅ Provider data: ${currentUser.providerData.map((e) => e.providerId).toList()}',
      );

      // provider 기록 (Firestore + 로컬)
      await SignInTracker.record('google');

      // AuthGate가 자동으로 홈으로 보내므로 추가 라우팅 불필요
    } catch (e) {
      debugPrint('❌ Google 로그인 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Google 로그인 오류: $e')));
      }
      return; // ← 에러 시 종료!
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Apple 로그인 실패')));
      } else if (user != null) {
        // 로컬 provider 기록 (배지용)
        await SignInTracker.record('apple');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 카카오 로그인
  Future<void> _signInWithKakao() async {
    // 웹에서는 kakao_flutter_sdk가 정상 동작하지 않아 안내 메시지 표시
    if (kIsWeb) {
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('카카오 로그인 안내'),
              content: const Text(
                '카카오 로그인은 현재 모바일 앱에서만 지원돼요.\n\n'
                '웹에서는 Google 로그인 또는 이메일 로그인을 이용해주세요.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      debugPrint('🔑 카카오 로그인 시작');
      final user = await KakaoAuthService.signInWithKakao();

      if (user == null) {
        // ✅ 실패 시 명시적으로 return (절대 홈으로 이동하지 않음)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('카카오 로그인 실패. 다시 시도해주세요.')),
          );
        }
        return; // ← 여기서 종료!
      }

      // ✅ 성공 시에만 이 줄까지 도달
      debugPrint('✅ 카카오 로그인 성공: ${user.uid} (${user.email})');

      // 로컬 provider 기록 (배지용, Firestore는 Function에서 이미 저장)
      await SignInTracker.record('kakao');

      // AuthGate가 자동으로 홈으로 보내므로 추가 라우팅 불필요
    } catch (e) {
      debugPrint('❌ 카카오 로그인 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('카카오 로그인 오류: $e')));
      }
      return; // ← 에러 시 종료!
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 네이버 로그인
  Future<void> _signInWithNaver() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('🔑 네이버 로그인 시작');
      final user = await NaverAuthService.signInWithNaver();

      if (user == null) {
        // ✅ 실패 시 명시적으로 return (절대 홈으로 이동하지 않음)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('네이버 로그인 실패. 다시 시도해주세요.')),
          );
        }
        return; // ← 여기서 종료!
      }

      // ✅ 성공 시에만 이 줄까지 도달
      debugPrint('✅ 네이버 로그인 성공: ${user.uid} (${user.email})');
      debugPrint(
        '✅ Provider data: ${user.providerData.map((e) => e.providerId).toList()}',
      );

      // 로컬 provider 기록 (배지용)
      await SignInTracker.record('naver');

      // AuthGate가 자동으로 홈으로 보내므로 추가 라우팅 불필요
    } catch (e) {
      debugPrint('❌ 네이버 로그인 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('네이버 로그인 오류: $e')));
      }
      return; // ← 에러 시 종료!
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 이메일/비밀번호 로그인 (다이얼로그)
  Future<void> _showEmailSignInDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final passwordConfirmController = TextEditingController();
    bool isSignUp = false;

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(isSignUp ? '이메일 회원가입' : '이메일 로그인'),
                  content: SingleChildScrollView(
                    child: Column(
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
                          decoration: InputDecoration(
                            labelText: '비밀번호',
                            hintText: isSignUp ? '8~20자, 영문·숫자·특수문자 조합' : null,
                          ),
                          obscureText: true,
                        ),
                        // 회원가입 시에만 비밀번호 확인 필드 표시
                        if (isSignUp) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: passwordConfirmController,
                            decoration: const InputDecoration(
                              labelText: '비밀번호 확인',
                            ),
                            obscureText: true,
                          ),
                        ],
                      ],
                    ),
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
                        final passwordConfirm =
                            passwordConfirmController.text.trim();

                        if (email.isEmpty || password.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('이메일과 비밀번호를 입력하세요')),
                          );
                          return;
                        }

                        // 회원가입 시 비밀번호 검증
                        if (isSignUp) {
                          // 비밀번호 확인 일치 여부
                          if (password != passwordConfirm) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('비밀번호가 일치하지 않습니다')),
                            );
                            return;
                          }

                          // 비밀번호 길이 검증 (8~20자)
                          if (password.length < 8 || password.length > 20) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('비밀번호는 8~20자여야 합니다'),
                              ),
                            );
                            return;
                          }

                          // 비밀번호 조합 검증 (영문, 숫자, 특수문자 포함)
                          final hasLetter = RegExp(
                            r'[a-zA-Z]',
                          ).hasMatch(password);
                          final hasDigit = RegExp(r'[0-9]').hasMatch(password);
                          final hasSpecial = RegExp(
                            r'[!@#$%^&*(),.?":{}|<>]',
                          ).hasMatch(password);

                          if (!hasLetter || !hasDigit || !hasSpecial) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('비밀번호는 영문, 숫자, 특수문자를 포함해야 합니다'),
                              ),
                            );
                            return;
                          }
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
                          } else {
                            // 이메일 로그인 provider 기록
                            await SignInTracker.record('email');
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
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 48),

                  // 로딩 표시
                  if (_isLoading)
                    const CircularProgressIndicator(color: Colors.white)
                  else
                    Column(
                      children: [
                        // 마지막 로그인 버튼을 맨 위로 올리고 나머지 순서 유지
                        ..._buildOrderedButtons(),
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

  /// 마지막 로그인 provider를 맨 위로 올려서 버튼 리스트 생성
  List<Widget> _buildOrderedButtons() {
    final buttons = <_BtnDef>[
      _BtnDef('google', Icons.g_mobiledata, 'Google로 로그인',
          Colors.white, Colors.black87, _signInWithGoogle),
      if (!kIsWeb && Platform.isIOS)
        _BtnDef('apple', Icons.apple, 'Apple로 로그인',
            Colors.black, Colors.white, _signInWithApple),
      _BtnDef('kakao', Icons.chat_bubble, '카카오로 로그인',
          const Color(0xFFFEE500), Colors.black87, _signInWithKakao),
      _BtnDef('naver', Icons.language, '네이버로 로그인',
          const Color(0xFF03C75A), Colors.white, _signInWithNaver),
      _BtnDef('email', Icons.email, '이메일로 로그인',
          Colors.blueGrey, Colors.white, _showEmailSignInDialog),
    ];

    // 마지막 로그인 provider 를 맨 위로
    if (_lastProvider != null) {
      final idx = buttons.indexWhere((b) => b.provider == _lastProvider);
      if (idx > 0) {
        final btn = buttons.removeAt(idx);
        buttons.insert(0, btn);
      }
    }

    final widgets = <Widget>[];
    for (final b in buttons) {
      widgets.add(
        _buildLoginButton(
          provider: b.provider,
          icon: b.icon,
          label: b.label,
          color: b.color,
          textColor: b.textColor,
          onPressed: b.onPressed,
          isLast: b.provider == _lastProvider,
        ),
      );
      widgets.add(const SizedBox(height: 12));
    }
    return widgets;
  }

  /// 로그인 버튼 위젯
  Widget _buildLoginButton({
    required String provider,
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
    bool isLast = false,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
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
        ),
        if (isLast)
          Positioned(
            right: 8,
            top: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Text(
                '마지막 로그인',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 로그인 버튼 정의 (순서 변경용)
class _BtnDef {
  final String provider;
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onPressed;
  const _BtnDef(
    this.provider,
    this.icon,
    this.label,
    this.color,
    this.textColor,
    this.onPressed,
  );
}
