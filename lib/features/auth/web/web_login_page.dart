import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/admin_activity_service.dart';
import '../../../services/apple_auth_service.dart';
import '../../../services/email_auth_service.dart';
import '../../../services/kakao_auth_service.dart';
import '../../../services/sign_in_tracker.dart';
import '../../publisher/services/clinic_auth_service.dart';
import '../../publisher/pages/publisher_shared.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/web_site_footer.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/hygiene_lab_english_title.dart';

/// 통합 로그인 페이지 (/login)
///
/// 좌: 지원자 로그인 (카카오 · 구글 · 애플 · 이메일  /  네이버는 앱 전용)
/// 우: 치과 로그인 (이메일/비밀번호)
abstract final class _WebLoginSnsAssets {
  static const google = 'assets/auth/sns_google.svg';
  static const apple = 'assets/auth/sns_apple.svg';
  static const kakao = 'assets/auth/sns_kakao.svg';
  static const naver = 'assets/auth/sns_naver.png';
  static const email = 'assets/auth/sns_email.svg';
}

class WebLoginPage extends StatefulWidget {
  final String? nextRoute;
  const WebLoginPage({super.key, this.nextRoute});

  @override
  State<WebLoginPage> createState() => _WebLoginPageState();
}

class _WebLoginPageState extends State<WebLoginPage> {
  /// 마지막으로 redirect 시도한 uid — uid가 바뀌면 다시 시도하도록 함
  String? _lastRedirectedUid;
  DateTime? _lastRedirectAt;

  /// 현재 user가 치과 계정으로 로그인된 상태인지 (clinics_accounts 존재 여부).
  /// 같은 uid에 대해 한 번만 조회하고 캐싱한다.
  String? _domainCheckedUid;
  bool _isClinicAccount = false;
  bool _checkingDomain = false;

  Future<void> _ensureDomainChecked(User user) async {
    if (_domainCheckedUid == user.uid || _checkingDomain) return;
    _checkingDomain = true;
    try {
      final status = await ClinicAuthService.getStatus();
      if (!mounted) return;
      setState(() {
        _domainCheckedUid = user.uid;
        _isClinicAccount = status.exists;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _domainCheckedUid = user.uid;
        _isClinicAccount = false;
      });
    } finally {
      _checkingDomain = false;
    }
  }

  /// 라우터 [redirect]와 동일 정책: `next`가 안전할 때만 사용, 아니면 홈
  String _postAuthDestination() {
    final next = widget.nextRoute;
    if (next != null &&
        next.isNotEmpty &&
        next.startsWith('/') &&
        !next.startsWith('//')) {
      return next;
    }
    return '/';
  }

  /// `/login`에 멈춰 있을 때 사용자가 직접 다시 시도할 수 있는 강제 새로고침
  void _retryNavigation() {
    setState(() {
      _lastRedirectedUid = null;
      _lastRedirectAt = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSessionGateScaffold(message: '세션 확인 중…');
        }

        final user = snapshot.data;
        // ?next= 가 명시적으로 지정된 경우에만 자동 이동(로그인 후 원래 가려던 곳)
        final next = widget.nextRoute;
        final hasExplicitNext = next != null &&
            next.isNotEmpty &&
            next.startsWith('/') &&
            !next.startsWith('//');
        if (user != null && hasExplicitNext) {
          final now = DateTime.now();
          final isCooldown = _lastRedirectedUid == user.uid &&
              _lastRedirectAt != null &&
              now.difference(_lastRedirectAt!).inSeconds < 3;
          if (!isCooldown) {
            _lastRedirectedUid = user.uid;
            _lastRedirectAt = now;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              context.go(_postAuthDestination());
            });
          }
          return _buildSessionGateScaffold(
            message: '이미 로그인되어 있습니다. 이동 중…',
            showStuckHelp: true,
            onRetry: _retryNavigation,
          );
        }

