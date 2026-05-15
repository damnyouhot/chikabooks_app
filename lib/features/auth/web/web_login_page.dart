import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/kakao_auth_service.dart';
import '../../../services/apple_auth_service.dart';
import '../../../services/email_auth_service.dart';
import '../../../services/sign_in_tracker.dart';
import '../../publisher/services/clinic_auth_service.dart';
import '../../publisher/pages/publisher_shared.dart';
import '../services/web_account_actions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/hygiene_lab_english_title.dart';

const _kNaver = Color(0xFF03C75A); // 네이버 브랜드 그린 — 의도적 유지

// ── [CHIKA_WEB_AUTO_LOGIN: BEGIN] ─────────────────────────────────────
// 임시 기능 — 빌드 타임 dart-define 으로만 활성화되는 "테스트 계정 1-click 입장".
// 이 블록과, 아래 _ApplicantLoginCardState 의 [CHIKA_WEB_AUTO_LOGIN] 마커 블록만
// 통째로 제거하면 원복. (검색 키워드: CHIKA_WEB_AUTO_LOGIN)
const bool kChikaAutoLoginOn =
    bool.fromEnvironment('CHIKA_WEB_AUTO_LOGIN', defaultValue: false);
const String kChikaAutoLoginEmail =
    String.fromEnvironment('CHIKA_WEB_AUTO_EMAIL', defaultValue: '');
const String kChikaAutoLoginPassword =
    String.fromEnvironment('CHIKA_WEB_AUTO_PASSWORD', defaultValue: '');
const String kChikaAutoLoginClinicEmail =
    String.fromEnvironment('CHIKA_WEB_AUTO_CLINIC_EMAIL', defaultValue: '');
const String kChikaAutoLoginClinicPassword =
    String.fromEnvironment('CHIKA_WEB_AUTO_CLINIC_PASSWORD', defaultValue: '');
bool get kChikaAutoLoginQuickEntryAvailable =>
    kChikaAutoLoginOn &&
    kChikaAutoLoginEmail.trim().isNotEmpty &&
    kChikaAutoLoginPassword.isNotEmpty;
bool get kChikaAutoLoginClinicQuickEntryAvailable =>
    kChikaAutoLoginOn &&
    kChikaAutoLoginClinicEmail.trim().isNotEmpty &&
    kChikaAutoLoginClinicPassword.isNotEmpty;
// ── [CHIKA_WEB_AUTO_LOGIN: END] ───────────────────────────────────────

/// 로그인 페이지에서 두 카드(좌:지원자 / 우:치과)를 어떻게 그릴지 결정하는 역할 상태.
///
/// - [guest]      : 로그인 안 됨 → 양쪽 모두 로그인 카드.
/// - [loading]    : 로그인됐지만 아직 역할(clinic 계정 여부) 판별 중.
/// - [applicant]  : `clinics_accounts/{uid}` 미존재 → 좌측에 "지원자로 로그인됨"
///                  카드, 우측엔 "치과 계정으로 사용하려면 로그아웃" 안내.
/// - [clinic]     : `clinics_accounts/{uid}` 존재 → 우측에 "치과로 로그인됨"
///                  카드, 좌측엔 "지원자로 사용하려면 로그아웃" 안내.
enum _LoginRole { guest, loading, applicant, clinic }

/// 통합 로그인 페이지 (/login)
///
/// 좌: 지원자 로그인 (카카오 · 구글 · 애플 · 이메일  /  네이버는 앱 전용)
/// 우: 치과 로그인 (이메일/비밀번호)
class WebLoginPage extends StatefulWidget {
  final String? nextRoute;
  const WebLoginPage({super.key, this.nextRoute});

  @override
  State<WebLoginPage> createState() => _WebLoginPageState();
}

class _WebLoginPageState extends State<WebLoginPage> {
  // ── 치과 로그인 폼 → 로그인 성공 후 자동 라우팅용 ──
  bool _clinicLoginRedirectPending = false;
  bool _clinicLoginRedirecting = false;

