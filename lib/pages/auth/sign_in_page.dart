import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/apple_auth_service.dart';
import '../../services/email_auth_service.dart';
import '../../services/kakao_auth_service.dart';
import '../../services/naver_auth_service.dart';
import '../../services/sign_in_tracker.dart';
import '../../services/onboarding_service.dart';
import '../../services/admin_activity_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/hygiene_lab_english_title.dart';
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
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      debugPrint('🔑 Google 로그인 시작');

      await googleSignIn.signOut();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('⚠️ Google 로그인 취소됨 (사용자가 취소)');
        return;
      }

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        debugPrint('❌ Google idToken이 null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google 로그인 실패. 다시 시도해주세요.')),
          );
        }
        return;
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await OnboardingService.forceSchedule();
      await FirebaseAuth.instance.signInWithCredential(credential);
      debugPrint('✅ Firebase Auth signInWithCredential 성공');

      await Future.delayed(const Duration(milliseconds: 200));

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('❌ Firebase Auth currentUser가 여전히 null (비정상)');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google 로그인 실패. 다시 시도해주세요.')),
          );
        }
        return;
      }

      debugPrint('✅ Google 로그인 성공: ${currentUser.uid} (${currentUser.email})');

      await SignInTracker.record('google');
      AdminActivityService.log(ActivityEventType.viewSignInPage, page: 'sign_in');
      AdminActivityService.log(ActivityEventType.loginSuccess, page: 'sign_in', extra: {'provider': 'google'});
      AdminActivityService.logFunnel(
        FunnelEventType.signupComplete,
        extra: {'provider': 'google'},
      );
    } catch (e) {
      debugPrint('❌ Google 로그인 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Google 로그인 오류: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Apple 로그인
  Future<void> _signInWithApple() async {
    AdminActivityService.log(ActivityEventType.tapLoginApple, page: 'sign_in');
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await OnboardingService.forceSchedule();

      final appleRes = await AppleAuthService.signInWithApple();
      if (appleRes == null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Apple 로그인 실패')));
      } else if (appleRes != null) {
        final (user, appleIdEmail) = appleRes;
        await SignInTracker.record(
          'apple',
          email: appleIdEmail ?? user.email,
        );
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

    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await OnboardingService.forceSchedule();

      debugPrint('🔑 카카오 로그인 시작');
      final user = await KakaoAuthService.signInWithKakao();

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('카카오 로그인 실패. 다시 시도해주세요.')),
          );
        }
        return;
      }

      debugPrint('✅ 카카오 로그인 성공: ${user.uid} (${user.email})');

      await SignInTracker.record('kakao');
      AdminActivityService.log(ActivityEventType.viewSignInPage, page: 'sign_in');
      AdminActivityService.log(ActivityEventType.loginSuccess, page: 'sign_in', extra: {'provider': 'kakao'});
      AdminActivityService.logFunnel(
        FunnelEventType.signupComplete,
        extra: {'provider': 'kakao'},
      );
    } catch (e) {
      debugPrint('❌ 카카오 로그인 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('카카오 로그인 오류: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 네이버 로그인
  Future<void> _signInWithNaver() async {
    AdminActivityService.log(ActivityEventType.tapLoginNaver, page: 'sign_in');
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await OnboardingService.forceSchedule();

      debugPrint('🔑 네이버 로그인 시작');
      final naverRes = await NaverAuthService.signInWithNaver();

      if (naverRes.user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                naverRes.errorMessage ?? '네이버 로그인 실패. 다시 시도해주세요.',
              ),
            ),
          );
        }
        return;
      }

      final user = naverRes.user!;
      final naverProfileEmail = naverRes.profileEmail;
      debugPrint(
        '✅ 네이버 로그인 성공: ${user.uid} (Auth.email=${user.email}, sdk=$naverProfileEmail)',
      );

      await SignInTracker.record(
        'naver',
        email: naverProfileEmail ?? user.email,
      );
      AdminActivityService.log(ActivityEventType.viewSignInPage, page: 'sign_in');
      AdminActivityService.log(ActivityEventType.loginSuccess, page: 'sign_in', extra: {'provider': 'naver'});
      AdminActivityService.logFunnel(
        FunnelEventType.signupComplete,
        extra: {'provider': 'naver'},
      );
    } catch (e) {
      debugPrint('❌ 네이버 로그인 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('네이버 로그인 오류: $e')));
      }
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
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const HygieneLabEnglishTitle(
                        fontSize: 34.8,
                        letterSpacing: 0.21,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '하이진랩',
                        style: TextStyle(
                          fontSize: 20,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Apple SD Gothic Neo',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '치과인의 커리어 연구소',
                        style: TextStyle(
                          fontSize: 16.9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
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
                                  '치과책방 전자책 구매자는 \n치과책방 계정으로 로그인하셔야 구매하신 책이 앱에 등록됩니다',
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
      _BtnDef(
        'google',
        _LoginSnsAssets.google,
        'Google로 로그인',
        Colors.white,
        Colors.black87,
        _signInWithGoogle,
      ),
      if (!kIsWeb && Platform.isIOS)
        _BtnDef(
          'apple',
          _LoginSnsAssets.apple,
          'Apple로 로그인',
          Colors.black,
          Colors.white,
          _signInWithApple,
        ),
      _BtnDef(
        'kakao',
        _LoginSnsAssets.kakao,
        '카카오로 로그인',
        const Color(0xFFFEE500),
        Colors.black87,
        _signInWithKakao,
      ),
      _BtnDef(
        'naver',
        _LoginSnsAssets.naver,
        '네이버로 로그인',
        AppColors.naverLoginGreen,
        Colors.white,
        _signInWithNaver,
      ),
      _BtnDef(
        'email',
        _LoginSnsAssets.email,
        '이메일로 로그인',
        Colors.blueGrey,
        Colors.white,
        _showEmailSignInDialog,
      ),
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
          iconAsset: b.iconAsset,
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
    required String iconAsset,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
    bool isLast = false,
  }) {
    final Widget iconChild =
        iconAsset.endsWith('.png')
            ? Semantics(
              label: label,
              child: Image.asset(
                iconAsset,
                width: 24,
                height: 24,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            )
            : SvgPicture.asset(
              iconAsset,
              fit: BoxFit.contain,
              semanticsLabel: label,
            );
    final iconWidget = SizedBox(width: 24, height: 24, child: iconChild);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            icon: iconWidget,
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
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '마지막 로그인',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.onAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// SNS 로그인 버튼용 에셋 경로 (`assets/auth/`)
abstract final class _LoginSnsAssets {
  static const google = 'assets/auth/sns_google.svg';
  static const apple = 'assets/auth/sns_apple.svg';
  static const kakao = 'assets/auth/sns_kakao.svg';
  static const naver = 'assets/auth/sns_naver.png';
  static const email = 'assets/auth/sns_email.svg';
}

/// 로그인 버튼 정의 (순서 변경용)
class _BtnDef {
  final String provider;
  final String iconAsset;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onPressed;
  const _BtnDef(
    this.provider,
    this.iconAsset,
    this.label,
    this.color,
    this.textColor,
    this.onPressed,
  );
}