        return Scaffold(
          backgroundColor: AppColors.white,
          body: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl,
                      vertical: AppSpacing.xxl,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 960),
                          child: SizedBox(
                            width: double.infinity,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(child: _buildLogo()),
                                const SizedBox(height: AppSpacing.xxl),

                                // ── 좌(지원자) / 우(치과) ────────────────
                                LayoutBuilder(
                                  builder: (context, innerConstraints) {
                                    // 로그인된 도메인 판정.
                                    // - user == null: 양쪽 모두 로그인 카드
                                    // - user != null && 치과 계정: 우측만 "로그인됨"
                                    // - user != null && 지원자 계정: 좌측만 "로그인됨"
                                    if (user != null) {
                                      // 비동기 도메인 판정 트리거 (이미 캐시된 uid면 no-op)
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        _ensureDomainChecked(user);
                                      });
                                    }
                                    final domainKnown =
                                        user != null && _domainCheckedUid == user.uid;
                                    final isClinicSignedIn =
                                        domainKnown && _isClinicAccount;
                                    final isApplicantSignedIn =
                                        domainKnown && !_isClinicAccount;

                                    final clinicSlot = isClinicSignedIn
                                        ? _SignedInStatusCard(
                                            user: user,
                                            domain: _SignedInDomain.clinic,
                                          )
                                        : _ClinicLoginCard(
                                            nextRoute: widget.nextRoute,
                                          );
                                    final applicantSlot = isApplicantSignedIn
                                        ? _SignedInStatusCard(
                                            user: user,
                                            domain: _SignedInDomain.applicant,
                                          )
                                        : _ApplicantLoginCard(
                                            nextRoute: widget.nextRoute,
                                          );

                                    Widget verticalDivider({double h = 108}) =>
                                        SizedBox(
                                          width: 48,
                                          child: Center(
                                            child: Container(
                                              width: 1,
                                              height: h,
                                              decoration: BoxDecoration(
                                                color: AppColors.divider,
                                                borderRadius:
                                                    BorderRadius.circular(0.5),
                                              ),
                                            ),
                                          ),
                                        );
                                    Widget horizontalDivider() => Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 20,
                                          ),
                                          child: Center(
                                            child: Container(
                                              width: 96,
                                              height: 1,
                                              decoration: BoxDecoration(
                                                color: AppColors.divider,
                                                borderRadius:
                                                    BorderRadius.circular(0.5),
                                              ),
                                            ),
                                          ),
                                        );

                                    if (innerConstraints.maxWidth < 620) {
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          applicantSlot,
                                          horizontalDivider(),
                                          clinicSlot,
                                        ],
                                      );
                                    }
                                    return IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(child: applicantSlot),
                                          verticalDivider(),
                                          Expanded(child: clinicSlot),
                                        ],
                                      ),
                                    );
                                  },
                                ),

                                const SizedBox(height: AppSpacing.xxl),

                                // ── 하단 사업자 정보 · 약관 ───────────────
                                const Padding(
                                  padding: EdgeInsets.only(top: AppSpacing.md),
                                  child: WebSiteFooter(
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSessionGateScaffold({
    required String message,
    bool showStuckHelp = false,
    VoidCallback? onRetry,
  }) {
    return Scaffold(
      backgroundColor: AppColors.white,
      bottomNavigationBar: const WebSiteFooter(),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.accent),
            const SizedBox(height: 20),
            Text(
              message,
              style: GoogleFonts.notoSansKr(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            if (showStuckHelp) ...[
              const SizedBox(height: 28),
              Text(
                '이동이 진행되지 않으면 아래 버튼을 눌러 주세요.',
                style: GoogleFonts.notoSansKr(
                  fontSize: 12,
                  color: AppColors.textDisabled,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onRetry != null)
                    TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('다시 시도'),
                    ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () async {
                      try {
                        await FirebaseAuth.instance.signOut();
                      } catch (_) {}
                      if (!mounted) return;
                      context.go('/login');
                    },
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('로그아웃 후 다시 로그인'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        const HygieneLabEnglishTitle(
          fontSize: 31.2,
          letterSpacing: 0.18,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 2),
        Text(
          '하이진랩',
          style: TextStyle(
            fontSize: 19.5,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
            fontFamily: 'Apple SD Gothic Neo',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '치과인의 커리어 연구소',
          style: GoogleFonts.notoSansKr(
            fontSize: 16.9,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 지원자 로그인 카드 (소셜 + 이메일)
// ═══════════════════════════════════════════════════════════════
class _ApplicantLoginCard extends StatefulWidget {
  final String? nextRoute;
  const _ApplicantLoginCard({this.nextRoute});

  @override
  State<_ApplicantLoginCard> createState() => _ApplicantLoginCardState();
}

class _ApplicantLoginCardState extends State<_ApplicantLoginCard> {
  bool _isLoading = false;
  String? _loadingProvider;
  String? _errorMsg;
  bool _showEmailForm = false;
  bool _isSignUp = false;
  String? _lastProvider;

  // 네이버 비밀번호 설정 링크 전송 폼
  bool _showNaverResetForm = false;
  bool _naverResetSent = false;
  bool _naverResetLoading = false;
  final _naverEmailCtrl = TextEditingController();

  // 네이버 비밀번호 설정 완료 기록 (SharedPreferences)
  String? _naverPwSetEmail;

  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBadge();
  }

  Future<void> _loadBadge() async {
    final p = await SignInTracker.getLocalLastProvider();
    final prefs = await SharedPreferences.getInstance();
    final naverEmail = prefs.getString('naver_pw_set_email');
    if (mounted) {
      setState(() {
        _lastProvider = p;
        _naverPwSetEmail = naverEmail;
        if (naverEmail != null) {
          _showEmailForm = true;
          _emailCtrl.text = naverEmail;
        }
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _naverEmailCtrl.dispose();
    super.dispose();
  }

  // ── 로그인 후 공통 라우팅 ──────────────────────────────────
  Future<void> _handlePostLogin(
    String provider, {
    bool isSignUp = false,
    String? emailHint,
  }) async {
    if (!mounted) return;

    if (FirebaseAuth.instance.currentUser?.uid == null) return;

    try {
      final blocked =
          await ClinicAuthService.blockClinicAccountFromApplicantLogin();
      if (blocked != null) {
        if (!mounted) return;
        _showError(blocked);
        return;
      }

      await SignInTracker.record(provider, email: emailHint);
      // 앱 [SignInPage]와 동일: 로그인 성공 후 uid가 있을 때만 기록 (①~③)
      AdminActivityService.log(
        ActivityEventType.viewSignInPage,
        page: 'sign_in',
      );
      AdminActivityService.log(
        ActivityEventType.loginSuccess,
        page: 'sign_in',
        extra: {
          'provider': provider,
          'platform': 'web',
          if (provider == 'email') 'isSignUp': isSignUp,
        },
      );
      AdminActivityService.logFunnel(
        FunnelEventType.signupComplete,
        extra: {'provider': provider, 'platform': 'web'},
      );
      if (!mounted) return;
      context.go(widget.nextRoute ?? '/applicant/resumes');
    } catch (_) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
      if (mounted) {
        _showError('로그인 확인 중 오류가 발생했어요. 잠시 후 다시 시도해주세요.');
      }
    }
  }

  // ── 카카오 ─────────────────────────────────────────────────
  Future<void> _loginKakao() async {
    AdminActivityService.log(ActivityEventType.tapLoginKakao, page: 'sign_in');
    _setLoading('kakao');
    try {
      final user = await KakaoAuthService.signInWithKakao();
      if (user == null) {
        _showError('카카오 로그인에 실패했어요. 다시 시도해주세요.');
        return;
      }
      await _handlePostLogin('kakao');
    } catch (e) {
      _showError('카카오 로그인 오류: $e');
    } finally {
      _clearLoading();
    }
  }

  // ── 구글 ───────────────────────────────────────────────────
  Future<void> _loginGoogle() async {
    AdminActivityService.log(ActivityEventType.tapLoginGoogle, page: 'sign_in');
    _setLoading('google');
    try {
      // 웹에서는 signInWithPopup 방식 사용 (idToken null 문제 해결)
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      final userCredential = await FirebaseAuth.instance.signInWithPopup(
        googleProvider,
      );

      if (userCredential.user == null) {
        _showError('Google 로그인에 실패했어요.');
        return;
      }
      await _handlePostLogin('google');
    } catch (e) {
      _showError('Google 로그인 오류: $e');
    } finally {
      _clearLoading();
    }
  }

  // ── 애플 ───────────────────────────────────────────────────
  Future<void> _loginApple() async {
    AdminActivityService.log(ActivityEventType.tapLoginApple, page: 'sign_in');
    _setLoading('apple');
    try {
      final appleRes = await AppleAuthService.signInWithApple();
      if (appleRes == null) {
        _showError('Apple 로그인에 실패했어요.');
        return;
      }
      final (user, appleIdEmail) = appleRes;
      await _handlePostLogin('apple', emailHint: appleIdEmail ?? user.email);
    } catch (e) {
      _showError('Apple 로그인 오류: $e');
    } finally {
      _clearLoading();
    }
  }

  // ── 네이버 웹 비밀번호 설정 링크 발송 ──────────────────────
  Future<void> _sendNaverPasswordReset() async {
    final email = _naverEmailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMsg = '올바른 이메일 주소를 입력해주세요.');
      return;
    }
    setState(() {
      _naverResetLoading = true;
      _errorMsg = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        // SharedPreferences에 네이버 이메일 저장 → 다음 방문 시 안내
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('naver_pw_set_email', email);
        setState(() {
          _naverResetSent = true;
          _naverResetLoading = false;
          _naverPwSetEmail = email;
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _naverResetLoading = false;
          _errorMsg =
              e.code == 'user-not-found'
                  ? '등록된 이메일이 아니에요. 가입한 네이버 이메일을 다시 확인해주세요.'
                  : '발송 중 오류가 발생했어요. 다시 시도해주세요.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _naverResetLoading = false;
          _errorMsg = '발송 중 오류가 발생했어요. 다시 시도해주세요.';
        });
      }
    }
  }

  // ── 이메일 ─────────────────────────────────────────────────
  Future<void> _loginEmail() async {
    final email = _emailCtrl.text.trim();
    final password = _pwCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showError('이메일과 비밀번호를 입력해주세요.');
      return;
    }
    AdminActivityService.log(ActivityEventType.tapLoginEmail, page: 'sign_in');
    _setLoading('email');
    try {
      User? user;
      if (_isSignUp) {
        if (password.length < 8) {
          _showError('비밀번호는 8자 이상이어야 해요.');
          return;
        }
        // 회원가입 전: 공고자 계정 중복 체크 (normalizedEmail 기준)
        final dupMsg = await ClinicAuthService.checkDuplicateForApplicantSignup(
          email,
        );
        if (dupMsg != null) {
          _showError(dupMsg);
          return;
        }
        user = await EmailAuthService.signUp(email: email, password: password);
      } else {
        user = await EmailAuthService.signIn(email: email, password: password);
      }
      if (user == null) {
        _showError(_isSignUp ? '회원가입에 실패했어요.' : '로그인에 실패했어요.');
        return;
      }
      await _handlePostLogin('email', isSignUp: _isSignUp);
    } on FirebaseAuthException catch (e) {
      _showError(_mapAuthError(e.code));
    } catch (e) {
      _showError('이메일 로그인 오류: $e');
    } finally {
      _clearLoading();
    }
  }

  // ── 헬퍼 ───────────────────────────────────────────────────
  void _setLoading(String p) {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadingProvider = p;
        _errorMsg = null;
      });
    }
  }

  void _clearLoading() {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _loadingProvider = null;
      });
    }
  }

  void _showError(String msg) {
    if (mounted) setState(() => _errorMsg = msg);
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return '등록되지 않은 이메일이에요.';
      case 'wrong-password':
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 올바르지 않아요.';
      case 'email-already-in-use':
        return '이미 사용 중인 이메일이에요.';
      case 'weak-password':
        return '비밀번호가 너무 약해요.';
      default:
        return '로그인 중 오류가 발생했어요.';
    }
  }

  // ── UI ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.divider.withOpacity(0.25),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 제목 ─────────────────────────────
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '지원자 (치과위생사)',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '이력서 작성 · 공고 지원',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── 소셜 로그인 버튼들 ──────────────
          _snsBtn(
            'kakao',
            _WebLoginSnsAssets.kakao,
            '카카오로 로그인',
            const Color(0xFFFEE500),
            Colors.black87,
            _loginKakao,
          ),
          const SizedBox(height: AppSpacing.sm),
          _snsBtn(
            'google',
            _WebLoginSnsAssets.google,
            'Google로 로그인',
            AppColors.white,
            Colors.black87,
            _loginGoogle,
            border: AppColors.divider,
          ),
          const SizedBox(height: AppSpacing.sm),
          _snsBtn(
            'apple',
            _WebLoginSnsAssets.apple,
            'Apple로 로그인',
            Colors.black,
            AppColors.white,
            _loginApple,
          ),
          const SizedBox(height: AppSpacing.sm),

          // 네이버 (웹: 비밀번호 설정 링크 방식)
          _snsBtn(
            'naver',
            _WebLoginSnsAssets.naver,
            '네이버로 로그인',
            _naverPwSetEmail != null
                ? AppColors.textDisabled
                : AppColors.naverLoginGreen,
            AppColors.white,
            _naverPwSetEmail != null
                ? null
                : () {
                  setState(() {
                    _showNaverResetForm = !_showNaverResetForm;
                    _naverResetSent = false;
                    _naverEmailCtrl.clear();
                    _errorMsg = null;
                  });
                },
            trailingLabel:
                _naverPwSetEmail != null
                    ? '이메일+비밀번호로 로그인하세요'
                    : '웹에서는 비밀번호 설정이 필요해요',
            trailingBadgeBg:
                _naverPwSetEmail != null
                    ? AppColors.textDisabled.withOpacity(0.25)
                    : AppColors.naverLoginGreen.withOpacity(0.3),
          ),

          // 네이버 비밀번호 설정 완료 시 이메일 폼 안내
          if (_naverPwSetEmail != null && _showEmailForm) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.naverLoginGreen.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.naverLoginGreen.withOpacity(0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: AppColors.naverLoginGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '네이버 이메일 + 설정한 비밀번호로 로그인하세요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary.withOpacity(0.75),
                        height: 1.4,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('naver_pw_set_email');
                      if (mounted) {
                        setState(() {
                          _naverPwSetEmail = null;
                          _emailCtrl.clear();
                          _showEmailForm = false;
                        });
                      }
                    },
                    child: Text(
                      '초기화',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withOpacity(0.6),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 네이버 비밀번호 설정 링크 폼 (토글)
          if (_showNaverResetForm) ...[
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.naverLoginGreen.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.naverLoginGreen.withOpacity(0.25),
                ),
              ),
              child:
                  _naverResetSent
                      ? Column(
                        children: [
                          const Icon(
                            Icons.mark_email_read_outlined,
                            color: AppColors.naverLoginGreen,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '비밀번호 설정 링크를 보냈어요!\n메일함을 확인해주세요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed:
                                () => setState(() {
                                  _naverResetSent = false;
                                  _naverEmailCtrl.clear();
                                }),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                            ),
                            child: const Text(
                              '다시 입력하기',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.naverLoginGreen,
                              ),
                            ),
                          ),
                        ],
                      )
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '네이버로 가입한 이메일 주소를 입력하면\n비밀번호 설정 링크를 보내드려요.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          PubTextField(
                            controller: _naverEmailCtrl,
                            label: '가입한 네이버 이메일',
                            hint: 'example@naver.com',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed:
                                  _naverResetLoading
                                      ? null
                                      : _sendNaverPasswordReset,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.naverLoginGreen,
                                foregroundColor: AppColors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child:
                                  _naverResetLoading
                                      ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.white,
                                        ),
                                      )
                                      : const Text(
                                        '메일로 비밀번호 설정 링크 보내기',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                            ),
                          ),
                        ],
                      ),
            ),
          ],

          const SizedBox(height: 12),

          // ── 이메일 로그인 (앱 블루 · 흰색 볼드 + 아이콘) ───────
          if (!_showEmailForm)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed:
                    () => setState(() {
                      _showEmailForm = true;
                      _errorMsg = null;
                    }),
                icon: SizedBox(
                  width: 22,
                  height: 22,
                  child: SvgPicture.asset(
                    _WebLoginSnsAssets.email,
                    fit: BoxFit.contain,
                    colorFilter: const ColorFilter.mode(
                      AppColors.white,
                      BlendMode.srcIn,
                    ),
                    semanticsLabel: '이메일로 로그인',
                  ),
                ),
                label: Text(
                  '이메일로 로그인',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          else ...[
            PubTextField(
              controller: _emailCtrl,
              label: '이메일',
              hint: 'email@example.com',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.sm),
            PubTextField(controller: _pwCtrl, label: '비밀번호', obscure: true),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (_loadingProvider == 'email') ? null : _loginEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    (_loadingProvider == 'email')
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                        : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isSignUp
                                  ? Icons.person_add_outlined
                                  : Icons.login_rounded,
                              color: AppColors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isSignUp ? '회원가입' : '로그인',
                              style: GoogleFonts.notoSansKr(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.white,
                              ),
                            ),
                          ],
                        ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(
                  _isSignUp ? '이미 계정이 있어요' : '아직 계정이 없어요 (회원가입)',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],

          // ── 에러 메시지 ────────────────────
          if (_errorMsg != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: AppColors.error.withOpacity(0.8),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMsg!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.error.withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 소셜 로그인 버튼 (마지막 로그인 배지 포함)
  Widget _snsBtn(
    String provider,
    String iconAsset,
    String label,
    Color bgColor,
    Color fgColor,
    VoidCallback? onPressed, {
    Color? border,
    String? trailingLabel,
    Color? trailingBadgeBg,
  }) {
    final isLast = _lastProvider == provider;
    final busy = _loadingProvider == provider;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            icon:
                busy
                    ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fgColor,
                      ),
                    )
                    : SizedBox(
                      width: 24,
                      height: 24,
                      child:
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
                              ),
                    ),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: fgColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (trailingLabel != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: trailingBadgeBg ?? AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      trailingLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            trailingBadgeBg != null
                                ? fgColor.withOpacity(0.85)
                                : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: bgColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side:
                    border != null
                        ? BorderSide(color: border)
                        : BorderSide.none,
              ),
            ),
            onPressed: _isLoading ? null : onPressed,
          ),
        ),

        // "마지막 로그인" 배지
        if (isLast && onPressed != null)
          Positioned(
            right: 8,
            top: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '마지막 로그인',
                style: GoogleFonts.notoSansKr(
                  fontSize: 9,
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

        // 네이버에 마지막 로그인 배지 + 앱 안내
        if (isLast && onPressed == null)
          Positioned(
            right: 8,
            top: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.textDisabled,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '마지막 로그인 (앱)',
                style: GoogleFonts.notoSansKr(
                  fontSize: 9,
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

/// 공고자 로그인 전용 — 밑줄(라인) 입력, 크림 배경 없음
class _ClinicLineTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  const _ClinicLineTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.notoSansKr(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.18,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        hintStyle: GoogleFonts.notoSansKr(
          fontSize: 13,
          letterSpacing: -0.12,
          color: AppColors.textDisabled,
        ),
        labelStyle: GoogleFonts.notoSansKr(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.12,
          color: AppColors.textSecondary,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        isDense: true,
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.divider),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.divider),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.accent, width: 2),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.cardEmphasis),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.cardEmphasis, width: 1.5),
        ),
        filled: false,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 치과 로그인 카드 (이메일/비밀번호)
