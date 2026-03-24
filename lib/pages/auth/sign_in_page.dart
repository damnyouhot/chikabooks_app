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
import '../../services/onboarding_service.dart';
import '../../services/admin_activity_service.dart';
import '../../core/theme/app_colors.dart';

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
    // ※ view_sign_in_page는 로그인 전이라 uid가 null → 기록 불가
    // → 로그인 성공 시 _logPostLogin()에서 함께 기록
  }

  Future<void> _loadLastProvider() async {
    final p = await SignInTracker.getLocalLastProvider();
    if (mounted && p != null) setState(() => _lastProvider = p);
  }

  /// Google 로그인
  Future<void> _signInWithGoogle() async {
    AdminActivityService.log(ActivityEventType.tapLoginGoogle, page: 'sign_in');
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

      // ✅ auth 상태 변경 전에 온보딩 플래그 설정 (race condition 방지)
      await OnboardingService.forceSchedule();

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
      // 퍼널 이벤트: 로그인 화면 진입 + 로그인 성공 (로그인 전에는 uid 없으므로 여기서 함께 기록)
      AdminActivityService.log(ActivityEventType.viewSignInPage, page: 'sign_in');
      AdminActivityService.log(ActivityEventType.loginSuccess, page: 'sign_in', extra: {'provider': 'google'});
      AdminActivityService.logFunnel(
        FunnelEventType.signupComplete,
        extra: {'provider': 'google'},
      );

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
    AdminActivityService.log(ActivityEventType.tapLoginApple, page: 'sign_in');
    setState(() => _isLoading = true);
    try {
      // ✅ auth 상태 변경 전에 온보딩 플래그 설정 (race condition 방지)
      await OnboardingService.forceSchedule();

      final user = await AppleAuthService.signInWithApple();
      if (user == null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Apple 로그인 실패')));
      } else if (user != null) {
        // 로컬 provider 기록 (배지용)
        await SignInTracker.record('apple');
        AdminActivityService.log(ActivityEventType.viewSignInPage, page: 'sign_in');
        AdminActivityService.log(ActivityEventType.loginSuccess, page: 'sign_in', extra: {'provider': 'apple'});
        AdminActivityService.logFunnel(
          FunnelEventType.signupComplete,
          extra: {'provider': 'apple'},
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 카카오 로그인
  Future<void> _signInWithKakao() async {
    AdminActivityService.log(ActivityEventType.tapLoginKakao, page: 'sign_in');
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
      // ✅ auth 상태 변경 전에 온보딩 플래그 설정 (race condition 방지)
      await OnboardingService.forceSchedule();

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
      AdminActivityService.log(ActivityEventType.viewSignInPage, page: 'sign_in');
      AdminActivityService.log(ActivityEventType.loginSuccess, page: 'sign_in', extra: {'provider': 'kakao'});
      AdminActivityService.logFunnel(
        FunnelEventType.signupComplete,
        extra: {'provider': 'kakao'},
      );

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
    AdminActivityService.log(ActivityEventType.tapLoginNaver, page: 'sign_in');
    setState(() => _isLoading = true);
    try {
      // ✅ auth 상태 변경 전에 온보딩 플래그 설정 (race condition 방지)
      await OnboardingService.forceSchedule();

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
      AdminActivityService.log(ActivityEventType.viewSignInPage, page: 'sign_in');
      AdminActivityService.log(ActivityEventType.loginSuccess, page: 'sign_in', extra: {'provider': 'naver'});
      AdminActivityService.logFunnel(
        FunnelEventType.signupComplete,
        extra: {'provider': 'naver'},
      );

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
    AdminActivityService.log(ActivityEventType.tapLoginEmail, page: 'sign_in');
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
                    if (!isSignUp)
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showPasswordResetDialog();
                        },
                        child: const Text('비밀번호 찾기'),
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

                        // ✅ auth 상태 변경 전에 온보딩 플래그 설정
                        await OnboardingService.forceSchedule();

                        User? user;
                        String? authError;
                        try {
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
                        } catch (e) {
                          // Exception 메시지에서 'Exception: ' 접두사 제거
                          authError = e.toString().replaceFirst('Exception: ', '');
                        }

                        if (context.mounted) {
                          if (user == null) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(authError ?? (isSignUp ? '회원가입 실패' : '로그인 실패')),
                              ),
                            );
                          } else {
                            // ✅ pop 전에 먼저 실행 — HomeShell 생성 전에 플래그 보장
                            await SignInTracker.record('email');
                            AdminActivityService.log(ActivityEventType.viewSignInPage, page: 'sign_in');
                            AdminActivityService.log(ActivityEventType.loginSuccess, page: 'sign_in', extra: {'provider': 'email', 'isSignUp': isSignUp});
                            if (isSignUp) {
                              AdminActivityService.logFunnel(
                                FunnelEventType.signupComplete,
                                extra: {'provider': 'email'},
                              );
                            }
                            if (context.mounted) Navigator.pop(context);
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

  Future<void> _showPasswordResetDialog() async {
    final emailCtrl = TextEditingController();
    bool isSending = false;
    bool isSent = false;
    String? errorMsg;

    await showDialog(
      context: context,
      barrierDismissible: !isSending,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Row(
                    children: const [
                      Icon(Icons.lock_reset_rounded, size: 22),
                      SizedBox(width: 8),
                      Text('비밀번호 설정 링크 보내기'),
                    ],
                  ),
                  content: isSent
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.mark_email_read_rounded,
                              size: 48,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${emailCtrl.text.trim()}으로\n비밀번호 설정 링크를 보냈어요.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14, height: 1.5),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '메일함을 확인해주세요.\n스팸함에 있을 수도 있어요.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                height: 1.5,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '가입 시 사용한 이메일을 입력하면\n비밀번호 설정 링크를 보내드려요.',
                              style: TextStyle(fontSize: 13, height: 1.5),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: '이메일',
                                hintText: 'email@example.com',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                prefixIcon: const Icon(Icons.email_outlined),
                              ),
                            ),
                            if (errorMsg != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  errorMsg!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                  actions: isSent
                      ? [
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('확인'),
                          ),
                        ]
                      : [
                          TextButton(
                            onPressed: isSending ? null : () => Navigator.pop(ctx),
                            child: const Text('취소'),
                          ),
                          ElevatedButton(
                            onPressed: isSending
                                ? null
                                : () async {
                                    final email = emailCtrl.text.trim();
                                    if (email.isEmpty || !email.contains('@')) {
                                      setDialogState(
                                        () => errorMsg = '올바른 이메일 주소를 입력해주세요.',
                                      );
                                      return;
                                    }
                                    setDialogState(() {
                                      isSending = true;
                                      errorMsg = null;
                                    });
                                    try {
                                      await FirebaseAuth.instance
                                          .sendPasswordResetEmail(email: email);
                                      if (ctx.mounted) {
                                        setDialogState(() => isSent = true);
                                      }
                                    } on FirebaseAuthException catch (e) {
                                      setDialogState(() {
                                        isSending = false;
                                        errorMsg = e.code == 'user-not-found'
                                            ? '등록되지 않은 이메일이에요.'
                                            : '발송 중 오류가 발생했어요. 다시 시도해주세요.';
                                      });
                                    }
                                  },
                            child: isSending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('링크 보내기'),
                          ),
                        ],
                ),
          ),
    );
    emailCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'HygieneLab',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppColors.blue,
                              letterSpacing: 0.35,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '하이진랩',
                            style: TextStyle(
                              fontSize: 19.5,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Apple SD Gothic Neo',
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '치과인들의 커리어 연구소',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child:
                  _isLoading
                      ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.blue),
                        ),
                      )
                      : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ..._buildOrderedButtons(),
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 22,
                                  color: AppColors.warning,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '전자책 스토어 구매자는 \n구매에 사용한 이메일 계정으로 로그인하세요.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
            ),
          ],
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
                color: AppColors.success,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '마지막 로그인',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.white,
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

