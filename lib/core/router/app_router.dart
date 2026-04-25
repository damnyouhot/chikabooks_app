import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'go_router_refresh_stream.dart';
import 'app_route_observer.dart';
import '../../pages/auth/auth_gate.dart';
import '../../pages/job_page.dart';
import '../../pages/hira_update_page.dart';
import '../../pages/ebook/ebook_list_page.dart';
import '../../pages/quiz_today_page.dart';
import '../../pages/admin/admin_dashboard_page.dart';
import '../../features/jobs/web/job_post_web_page.dart';
import '../../features/jobs/web/job_input_page.dart';
import '../../features/jobs/web/job_draft_editor_page.dart';
import '../../features/jobs/web/job_product_select_page.dart';
import '../../features/jobs/web/job_publish_success_page.dart';
import '../../features/jobs/web/legal_page.dart';
import '../../features/jobs/ui/clinic_verify_page.dart';
import '../../features/me/pages/me_overview_page.dart';
import '../../features/me/pages/me_clinic_page.dart';
import '../../features/me/pages/me_verification_page.dart';
import '../../features/me/pages/me_account_page.dart';
import '../../features/me/pages/me_billing_page.dart';
import '../../features/me/pages/me_orders_page.dart';
import '../../features/me/pages/me_applicants_pool_page.dart';
import '../../features/me/pages/me_notifications_page.dart';
import '../../features/auth/web/web_login_page.dart';
import '../../features/auth/web/set_password_page.dart';
import '../../features/payment/payment_result_page.dart';
import '../../features/feedback/feedback_list_page.dart';
import '../../features/feedback/feedback_write_page.dart';
import '../../features/feedback/feedback_detail_page.dart';
import '../../features/publisher/pages/publisher_signup_page.dart';
import '../../features/publisher/pages/publisher_forgot_page.dart';
// 레거시 온보딩 페이지 — 모든 라우트가 /post-job/input으로 리다이렉트
// import '../../features/publisher/pages/publisher_onboarding_page.dart';
// import '../../features/publisher/pages/publisher_verify_phone_page.dart';
// import '../../features/publisher/pages/publisher_profile_page.dart';
// import '../../features/publisher/pages/publisher_verify_business_page.dart';
// import '../../features/publisher/pages/publisher_pending_page.dart';
// import '../../features/publisher/pages/publisher_done_page.dart';
import '../../features/publisher/services/clinic_auth_service.dart';
import '../../features/publisher/services/clinic_profile_service.dart';
import '../../features/resume/screens/resume_home_screen.dart';
import '../../features/resume/screens/resume_edit_screen.dart';
import '../../features/resume/screens/ocr_review_screen.dart';
import '../../services/user_profile_service.dart';
import '../../pages/support_page.dart';

/// 웹에서 세션 복원 후 [redirect]가 재실행되도록 함 (초기 `currentUser == null` 레이스 방지)
final _authRefreshListenable = GoRouterRefreshStream(
  FirebaseAuth.instance.authStateChanges(),
);

// ── 공고 등록 흐름 단계 인덱스 (슬라이드 방향 결정용) ───────────────
//
// /login(또는 / )도 같은 흐름의 -1 단계로 보아, 공고 시작 ↔ 홈(로그인)도
// 동일한 좌우 슬라이드 트랜지션을 적용한다.
int _jobPostStepIndex(String location) {
  if (location.startsWith('/post-job/product')) return 2;
  if (location.startsWith('/post-job/edit')) return 1;
  if (location.startsWith('/post-job/input')) return 0;
  if (location == '/login' || location == '/') return -1;
  return -999; // 흐름 외 라우트
}

/// 직전 라우트의 단계 인덱스를 기억해 좌·우 슬라이드 방향을 결정한다.
int _lastJobPostStepIndex = -999;