// ═══════════════════════════════════════════════════════════════
class _ClinicLoginCard extends StatefulWidget {
  final String? nextRoute;
  const _ClinicLoginCard({this.nextRoute});

  @override
  State<_ClinicLoginCard> createState() => _ClinicLoginCardState();
}

class _ClinicLoginCardState extends State<_ClinicLoginCard> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _obscurePw = true;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text,
      );

      if (!mounted) return;
      final status = await ClinicAuthService.getStatus();
      if (!mounted) return;

      if (!status.exists) {
        await ClinicAuthService.initClinicAccount();
      }

      await ClinicAuthService.recordLogin();

      if (!mounted) return;
      context.go(widget.nextRoute ?? '/post-job/input');
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMsg = _mapError(e.code));
    } catch (_) {
      setState(() => _errorMsg = '로그인 중 오류가 발생했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapError(String code) {
    return switch (code) {
      'user-not-found' => '등록되지 않은 이메일이에요.',
      'wrong-password' => '비밀번호가 올바르지 않아요.',
      'invalid-credential' =>
        '이메일 또는 비밀번호를 다시 확인해주세요.\n치과 계정이 없으면 회원가입으로 진행해 주세요.',
      'user-disabled' => '이 계정은 비활성화 상태예요.',
      'too-many-requests' =>
        '로그인 시도가 너무 많아 일시적으로 차단됐어요.\n잠시 후(1~2분) 다시 시도해주세요.',
      _ => '로그인 중 오류가 발생했어요. 다시 시도해주세요.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.divider.withOpacity(0.25),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.business_center_outlined,
                    color: AppColors.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '치과 로그인',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '이미지나 텍스트만 넣으면 AI가 공고를 만들어 드려요',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            _ClinicLineTextField(
              controller: _emailCtrl,
              label: '이메일',
              hint: 'admin@clinic.com',
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return '이메일을 입력해주세요.';
                if (!v.contains('@')) return '올바른 이메일 형식이 아니에요.';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            _ClinicLineTextField(
              controller: _pwCtrl,
              label: '비밀번호',
              obscure: _obscurePw,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePw
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textDisabled,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePw = !_obscurePw),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return '비밀번호를 입력해주세요.';
                return null;
              },
            ),

            if (_errorMsg != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardEmphasis.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border(
                    left: BorderSide(color: AppColors.cardEmphasis, width: 3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: AppColors.cardEmphasis,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMsg!,
                        style: GoogleFonts.notoSansKr(
                          fontSize: 12,
                          letterSpacing: -0.12,
                          color: AppColors.textPrimary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: AppPublisher.ctaHeight,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppPublisher.buttonRadius,
                    ),
                  ),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                        : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_outlined,
                              color: AppColors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '로그인',
                              style: GoogleFonts.notoSansKr(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.18,
                                color: AppColors.white,
                              ),
                            ),
                          ],
                        ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                TextButton(
                  onPressed: () => context.push('/publisher/forgot'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    '비밀번호 찾기',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 12,
                      letterSpacing: -0.12,
                      color: AppColors.textSecondary,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.textDisabled,
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: () => context.push('/publisher/signup'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: BorderSide(color: AppColors.accent.withOpacity(0.45)),
                    backgroundColor: AppColors.accent.withOpacity(0.04),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 18,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppPublisher.buttonRadius,
                      ),
                    ),
                  ),
                  child: Text(
                    '10초만에 회원 가입하기',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 이미 로그인된 사용자에게 보여주는 안내 카드
// ═══════════════════════════════════════════════════════════════
enum _SignedInDomain { clinic, applicant }

class _SignedInStatusCard extends StatelessWidget {
  final User user;
  final _SignedInDomain domain;
  const _SignedInStatusCard({required this.user, required this.domain});

  bool get _isClinic => domain == _SignedInDomain.clinic;

  String get _title => _isClinic
      ? '치과 계정으로 로그인되어 있어요'
      : '지원자 계정으로 로그인되어 있어요';

  String get _ctaLabel => _isClinic ? '공고 시작으로 이동' : '이력서로 이동';

  String get _ctaRoute => _isClinic ? '/post-job/input' : '/applicant/resumes';

  Color get _accentColor =>
      _isClinic ? AppColors.accent : AppColors.success;

  IconData get _badgeIcon => _isClinic
      ? Icons.business_center_outlined
      : Icons.person_outline_rounded;

  String get _displayName {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user.email;
    if (email != null && email.isNotEmpty) return email;
    return '로그인됨';
  }

  String? get _subtitle {
    final email = user.email;
    if (user.displayName?.trim().isNotEmpty == true && email != null) {
      return email;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.divider.withOpacity(0.25),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _badgeIcon,
                  color: _accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _displayName,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (_subtitle != null)
                      Text(
                        _subtitle!,
                        style: GoogleFonts.notoSansKr(
                          fontSize: 12,
                          letterSpacing: -0.3,
                          color: AppColors.textDisabled,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            height: AppPublisher.ctaHeight,
            child: ElevatedButton.icon(
              onPressed: () => context.go(_ctaRoute),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                _ctaLabel,
                style: GoogleFonts.notoSansKr(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppColors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: AppColors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppPublisher.buttonRadius,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  await FirebaseAuth.instance.signOut();
                } catch (_) {}
              },
              icon: const Icon(Icons.logout, size: 16),
              label: Text(
                '로그아웃',
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: AppColors.textSecondary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(color: AppColors.divider),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppPublisher.buttonRadius,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
