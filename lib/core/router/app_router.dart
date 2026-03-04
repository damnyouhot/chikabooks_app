import 'package:go_router/go_router.dart';
import '../../pages/auth/auth_gate.dart';
import '../../pages/job_page.dart';
import '../../pages/hira_update_page.dart';
import '../../pages/ebook/ebook_list_page.dart';
import '../../pages/quiz_today_page.dart';
import '../../features/jobs/web/job_post_web_page.dart';
import '../../features/jobs/web/legal_page.dart';
import '../../features/jobs/ui/clinic_verify_page.dart';
import '../../features/auth/web/web_login_page.dart';
import '../../features/publisher/pages/publisher_login_page.dart';
import '../../features/publisher/pages/publisher_signup_page.dart';
import '../../features/publisher/pages/publisher_forgot_page.dart';
import '../../features/publisher/pages/publisher_onboarding_page.dart';
import '../../features/publisher/pages/publisher_verify_phone_page.dart';
import '../../features/publisher/pages/publisher_profile_page.dart';
import '../../features/publisher/pages/publisher_verify_business_page.dart';
import '../../features/publisher/pages/publisher_pending_page.dart';
import '../../features/publisher/pages/publisher_done_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const AuthGate()),
    GoRoute(path: '/post-job', builder: (_, __) => const JobPostWebPage()),
    GoRoute(
      path: '/clinic-verify',
      builder: (_, __) => const ClinicVerifyPage(),
    ),
    GoRoute(path: '/jobs', builder: (_, __) => const JobPage()),
    GoRoute(path: '/policy', builder: (_, __) => const HiraUpdatePage()),
    GoRoute(path: '/books', builder: (_, __) => const EbookListPage()),
    GoRoute(path: '/quiz', builder: (_, __) => const QuizTodayPage()),

    // ── 로그인 불필요 — 법적 문서 페이지 ──────────────────
    GoRoute(path: '/privacy', builder: (_, __) => buildPrivacyPage()),
    GoRoute(path: '/terms', builder: (_, __) => buildTermsPage()),

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

    // ── 치과(구 게시자) 전용 라우트 ──────────────────────
    GoRoute(
      path: '/publisher/signup',
      builder: (_, __) => const PublisherSignupPage(),
    ),
    GoRoute(
      path: '/publisher/forgot',
      builder: (_, __) => const PublisherForgotPage(),
    ),
    GoRoute(
      path: '/publisher/onboarding',
      builder: (_, __) => const PublisherOnboardingPage(),
    ),
    GoRoute(
      path: '/publisher/verify-phone',
      builder: (_, __) => const PublisherVerifyPhonePage(),
    ),
    GoRoute(
      path: '/publisher/profile',
      builder: (_, __) => const PublisherProfilePage(),
    ),
    GoRoute(
      path: '/publisher/verify-business',
      builder: (_, __) => const PublisherVerifyBusinessPage(),
    ),
    GoRoute(
      path: '/publisher/pending',
      builder: (_, __) => const PublisherPendingPage(),
    ),
    GoRoute(
      path: '/publisher/done',
      builder: (_, __) => const PublisherDonePage(),
    ),
  ],
);
