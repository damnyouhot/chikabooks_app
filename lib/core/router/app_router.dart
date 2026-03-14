import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../pages/auth/auth_gate.dart';
import '../../pages/job_page.dart';
import '../../pages/hira_update_page.dart';
import '../../pages/ebook/ebook_list_page.dart';
import '../../pages/quiz_today_page.dart';
import '../../pages/admin/admin_dashboard_page.dart';
import '../../features/jobs/web/job_post_web_page.dart';
import '../../features/jobs/web/legal_page.dart';
import '../../features/jobs/ui/clinic_verify_page.dart';
import '../../features/auth/web/web_login_page.dart';
import '../../features/publisher/pages/publisher_signup_page.dart';
import '../../features/publisher/pages/publisher_forgot_page.dart';
import '../../features/publisher/pages/publisher_onboarding_page.dart';
import '../../features/publisher/pages/publisher_verify_phone_page.dart';
import '../../features/publisher/pages/publisher_profile_page.dart';
import '../../features/publisher/pages/publisher_verify_business_page.dart';
import '../../features/publisher/pages/publisher_pending_page.dart';
import '../../features/publisher/pages/publisher_done_page.dart';
import '../../features/resume/screens/resume_home_screen.dart';
import '../../features/resume/screens/resume_edit_screen.dart';
import '../../features/resume/screens/ocr_review_screen.dart';
import '../../services/user_profile_service.dart';

final appRouter = GoRouter(
  initialLocation: '/',

  // ── 글로벌 리다이렉트: 인증 필요 경로 가드 ──────────────────
  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final path = state.uri.path;

    // 인증 필요 경로 목록
    const guardedPrefixes = ['/post-job', '/applicant', '/clinic-verify'];
    final needsAuth = guardedPrefixes.any((p) => path.startsWith(p));
    if (needsAuth && user == null) {
      return '/login?next=$path';
    }

    // 관리자 대시보드 접근 가드
    if (path.startsWith('/admin')) {
      if (user == null) return '/';
      final isAdmin = await UserProfileService.isAdmin();
      if (!isAdmin) return '/'; // 비관리자 차단 → 홈으로
    }

    return null;
  },

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

    // ── 관리자 대시보드 ──────────────────────────────────────
    GoRoute(
      path: '/admin',
      builder: (_, __) => const AdminDashboardPage(),
    ),

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