  // ── 현재 로그인 역할 추적 ──
  _LoginRole _role = _LoginRole.loading;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    final initial = FirebaseAuth.instance.currentUser;
    _role = initial == null ? _LoginRole.guest : _LoginRole.loading;
    if (initial != null) {
      // 페이지 로드 시점에 이미 로그인되어 있으면 사용자가 /login 에 머무를
      // 이유가 없다 → 역할 확정 후 자동으로 공고 보드/지정 경로로 이동시킨다.
      _resolveRole(initial, isInitialEntry: true);
    }
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      if (user == null) {
        setState(() => _role = _LoginRole.guest);
      } else {
        setState(() => _role = _LoginRole.loading);
        // SNS 버튼을 통한 로그인 직후엔 [_handlePostLogin] 이 직접 라우팅하므로
        // 여기서는 자동 이동을 발동시키지 않는다 (이중 navigation 방지).
        _resolveRole(user);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  /// `clinics_accounts/{uid}` 존재 여부로 역할 확정.
  ///
  /// 역할이 확정되면 사용자가 /login 에 머무를 이유가 없으므로 자동으로
  /// 적절한 경로(공고 보드 `/` 또는 nextRoute)로 이동시킨다.
  /// SNS 직후 흐름의 [_handlePostLogin] 과 동일한 destination 으로 가더라도
  /// 두 번째 navigation 은 mounted=false 단계에서 무시되므로 안전하다.
  ///
  /// [isInitialEntry] 는 호출 위치를 로그/디버깅용으로 표기만 한다.
  /// (예전엔 isInitialEntry=false 케이스에서 자동 이동을 막았지만,
  /// SNS 토큰 교환 sync 지연 등으로 [_handlePostLogin] 이 도중에 빠져나가는
  /// 회귀가 보고되어 모든 케이스에서 자동 이동을 보장한다.)
  Future<void> _resolveRole(User user, {bool isInitialEntry = false}) async {
    try {
      final isClinic = await ClinicAuthService.isClinicAccount(user.uid);
      if (!mounted) return;
      // 치과 폼에서 로그인을 갓 트리거했고, 실제 치과 계정으로 확인되면
      // 즉시 새 공고 플로우(또는 nextRoute)로 이동시킨다.
      //
      // ⚠️ setState 보다 *먼저* 분기·라우팅한다.
      // 이유: setState(_role=clinic) 을 먼저 부르면 build 가 한 번 돌면서
      // _LoggedInClinicCard 가 만들어지고, 그 카드의 initState 가 post-frame
      // 으로 `/`(또는 nextRoute) 로 또 navigation 하여 우리가 방금 호출한
      // context.go('/post-job/input') 를 덮어쓰는 회귀가 있었다.
      // 라우팅으로 이미 화면이 바뀔 예정이므로 _role 갱신은 생략.
      if (isClinic && _clinicLoginRedirectPending && !_clinicLoginRedirecting) {
        _clinicLoginRedirecting = true;
        context.go(widget.nextRoute ?? '/post-job/input');
        return;
      }

      setState(
        () => _role = isClinic ? _LoginRole.clinic : _LoginRole.applicant,
      );
      _autoRedirectAfterLogin();
    } catch (_) {
      // Firestore 일시 오류 시: 로그인은 유지하되 안전한 기본값(applicant)으로
      // 폴백한다. (clinics_accounts 권한/네트워크 문제로 무한 로딩 방지)
      if (!mounted) return;
      setState(() => _role = _LoginRole.applicant);
      // 일시 오류라도 자동 이동은 그대로 수행해 사용자가 /login 에 묶이지
      // 않도록 한다.
      _autoRedirectAfterLogin();
    }
  }

  /// 역할 확정 후 자동으로 nextRoute 또는 `/` 로 이동.
  /// (이미 다른 경로(예: [_handlePostLogin])에서 라우팅이 진행되어 widget 이
  /// dispose 됐다면 `mounted` 체크로 안전하게 무시된다.)
  void _autoRedirectAfterLogin() {
    if (!mounted) return;
    final next = widget.nextRoute;
    if (next != null && next.isNotEmpty) {
      context.go(next);
    } else {
      context.go('/');
    }
  }

  void _markClinicLoginStarted() {
    _clinicLoginRedirectPending = true;
  }

  void _clearClinicLoginRedirect() {
    _clinicLoginRedirectPending = false;
    _clinicLoginRedirecting = false;
  }

  // ── 좌측(지원자) 영역 — 역할에 따라 다른 카드 ──
  Widget _buildApplicantSide() {
    switch (_role) {
      case _LoginRole.guest:
      case _LoginRole.loading:
        return _ApplicantLoginCard(nextRoute: widget.nextRoute);
      case _LoginRole.applicant:
        return _LoggedInApplicantCard(
          user: FirebaseAuth.instance.currentUser!,
          nextRoute: widget.nextRoute,
        );
      case _LoginRole.clinic:
        return const _OtherRoleNoticeCard(
          title: '지원자(치과위생사)',
          subtitle: '이력서 작성 · 공고 지원',
          message:
              '현재 치과(공고 등록) 계정으로 로그인되어 있어요.\n'
              '지원자로 사용하려면 로그아웃 후 다시 로그인해 주세요.',
          icon: Icons.person_outline_rounded,
          accent: AppColors.success,
        );
    }
  }

  // ── 우측(치과) 영역 — 역할에 따라 다른 카드 ──
  Widget _buildClinicSide() {
    switch (_role) {
      case _LoginRole.guest:
      case _LoginRole.loading:
        return _ClinicLoginCard(
          nextRoute: widget.nextRoute,
          onLoginStarted: _markClinicLoginStarted,
          onLoginFailed: _clearClinicLoginRedirect,
        );
      case _LoginRole.clinic:
        return _LoggedInClinicCard(
          user: FirebaseAuth.instance.currentUser!,
          nextRoute: widget.nextRoute,
          // 갓 로그인된 흐름에서 부모가 이미 /post-job/input 으로 navigation
          // 했거나 진행 중이라면, 이 카드의 자체 redirect (`/`) 가 그것을
          // 덮어쓰지 않도록 자동 이동을 막는다.
          suppressAutoRedirect:
              _clinicLoginRedirectPending || _clinicLoginRedirecting,
        );
      case _LoginRole.applicant:
        return const _OtherRoleNoticeCard(
          title: '치과 (공고자)',
          subtitle: '공고 등록 · 지원자 관리',
          message:
              '현재 지원자 계정으로 로그인되어 있어요.\n'
              '치과 계정으로 사용하려면 로그아웃 후 다시 로그인해 주세요.',
          icon: Icons.business_center_rounded,
          accent: AppColors.accent,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.xxl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                _buildLogo(),
                const SizedBox(height: AppSpacing.xxl),

                // ── 좌(지원자) / 우(치과) ────────────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 620) {
                      return Column(
                        children: [
                          _buildApplicantSide(),
                          const SizedBox(height: 20),
                          _buildClinicSide(),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildApplicantSide()),
                        const SizedBox(width: 24),
                        Expanded(child: _buildClinicSide()),
                      ],
                    );
                  },
                ),

                const SizedBox(height: AppSpacing.xxl),

                // ── 하단 링크 ────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '© 하이진랩',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textDisabled,
                        ),
                      ),
                      const SizedBox(width: 16),
                      _link('개인정보처리방침', '/privacy'),
                      _dot(),
                      _link('이용약관', '/terms'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        const HygieneLabEnglishTitle(fontSize: 34.8, letterSpacing: 0.21),
        const SizedBox(height: 2),
        Text(
          '하이진랩',
          style: const TextStyle(
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
    );
  }

  Widget _link(String label, String path) {
    return InkWell(
      onTap: () => context.push(path),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.textDisabled,
          ),
        ),
      ),
    );
  }

  Widget _dot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text('·', style: TextStyle(color: AppColors.textDisabled)),
    );
  }
}

