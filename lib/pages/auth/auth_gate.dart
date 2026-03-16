import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../home/home_shell.dart';
import 'sign_in_page.dart';
import '../../services/admin_activity_service.dart';
import '../../services/app_error_logger.dart';
import '../../services/onboarding_service.dart';
import '../../services/user_profile_service.dart';
import '../../core/theme/app_colors.dart';

/// 인증 상태 확인 게이트
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    if (user == null) {
      // 로그아웃 상태: 모든 세션 캐시 초기화
      // (어떤 경로로 로그아웃해도 캐시가 정리되도록 방어적 처리)
      AdminActivityService.clearCache();
      AppErrorLogger.clearCache();
      UserProfileService.clearCache();
      return const SignInPage();
    }

    // HomeShell 진입 전에 온보딩 여부를 확정 → race condition 원천 차단
    return const OnboardingGate();
  }
}

/// 로그인 직후 온보딩 필요 여부를 판단하고 HomeShell로 분기
///
/// ── 왜 이 게이트가 필요한가 ────────────────────────────────────
/// 기존 구조:
///   authStateChanges → HomeShell 마운트 → (500ms 후) pendingOnboarding 체크
///   문제: HomeShell이 먼저 마운트되어 pendingOnboarding 저장 전에 체크가 실행됨
///
/// 변경 후:
///   authStateChanges → OnboardingGate → 온보딩 여부 확정 → HomeShell 마운트
///   효과: HomeShell이 처음부터 올바른 상태로 마운트됨, race condition 없음
/// ──────────────────────────────────────────────────────────────
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key});

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool? _shouldOnboard; // null=판단 중, true=온보딩 필요, false=스킵

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final result = await OnboardingService.shouldRunOnboarding();
    if (mounted) setState(() => _shouldOnboard = result);
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldOnboard == null) {
      // 판단 전: 빈 화면 (일반 화면이 잠깐 노출되는 현상 방지)
      // → 기존 HomeShell의 _onboardingChecked=false 가드와 동일한 역할
      return const Scaffold(backgroundColor: AppColors.appBg);
    }
    return HomeShell(startWithOnboarding: _shouldOnboard!);
  }
}

















