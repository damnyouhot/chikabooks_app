import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
      if (user != null) {
        return '/post-job/input';
      }
      return '/login';
    }

    // /login 은 비로그인 전용: 이미 로그인됨 → next 우선, 없으면 공고 입력
    if (path == '/login' && user != null) {
      final next = state.uri.queryParameters['next'];
      if (next != null && next.isNotEmpty) {
        if (next.startsWith('/') && !next.startsWith('//')) {
          return next;
        }
      }
      return kIsWeb ? '/post-job/input' : '/';
    }

    // 인증 필요 경로 목록
    const guardedPrefixes = ['/post-job', '/applicant', '/clinic-verify'];
    final needsAuth = guardedPrefixes.any((p) => path.startsWith(p));
    if (needsAuth && user == null) {
      return '/login?next=${Uri.encodeComponent(path)}';
    }

    // 레거시 온보딩 경로는 이제 모두 /post-job/input으로 redirect되므로
    // 별도 가드 불필요 (post-job 가드에서 처리)

    // 회원가입 완료 후 authStateChanges로 GoRouter가 refresh되어
    // 위젯이 rebuild된 경우, clinics_accounts가 이미 있으면 바로 진입시킴
    if (path == '/publisher/signup' && user != null) {
      final status = await ClinicAuthService.getStatus();
      if (status.exists) return '/post-job/input';
    }

    // 새 공고 플로우: 치과(`clinics_accounts`) 마스터가 있을 때만 진입.
    // (구글 등 비밀번호 없는 세션으로 /post-job 만 들어왔을 때 자동 생성하면
    // 이메일·비밀번호 치과 로그인과 불일치하는 계정이 생김 → 가입/로그인으로 유도)
    if (path.startsWith('/post-job') && user != null) {
      final status = await ClinicAuthService.getStatus();
      if (!status.exists) {
        final returnTo =
            state.uri.path +
            (state.uri.hasQuery ? '?${state.uri.query}' : '');
        return '/publisher/signup?next=${Uri.encodeComponent(returnTo)}';
      }
      await ClinicProfileService.migrateIfNeeded();
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

    // ── 새 공고 플로우 ──────────────────────────────────────
    GoRoute(path: '/post-job', builder: (_, __) => const JobPostWebPage()),
    GoRoute(path: '/post-job/input', builder: (_, __) => const JobInputPage()),
    GoRoute(
      path: '/post-job/edit/:draftId',
      builder: (_, state) =>
          JobDraftEditorPage(draftId: state.pathParameters['draftId']!),
    ),
    GoRoute(
      path: '/post-job/product/:draftId',
      builder: (_, state) =>
          JobProductSelectPage(draftId: state.pathParameters['draftId']!),
    ),
    GoRoute(
      path: '/post-job/publish/:draftId',
      // 레거시 경로 → 새 상품 선택 페이지로 리다이렉트
      redirect: (_, state) =>
          '/post-job/product/${state.pathParameters['draftId']}',
    ),
    GoRoute(
      path: '/post-job/success/:jobId',
      builder: (_, state) =>
          JobPublishSuccessPage(jobId: state.pathParameters['jobId']!),
    ),

    // ── 토스페이먼츠 결제 결과 ────────────────────────────
    GoRoute(
      path: '/post-job/payment/success',
      builder: (_, state) => PaymentSuccessPage(
        paymentKey: state.uri.queryParameters['paymentKey'] ?? '',
        orderId: state.uri.queryParameters['orderId'] ?? '',
        amount: state.uri.queryParameters['amount'] ?? '',
      ),
    ),
    GoRoute(
      path: '/post-job/payment/fail',
      builder: (_, state) => PaymentFailPage(
        code: state.uri.queryParameters['code'] ?? '',
        message: state.uri.queryParameters['message'] ?? '',
        orderId: state.uri.queryParameters['orderId'] ?? '',
      ),
    ),

    GoRoute(
      path: '/clinic-verify',
      builder: (_, __) => const ClinicVerifyPage(),
    ),
    GoRoute(path: '/jobs', builder: (_, __) => const JobPage()),
    GoRoute(path: '/policy', builder: (_, __) => const HiraUpdatePage()),
    GoRoute(path: '/books', builder: (_, __) => const EbookListPage()),
    GoRoute(path: '/quiz', builder: (_, __) => const QuizTodayPage()),

    // ── 관리자 대시보드 ──────────────────────────────────────
    GoRoute(
      path: '/admin',
      builder: (_, __) => const AdminDashboardPage(),
    ),

    // ── 피드백 게시판 ────────────────────────────────────────
    GoRoute(
      path: '/feedback',
      builder: (_, __) => const FeedbackListPage(),
    ),
    GoRoute(
      path: '/feedback/write',
      builder: (_, state) {
        final label = state.uri.queryParameters['label'] ?? '';
        final route = state.uri.queryParameters['route'] ?? '/feedback/write';
        return FeedbackWritePage(
          sourceScreenLabel: label,
          sourceRoute: route,
        );
      },
    ),
    GoRoute(
      path: '/feedback/:id',
      builder: (_, state) =>
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
      builder: (_, state) {
        final next = state.uri.queryParameters['next'];
        return WebLoginPage(nextRoute: next);
      },
    ),

    // ── 레거시 /publisher/login → /login 리다이렉트 ───────
    GoRoute(
      path: '/publisher/login',
      redirect: (_, __) => '/login',
    ),

    // ── 지원자 (치과위생사) 전용 라우트 ──────────────────
    GoRoute(
      path: '/applicant/resumes',
      builder: (_, __) => const ResumeHomeScreen(),
    ),
    GoRoute(
      path: '/applicant/resumes/edit/:resumeId',
      builder: (_, state) => ResumeEditScreen(
        resumeId: state.pathParameters['resumeId']!,
      ),
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
    GoRoute(
      path: '/publisher/profile',
      redirect: (_, __) => '/post-job/input',
    ),
    GoRoute(
      path: '/publisher/verify-business',
      redirect: (_, __) => '/post-job/input',
    ),
    GoRoute(
      path: '/publisher/pending',
      redirect: (_, __) => '/post-job/input',
    ),
    GoRoute(
      path: '/publisher/done',
      redirect: (_, __) => '/post-job/input',
    ),
  ],
);