/// 치과(공고자) 계정으로 로그인된 상태에서 잠깐이라도 /login 카드가
/// 노출되면 즉시 [_target] 으로 자동 이동시키는 안전장치.
///
/// 부모 위젯의 [_resolveRole] 자동 이동, 또는 SNS 흐름의 [_handlePostLogin]
/// 자동 이동이 어떤 race condition 으로 빠져나갔을 때 마지막 보루로 작동한다.
class _LoggedInClinicCard extends StatefulWidget {
  const _LoggedInClinicCard({
    required this.user,
    this.nextRoute,
    this.suppressAutoRedirect = false,
  });

  final User user;
  final String? nextRoute;

  /// 부모(_WebLoginPageState) 가 이미 명시적인 redirect 를 진행 중이면 true.
  /// 이 카드의 자체 자동 이동(`/`)이 부모의 `/post-job/input` navigation 을
  /// 덮어쓰는 회귀를 막는다.
  final bool suppressAutoRedirect;

  @override
  State<_LoggedInClinicCard> createState() => _LoggedInClinicCardState();
}

class _LoggedInClinicCardState extends State<_LoggedInClinicCard> {
  bool _scheduled = false;

  String get _target {
    final next = widget.nextRoute;
    if (next != null && next.isNotEmpty) return next;
    // 치과는 자기 대시보드/등록 플로우가 자연스러우나, 사용자 요구상
    // 공고 보드(/)에 그대로 머무를 수 있도록 / 를 기본 destination 으로.
    return '/';
  }

  @override
  void initState() {
    super.initState();
    if (!widget.suppressAutoRedirect) {
      _scheduleAutoRedirect();
    }
  }