/// 공고 흐름(+홈) 페이지 라우트에 좌우 슬라이드 트랜지션 적용
/// - 다음 단계로 갈 때(인덱스 증가): 새 페이지가 오른쪽에서 들어옴
/// - 이전 단계로 갈 때(인덱스 감소): 새 페이지가 왼쪽에서 들어옴
/// - 같은 인덱스로 재빌드되는 경우: 직전 방향을 유지하여 흔들림을 막는다.
CustomTransitionPage<void> _jobPostSlidePage({
  required GoRouterState state,
  required Widget child,
}) {
  final currentIdx = _jobPostStepIndex(state.uri.path);
  final lastIdx = _lastJobPostStepIndex;
  // 동일 인덱스로 재빌드되는 케이스(라우터 refresh 등)는 forward로 두어
  // 의도치 않은 역방향 슬라이드를 방지한다.
  final forward = lastIdx == -999 ? true : currentIdx > lastIdx;
  if (currentIdx != lastIdx) {
    _lastJobPostStepIndex = currentIdx;
  }

  final beginIn = forward ? const Offset(1, 0) : const Offset(-1, 0);
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // 들어오는 페이지만 한쪽에서 미끄러져 들어옴.
      // 나가는 페이지는 그 자리에 정지(secondaryAnimation 사용 안 함) →
      // 위로 덮이는 페이지에 잔여 흔들림이 생기지 않는다.
      return SlideTransition(
        position: Tween<Offset>(
          begin: beginIn,
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
        child: child,
      );
    },
  );
}

final appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: _authRefreshListenable,
  observers: [appRouteObserver],

  // ── 글로벌 리다이렉트: 인증 필요 경로 가드 ──────────────────
  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final path = state.uri.path;

    // ── 웹 전용: 루트(/) 진입 시 항상 웹 플로우로 보냄 ──────────
    // 모바일 HomeShell·앱 온보딩이 웹에 노출되는 것을 차단한다.
    if (kIsWeb && path == '/') {
      return '/login';
    }

    // /login 은 비로그인 전용이지만, 로그인된 상태에서도 페이지 자체에서
    // "현재 로그인됨" 카드를 보여주므로 자동 리다이렉트하지 않는다.
    // (단, ?next= 가 명시적으로 전달된 경우에만 해당 경로로 이동시킨다.)
    if (path == '/login' && user != null) {
      final next = state.uri.queryParameters['next'];
      if (next != null && next.isNotEmpty) {
        if (next.startsWith('/') && !next.startsWith('//')) {
          return next;
        }
      }
      // next가 없으면 그대로 /login에 머무르며 페이지에서 안내한다.
    }

    // 인증 필요 경로 목록
    const guardedPrefixes = [
      '/post-job',
      '/applicant',
      '/clinic-verify',
      '/me',
    ];
    final needsAuth = guardedPrefixes.any((p) => path.startsWith(p));
    if (needsAuth && user == null) {
      return '/login?next=${Uri.encodeComponent(path)}';
    }

    // /me 진입 시에도 치과 마스터(`clinics_accounts`)가 있어야 함
    if (path.startsWith('/me') && user != null) {
      try {
        final status = await ClinicAuthService.getStatus();
        if (!status.exists) {
          final returnTo =
              state.uri.path +
              (state.uri.hasQuery ? '?${state.uri.query}' : '');
          return '/publisher/signup?next=${Uri.encodeComponent(returnTo)}';
        }
        await ClinicProfileService.migrateIfNeeded();
      } catch (_) {
        // /me 는 가입 안내가 우선이지만, Firestore 일시 오류로 무한 대기되지 않도록
        // 가입 페이지로 보내 사용자에게 재시도 기회를 준다.
        final returnTo =
            state.uri.path + (state.uri.hasQuery ? '?${state.uri.query}' : '');
        return '/publisher/signup?next=${Uri.encodeComponent(returnTo)}';
      }
    }

    // 레거시 온보딩 경로는 이제 모두 /post-job/input으로 redirect되므로
    // 별도 가드 불필요 (post-job 가드에서 처리)

    // 회원가입 완료 후 authStateChanges로 GoRouter가 refresh되어
    // 위젯이 rebuild된 경우, clinics_accounts가 이미 있으면 바로 진입시킴
    if (path == '/publisher/signup' && user != null) {
      try {
        final status = await ClinicAuthService.getStatus();
        if (status.exists) return '/post-job/input';
      } catch (_) {
        // 일시 오류 시에는 가입 페이지를 그대로 보여 줘 사용자 차단을 피함
      }
    }

    // 새 공고 플로우: 치과(`clinics_accounts`) 마스터가 있을 때만 진입.
    // (구글 등 비밀번호 없는 세션으로 /post-job 만 들어왔을 때 자동 생성하면
    // 이메일·비밀번호 치과 로그인과 불일치하는 계정이 생김 → 가입/로그인으로 유도)
    if (path.startsWith('/post-job') && user != null) {
      try {
        final status = await ClinicAuthService.getStatus();
        if (!status.exists) {
          final returnTo =
              state.uri.path +
              (state.uri.hasQuery ? '?${state.uri.query}' : '');
          return '/publisher/signup?next=${Uri.encodeComponent(returnTo)}';
        }
        await ClinicProfileService.migrateIfNeeded();
      } catch (e) {
        // Firestore 일시 오류·권한 문제 등으로 redirect가 무한 대기되지 않도록
        // 안전하게 가입 페이지로 보냄 (그곳에서 안내·재시도 가능)
        final returnTo =
            state.uri.path + (state.uri.hasQuery ? '?${state.uri.query}' : '');
        return '/publisher/signup?next=${Uri.encodeComponent(returnTo)}';
      }
    }

    // 관리자 대시보드 접근 가드
    if (path.startsWith('/admin')) {
      if (user == null) return '/';
      final isAdmin = await UserProfileService.isAdmin();
      if (!isAdmin) return '/';
    }

    return null;
  },

  routes: [
    GoRoute(path: '/', builder: (_, __) => const AuthGate()),
    GoRoute(
      path: '/bond',
      builder: (_, __) => const AuthGate(initialTabIndex: 1),
    ),
    GoRoute(
      path: '/growth',
      builder: (_, __) => const AuthGate(initialTabIndex: 2),
    ),

    // ── 새 공고 플로우 ──────────────────────────────────────
    GoRoute(path: '/post-job', builder: (_, __) => const JobPostWebPage()),
    GoRoute(
      path: '/post-job/input',
      pageBuilder:
          (context, state) =>
              _jobPostSlidePage(state: state, child: const JobInputPage()),
    ),
    GoRoute(
      path: '/post-job/edit/:draftId',
      pageBuilder:
          (context, state) => _jobPostSlidePage(
            state: state,
            child: JobDraftEditorPage(
              draftId: state.pathParameters['draftId']!,
            ),
          ),
    ),
    GoRoute(
      path: '/post-job/product/:draftId',
      pageBuilder:
          (context, state) => _jobPostSlidePage(
            state: state,
            child: JobProductSelectPage(
              draftId: state.pathParameters['draftId']!,
            ),
          ),
    ),
    GoRoute(
      path: '/post-job/publish/:draftId',
      // 레거시 경로 → 새 상품 선택 페이지로 리다이렉트
      redirect:
          (_, state) => '/post-job/product/${state.pathParameters['draftId']}',
    ),
    GoRoute(
      path: '/post-job/success/:jobId',
      builder:
          (_, state) =>
              JobPublishSuccessPage(jobId: state.pathParameters['jobId']!),
    ),

    // ── 토스페이먼츠 결제 결과 ────────────────────────────
    GoRoute(
      path: '/post-job/payment/success',
      builder:
          (_, state) => PaymentSuccessPage(
            paymentKey: state.uri.queryParameters['paymentKey'] ?? '',
            orderId: state.uri.queryParameters['orderId'] ?? '',
            amount: state.uri.queryParameters['amount'] ?? '',
          ),
    ),
    GoRoute(
      path: '/post-job/payment/fail',
      builder:
          (_, state) => PaymentFailPage(
            code: state.uri.queryParameters['code'] ?? '',
            message: state.uri.queryParameters['message'] ?? '',
            orderId: state.uri.queryParameters['orderId'] ?? '',
          ),
    ),

    GoRoute(
      path: '/clinic-verify',
      builder:
          (_, state) => ClinicVerifyPage(
            profileId: state.uri.queryParameters['profileId'],
          ),
    ),
    GoRoute(path: '/jobs', builder: (_, __) => const JobPage()),
    GoRoute(path: '/policy', builder: (_, __) => const HiraUpdatePage()),
    GoRoute(path: '/books', builder: (_, __) => const EbookListPage()),
    GoRoute(path: '/quiz', builder: (_, __) => const QuizTodayPage()),

    // ── 관리자 대시보드 ──────────────────────────────────────
    GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardPage()),

    // ── 내 정보(My Page) ─────────────────────────────────────
    GoRoute(path: '/me', builder: (_, __) => const MeOverviewPage()),
    GoRoute(path: '/me/clinic', builder: (_, __) => const MeClinicPage()),
    GoRoute(path: '/me/verify', builder: (_, __) => const MeVerificationPage()),
    GoRoute(path: '/me/billing', builder: (_, __) => const MeBillingPage()),
    GoRoute(path: '/me/orders', builder: (_, __) => const MeOrdersPage()),
    GoRoute(
      path: '/me/applicants',
      builder: (_, __) => const MeApplicantsPoolPage(),
    ),
    GoRoute(
      path: '/me/notifications',
      builder: (_, __) => const MeNotificationsPage(),
    ),
    GoRoute(path: '/me/account', builder: (_, __) => const MeAccountPage()),

    // ── 피드백 게시판 ────────────────────────────────────────
    GoRoute(path: '/feedback', builder: (_, __) => const FeedbackListPage()),
    GoRoute(
      path: '/feedback/write',
      builder: (_, state) {
        final label = state.uri.queryParameters['label'] ?? '';
        final route = state.uri.queryParameters['route'] ?? '/feedback/write';
        return FeedbackWritePage(sourceScreenLabel: label, sourceRoute: route);
      },
    ),
    GoRoute(
      path: '/feedback/:id',
      builder:
          (_, state) =>
              FeedbackDetailPage(feedbackId: state.pathParameters['id']!),
    ),

    // ── 로그인 불필요 — 법적 문서 페이지 ──────────────────
    GoRoute(path: '/privacy', builder: (_, __) => buildPrivacyPage()),
    GoRoute(path: '/terms', builder: (_, __) => buildTermsPage()),
    GoRoute(path: '/refund', builder: (_, __) => buildRefundPage()),
    GoRoute(path: '/support', builder: (_, __) => const SupportPage()),

    // ── Firebase 이메일 액션 링크 (비밀번호 재설정) ──────────
    GoRoute(
      path: '/set-password',
      builder: (_, state) {
        final oobCode = state.uri.queryParameters['oobCode'] ?? '';
        if (oobCode.isNotEmpty) {
          return SetPasswordPage(oobCode: oobCode);
        }
        return const WebLoginPage(nextRoute: null);
      },
    ),

    // ── 통합 로그인 페이지 ────────────────────────────────
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) {
        final next = state.uri.queryParameters['next'];
        return _jobPostSlidePage(
          state: state,
          child: WebLoginPage(nextRoute: next),
        );
      },
    ),

    // ── 레거시 /publisher/login → /login 리다이렉트 ───────
    GoRoute(path: '/publisher/login', redirect: (_, __) => '/login'),

    // ── 지원자 (치과위생사) 전용 라우트 ──────────────────
    GoRoute(
      path: '/applicant/resumes',
      builder: (_, __) => const ResumeHomeScreen(),
    ),
    GoRoute(
      path: '/applicant/resumes/edit/:resumeId',
      builder:
          (_, state) =>
              ResumeEditScreen(resumeId: state.pathParameters['resumeId']!),
    ),
    GoRoute(
      path: '/applicant/resumes/import',
      builder: (_, __) => const OcrReviewScreen(),
    ),

    // ── 치과(구 게시자) 전용 라우트 ──────────────────────
    GoRoute(
      path: '/publisher/signup',
      builder: (_, __) => const PublisherSignupPage(),
    ),
    GoRoute(
      path: '/publisher/forgot',
      builder: (_, __) => const PublisherForgotPage(),
    ),
    // ── 레거시 온보딩 → 새 플로우 리다이렉트 ──────────────
    GoRoute(
      path: '/publisher/onboarding',
      redirect: (_, __) => '/post-job/input',
    ),
    GoRoute(
      path: '/publisher/verify-phone',
      redirect: (_, __) => '/post-job/input',
    ),
    GoRoute(path: '/publisher/profile', redirect: (_, __) => '/post-job/input'),
    GoRoute(
      path: '/publisher/verify-business',
      redirect: (_, __) => '/post-job/input',
    ),
    GoRoute(path: '/publisher/pending', redirect: (_, __) => '/post-job/input'),
    GoRoute(path: '/publisher/done', redirect: (_, __) => '/post-job/input'),
  ],
);