  void _scheduleAutoRedirect() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(_target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final email = user.email?.trim();
    final displayName = user.displayName?.trim();
    final title =
        displayName != null && displayName.isNotEmpty
            ? displayName
            : email != null && email.isNotEmpty
            ? email
            : '로그인된 계정';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.divider.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '현재 로그인됨',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '치과 공고 등록 계정',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (email != null && email.isNotEmpty && email != title) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          PubPrimaryButton(
            label: '공고 등록으로 돌아가기',
            onPressed: () => context.go(widget.nextRoute ?? '/post-job'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => context.push('/me'),
            icon: const Icon(Icons.account_box_outlined, size: 17),
            label: const Text('내 정보 보기'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: BorderSide(color: AppColors.accent.withValues(alpha: 0.35)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            // 카카오·구글·네이버 SDK 세션까지 모두 끊은 뒤 hard reload.
            // (Firebase 만 signOut 하면 SNS SDK 토큰이 남아 자동 재로그인됨)
            onPressed: () => WebAccountActionsService.confirmLogout(context),
            child: Text(
              '다른 계정으로 로그인',
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
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
  bool _isPasswordReset = false; // 비밀번호 만들기(재설정) 모드
  bool _isSignUp = false;
  String? _lastProvider;
  bool _resetSent = false; // 재설정 이메일 발송 완료 여부
  bool _naverTapped = false; // 네이버 버튼을 한 번 눌렀는지 (→ 비밀번호 만들기 활성화)

  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _resetEmailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBadge();
  }

  Future<void> _loadBadge() async {
    final p = await SignInTracker.getLocalLastProvider();
    if (mounted && p != null) setState(() => _lastProvider = p);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  // ── 로그인 후 공통 라우팅 ──────────────────────────────────
  Future<void> _handlePostLogin(String provider) async {
    // 1) 치과(공고자) 전용 계정으로 SNS 로그인 시도하면 차단.
    //    `clinics_accounts/{uid}`가 존재하면 즉시 signOut + 안내 메시지를 띄운다.
    //    (관리자 화이트리스트 이메일은 통과)
    final blockMsg =
        await ClinicAuthService.blockClinicAccountFromApplicantLogin();
    if (!mounted) return;
    if (blockMsg != null) {
      _showError(blockMsg);
      return;
    }

    await SignInTracker.record(provider);
    if (!mounted) return;

    // 2) 지원자 계정 확정 → 공고 보드(`/`)로 이동.
    //    `FirebaseAuth.instance.currentUser` 는 SNS 토큰 교환 직후 sync 가
    //    살짝 늦을 수 있어 uid null 가드는 두지 않고, 차단 미해당 시점이면
    //    무조건 라우팅을 진행한다. (사용자가 /login 에 묶이는 회귀를 방지)
    //    nextRoute 가 지원자에게 안전한 경로면 그쪽 우선.
    final next = widget.nextRoute;
    final safeNext =
        (next != null && _isApplicantSafePath(next)) ? next : '/';
    context.go(safeNext);
  }

  /// 지원자(일반) 계정이 진입해도 안전한 경로 여부.
  ///
  /// 치과 전용 경로(`/post-job`, `/publisher/...`, `/me/clinic` …)는 가드에서
  /// publisher 회원가입으로 튕기므로 제외한다. `/me` 자체와 지원자 전용 서브
  /// 페이지(`/me/applications`, `/me/resumes`)는 허용한다.
  bool _isApplicantSafePath(String path) {
    if (path.startsWith('/post-job')) return false;
    if (path.startsWith('/publisher')) return false;
    if (path.startsWith('/me')) {
      const meAllowed = <String>{'/me', '/me/applications', '/me/resumes'};
      return meAllowed.any((p) => path == p || path.startsWith('$p/'));
    }
    return path.startsWith('/');
  }

  // ── 카카오 ─────────────────────────────────────────────────
  Future<void> _loginKakao() async {
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
    _setLoading('apple');
    try {
      final user = await AppleAuthService.signInWithApple();
      if (user == null) {
        _showError('Apple 로그인에 실패했어요.');
        return;
      }
      await _handlePostLogin('apple');
    } catch (e) {
      _showError('Apple 로그인 오류: $e');
    } finally {
      _clearLoading();
    }
  }

  // ── 비밀번호 재설정 이메일 발송 ───────────────────────────
  Future<void> _sendPasswordReset() async {
    final email = _resetEmailCtrl.text.trim();
    if (email.isEmpty) {
      _showError('이메일을 입력해주세요.');
      return;
    }
    _setLoading('reset');
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) setState(() => _resetSent = true);
    } on FirebaseAuthException catch (e) {
      _showError(
        e.code == 'user-not-found'
            ? '등록되지 않은 이메일이에요.'
            : '오류가 발생했어요. 다시 시도해주세요.',
      );
    } catch (_) {
      _showError('오류가 발생했어요. 다시 시도해주세요.');
    } finally {
      _clearLoading();
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
    _setLoading('email');
    try {
      User? user;
      if (_isSignUp) {
        if (password.length < 8) {
          _showError('비밀번호는 8자 이상이어야 해요.');
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
      await _handlePostLogin('email');
    } on FirebaseAuthException catch (e) {
      _showError(_mapAuthError(e.code));
    } catch (e) {
      _showError('이메일 로그인 오류: $e');
    } finally {
      _clearLoading();
    }
  }

  // ── [CHIKA_WEB_AUTO_LOGIN: BEGIN] ────────────────────────────────
  // 임시 기능 — 테스트 계정으로 한 번에 로그인 후 공고 보드로 진입.
  // 자격 증명은 빌드 타임 dart-define (kChikaAutoLogin*) 에서만 가져온다.
  // 원복: 본 메서드 + build() 안의 [CHIKA_WEB_AUTO_LOGIN] 블록 + 파일 상단의
  // 같은 이름 마커 블록을 함께 제거. (검색 키워드: CHIKA_WEB_AUTO_LOGIN)
  Future<void> _loginAsTestApplicant() async {
    if (_isLoading) return;
    if (!kChikaAutoLoginQuickEntryAvailable) {
      _showError('테스트 계정 자격 증명이 빌드에 없어요. (.chika_web_login.env 확인)');
      return;
    }
    _setLoading('test_applicant');
    try {
      final auth = FirebaseAuth.instance;
      // 다른 계정으로 이미 로그인돼 있으면 먼저 정리.
      if (auth.currentUser != null) {
        try {
          await auth.signOut();
        } catch (_) {/* 무시 — 이어서 sign-in 시도 */}
      }
      await auth.signInWithEmailAndPassword(
        email: kChikaAutoLoginEmail.trim(),
        password: kChikaAutoLoginPassword,
      );
      if (!mounted) return;
      // 평소 이메일 로그인과 동일 후처리 (clinic 계정 차단 + 라우팅).
      await _handlePostLogin('email');
    } on FirebaseAuthException catch (e) {
      _showError('테스트 계정 입장 실패: ${e.code}');
    } catch (e) {
      _showError('테스트 계정 입장 오류: $e');
    } finally {
      _clearLoading();
    }
  }
  // ── [CHIKA_WEB_AUTO_LOGIN: END] ──────────────────────────────────

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
            Icons.chat_bubble,
            '카카오로 로그인',
            const Color(0xFFFEE500),
            Colors.black87,
            _loginKakao,
          ),
          const SizedBox(height: AppSpacing.sm),
          _snsBtn(
            'google',
            Icons.g_mobiledata,
            'Google로 로그인',
            AppColors.white,
            Colors.black87,
            _loginGoogle,
            border: AppColors.divider,
          ),
          const SizedBox(height: AppSpacing.sm),
          _snsBtn(
            'apple',
            Icons.apple,
            'Apple로 로그인',
            Colors.black,
            AppColors.white,
            _loginApple,
          ),
          const SizedBox(height: AppSpacing.sm),

          // 네이버 (처음엔 활성 — 누르면 비활성으로 바뀌고 아래 "비밀번호 만들기" 활성화)
          _snsBtn(
            'naver',
            Icons.language,
            '네이버로 로그인',
            _naverTapped ? AppColors.surfaceMuted : _kNaver,
            _naverTapped ? AppColors.textDisabled : AppColors.white,
            _naverTapped ? null : () => setState(() => _naverTapped = true),
            trailingLabel: '웹에서는 메일로 로그인 해야 해요',
          ),

          const SizedBox(height: AppSpacing.md),

          // ── 네이버 이용자 비밀번호 만들기 안내 ────────────
          if (!_isPasswordReset && !_showEmailForm) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    !_naverTapped
                        ? null
                        : () => setState(() {
                          _isPasswordReset = true;
                          _showEmailForm = false;
                          _resetSent = false;
                          _errorMsg = null;
                        }),
                icon: Icon(
                  Icons.lock_reset,
                  size: 15,
                  color:
                      _naverTapped ? AppColors.white : AppColors.textDisabled,
                ),
                label: Text(
                  '네이버 로그인 가입자 비밀번호 만들기',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        _naverTapped ? AppColors.white : AppColors.textDisabled,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _naverTapped ? _kNaver : AppColors.surfaceMuted,
                  disabledBackgroundColor: AppColors.surfaceMuted,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '비밀번호 만들기 후 이메일 로그인으로 이용해주세요.',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansKr(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ] else if (_isPasswordReset) ...[
            // ── 비밀번호 재설정 폼 ─────────────────────────
            if (_resetSent) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '재설정 링크를 이메일로 보냈어요.\n메일함을 확인해주세요.',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 12,
                          color: AppColors.success,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed:
                      () => setState(() {
                        _isPasswordReset = false;
                        _resetSent = false;
                        _resetEmailCtrl.clear();
                      }),
                  child: Text(
                    '로그인으로 돌아가기',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ] else ...[
              PubTextField(
                controller: _resetEmailCtrl,
                label: '가입한 네이버 이메일',
                hint: 'email@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      (_loadingProvider == 'reset') ? null : _sendPasswordReset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kNaver,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      (_loadingProvider == 'reset')
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                          : Text(
                            '비밀번호 설정 링크 보내기',
                            style: GoogleFonts.notoSansKr(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed:
                      () => setState(() {
                        _isPasswordReset = false;
                        _resetEmailCtrl.clear();
                        _errorMsg = null;
                      }),
                  child: Text(
                    '취소',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ],

          const SizedBox(height: 18),

          // ── 구분선 ─────────────────────────
          Row(
            children: [
              const Expanded(child: Divider(color: AppColors.divider)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '또는',
                  style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
                ),
              ),
              const Expanded(child: Divider(color: AppColors.divider)),
            ],
          ),
          const SizedBox(height: 14),

          // ── 이메일 로그인 ──────────────────
          if (!_showEmailForm)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(
                  Icons.email_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                label: const Text(
                  '이메일로 로그인',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.divider),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed:
                    () => setState(() {
                      _showEmailForm = true;
                      _isPasswordReset = false;
                      _errorMsg = null;
                    }),
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
              child: ElevatedButton(
                onPressed: (_loadingProvider == 'email') ? null : _loginEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    (_loadingProvider == 'email')
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                        : Text(
                          _isSignUp ? '회원가입' : '로그인',
                          style: GoogleFonts.notoSansKr(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
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

          // ── [CHIKA_WEB_AUTO_LOGIN: BEGIN] 테스트 계정 1-click 입장 ─────
          // dart-define 으로 자격 증명이 박힌 빌드에서만 렌더.
          // 원복: 이 BEGIN ~ END 블록을 통째로 제거.
          if (kChikaAutoLoginQuickEntryAvailable) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildTestAccountQuickEntry(),
          ],
          // ── [CHIKA_WEB_AUTO_LOGIN: END] ─────────────────────────────
        ],
      ),
    );
  }

  // ── [CHIKA_WEB_AUTO_LOGIN: BEGIN] 테스트 계정 진입 패널 위젯 ──────
  Widget _buildTestAccountQuickEntry() {
    final busy = _loadingProvider == 'test_applicant';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.science_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                '개발/테스트용 빠른 입장',
                style: GoogleFonts.notoSansKr(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _loginAsTestApplicant,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(
                '테스트 계정($kChikaAutoLoginEmail)으로 입장',
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '※ .chika_web_login.env 의 자격 증명을 사용하는 임시 테스트용 버튼이에요.\n'
            '   (검색 키워드: CHIKA_WEB_AUTO_LOGIN — 운영 빌드에는 노출되지 않음)',
            style: GoogleFonts.notoSansKr(
              fontSize: 11,
              height: 1.5,
              color: AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
  // ── [CHIKA_WEB_AUTO_LOGIN: END] ──────────────────────────────────

  /// 소셜 로그인 버튼 (마지막 로그인 배지 포함)
  Widget _snsBtn(
    String provider,
    IconData icon,
    String label,
    Color bgColor,
    Color fgColor,
    VoidCallback? onPressed, {
    Color? border,
    String? trailingLabel,
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
                    : Icon(icon, color: fgColor, size: 22),
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
                  Text(
                    '·',
                    style: TextStyle(
                      color: fgColor.withOpacity(0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    trailingLabel,
                    style: TextStyle(
                      color: fgColor.withOpacity(0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

// ═══════════════════════════════════════════════════════════════
// 치과 로그인 카드 (이메일/비밀번호)
// ═══════════════════════════════════════════════════════════════
class _ClinicLoginCard extends StatefulWidget {
  final String? nextRoute;
  final VoidCallback? onLoginStarted;
  final VoidCallback? onLoginFailed;

  const _ClinicLoginCard({
    this.nextRoute,
    this.onLoginStarted,
    this.onLoginFailed,
  });

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
      widget.onLoginStarted?.call();
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text,
      );

      // provider 기록
      await SignInTracker.record('email');
    } on FirebaseAuthException catch (e) {
      widget.onLoginFailed?.call();
      setState(() => _errorMsg = _mapError(e.code));
    } catch (_) {
      widget.onLoginFailed?.call();
      setState(() => _errorMsg = '로그인 중 오류가 발생했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── [CHIKA_WEB_AUTO_LOGIN: BEGIN] ────────────────────────────────
  // 임시 기능 — 치과 테스트 계정으로 한 번에 로그인 후 공고 작성 흐름 진입.
  // 자격 증명은 빌드 타임 dart-define (kChikaAutoLoginClinic*) 에서만 가져온다.
  // 원복: 본 메서드 + build() 안의 [CHIKA_WEB_AUTO_LOGIN] 블록 + 파일 상단의
  // 같은 이름 마커 블록을 함께 제거. (검색 키워드: CHIKA_WEB_AUTO_LOGIN)
  Future<void> _loginAsTestClinic() async {
    if (_isLoading) return;
    if (!kChikaAutoLoginClinicQuickEntryAvailable) {
      setState(() {
        _errorMsg = '테스트 치과 계정 자격 증명이 빌드에 없어요. (.chika_web_login.env 확인)';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      // 부모(_resolveRole) 가 로그인 직후 자동으로 /post-job/input 으로
      // 보내도록 redirect 펜딩 플래그 먼저 세팅.
      widget.onLoginStarted?.call();
      final auth = FirebaseAuth.instance;
      // 다른 계정으로 이미 로그인돼 있으면 먼저 정리.
      if (auth.currentUser != null) {
        try {
          await auth.signOut();
        } catch (_) {/* 무시 — 이어서 sign-in 시도 */}
      }
      await auth.signInWithEmailAndPassword(
        email: kChikaAutoLoginClinicEmail.trim(),
        password: kChikaAutoLoginClinicPassword,
      );
      await SignInTracker.record('email');
      // 라우팅은 부모 위젯 _resolveRole 의 isClinic 분기가 처리.
    } on FirebaseAuthException catch (e) {
      widget.onLoginFailed?.call();
      setState(() => _errorMsg = '테스트 치과 입장 실패: ${e.code}');
    } catch (e) {
      widget.onLoginFailed?.call();
      setState(() => _errorMsg = '테스트 치과 입장 오류: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // ── [CHIKA_WEB_AUTO_LOGIN: END] ──────────────────────────────────

  String _mapError(String code) {
    switch (code) {
      case 'user-not-found':
        return '등록되지 않은 이메일이에요.';
      case 'wrong-password':
        return '비밀번호가 올바르지 않아요.';
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 올바르지 않아요.';
      case 'user-disabled':
        return '이 계정은 비활성화 상태예요.';
      case 'too-many-requests':
        return '시도 횟수를 초과했어요. 잠시 후 다시 시도해주세요.';
      default:
        return '로그인 중 오류가 발생했어요. 다시 시도해주세요.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
            // 아이콘 + 제목
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.business_center_rounded,
                    color: AppColors.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
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
                    Text(
                      '공고 등록 · 지원자 관리',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── 안내 문구 ─────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '치과 계정은 SNS 로그인을 지원하지 않습니다.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'SNS로 가입했다면 비밀번호를 만들어 주세요.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 이메일
            PubTextField(
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

            // 비밀번호
            PubTextField(
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

            // 에러
            if (_errorMsg != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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

            const SizedBox(height: 20),
            PubPrimaryButton(
              label: '로그인',
              isLoading: _isLoading,
              onPressed: _login,
            ),

            const SizedBox(height: AppSpacing.md),

            // 비밀번호 만들기 버튼 (SNS 가입자 대상)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/publisher/forgot'),
                icon: const Icon(Icons.lock_reset, size: 15),
                label: Text(
                  'SNS가입자 비밀번호 만들기',
                  style: GoogleFonts.notoSansKr(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: BorderSide(color: AppColors.accent.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // 비밀번호 찾기 + 회원가입
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => context.push('/publisher/forgot'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: Text(
                    '비밀번호를 잊으셨나요?',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/publisher/signup'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: const Text(
                    '회원가입',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),

            // ── [CHIKA_WEB_AUTO_LOGIN: BEGIN] 치과 테스트 계정 1-click 입장 ──
            // dart-define 으로 자격 증명이 박힌 빌드에서만 렌더.
            // 원복: 이 BEGIN ~ END 블록을 통째로 제거.
            if (kChikaAutoLoginClinicQuickEntryAvailable) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildTestClinicQuickEntry(),
            ],
            // ── [CHIKA_WEB_AUTO_LOGIN: END] ─────────────────────────────
          ],
        ),
      ),
    );
  }

  // ── [CHIKA_WEB_AUTO_LOGIN: BEGIN] 치과 테스트 계정 진입 패널 위젯 ──
  Widget _buildTestClinicQuickEntry() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.science_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                '개발/테스트용 빠른 입장',
                style: GoogleFonts.notoSansKr(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _loginAsTestClinic,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(
                '테스트 치과 계정($kChikaAutoLoginClinicEmail)으로 입장',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '※ .chika_web_login.env 의 자격 증명을 사용하는 임시 테스트용 버튼이에요.\n'
            '   (검색 키워드: CHIKA_WEB_AUTO_LOGIN — 운영 빌드에는 노출되지 않음)',
            style: GoogleFonts.notoSansKr(
              fontSize: 11,
              height: 1.5,
              color: AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
  // ── [CHIKA_WEB_AUTO_LOGIN: END] ──────────────────────────────────
}

// ═══════════════════════════════════════════════════════════════
// 지원자(치과위생사)로 이미 로그인된 상태일 때 좌측에 표시되는 카드.
// 치과 카드(_LoggedInClinicCard)와 시각적 균형을 맞추되, 진입 CTA는
// 지원자 대시보드(`/me`)로 보낸다.
// ═══════════════════════════════════════════════════════════════
/// 지원자(일반) 계정으로 로그인된 상태에서 잠깐이라도 /login 카드가
/// 노출되면 즉시 [_target] 으로 자동 이동시키는 안전장치.
///
/// (부모 [_resolveRole] 또는 SNS 흐름의 [_handlePostLogin] 자동 이동이
/// race condition 으로 빠져나갔을 때 마지막 보루로 작동.)
class _LoggedInApplicantCard extends StatefulWidget {
  const _LoggedInApplicantCard({required this.user, this.nextRoute});

  final User user;
  final String? nextRoute;

  @override
  State<_LoggedInApplicantCard> createState() => _LoggedInApplicantCardState();
}

class _LoggedInApplicantCardState extends State<_LoggedInApplicantCard> {
  bool _scheduled = false;

  String get _target {
    final next = widget.nextRoute;
    if (next != null && next.isNotEmpty) return next;
    return '/';
  }

  @override
  void initState() {
    super.initState();
    _scheduleAutoRedirect();
  }

  void _scheduleAutoRedirect() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(_target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final email = user.email?.trim();
    final displayName = user.displayName?.trim();
    final title =
        displayName != null && displayName.isNotEmpty
            ? displayName
            : email != null && email.isNotEmpty
            ? email
            : '로그인된 계정';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.divider.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '현재 로그인됨',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '지원자 (치과위생사)',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (email != null && email.isNotEmpty && email != title) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  () => context.go(widget.nextRoute ?? '/me'),
              icon: const Icon(Icons.dashboard_outlined, size: 18),
              label: Text(
                '내 정보로 이동',
                style: GoogleFonts.notoSansKr(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            // 모든 SNS SDK 세션까지 정리 후 hard reload (자동 재로그인 방지)
            onPressed: () => WebAccountActionsService.confirmLogout(context),
            child: Text(
              '다른 계정으로 로그인',
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 다른 역할로 로그인되어 있을 때 반대편에 표시하는 안내 카드.
// 예) 치과로 로그인된 상태에서 좌측(지원자) 카드 영역.
// 사용자가 헷갈리지 않도록 "현재 어느 역할인지" + "변경 방법"만 간결히 노출.
// ═══════════════════════════════════════════════════════════════
class _OtherRoleNoticeCard extends StatelessWidget {
  const _OtherRoleNoticeCard({
    required this.title,
    required this.subtitle,
    required this.message,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final String message;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: accent.withValues(alpha: 0.55),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(
              message,
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                height: 1.55,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              // 카카오/구글/네이버 SDK 세션까지 모두 정리 + hard reload.
              onPressed: () => WebAccountActionsService.confirmLogout(context),
              icon: const Icon(Icons.logout, size: 16),
              label: Text(
                '로그아웃하고 다른 계정으로 로그인',
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.divider),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
