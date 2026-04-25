import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../home/home_shell.dart';
import '../home/clinic_readonly_shell.dart';
import 'sign_in_page.dart';
import '../../features/publisher/services/clinic_auth_service.dart';
import '../../services/admin_activity_service.dart';
import '../../services/app_error_logger.dart';
import '../../services/onboarding_service.dart';
import '../../services/user_profile_service.dart';
import '../../core/theme/app_colors.dart';

/// 인증 상태 확인 게이트
class AuthGate extends StatelessWidget {
  final int initialTabIndex;
  final int initialGrowthSubTabIndex;

  const AuthGate({
    super.key,
    this.initialTabIndex = 0,
    this.initialGrowthSubTabIndex = -1,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();

    if (user == null) {
      AdminActivityService.clearCache();
      AppErrorLogger.clearCache();
      UserProfileService.clearCache();
      return const SignInPage();
    }
    return OnboardingGate(
      initialTabIndex: initialTabIndex,
      initialGrowthSubTabIndex: initialGrowthSubTabIndex,
    );
  }
}

/// 로그인 직후 온보딩 필요 여부와 계정 유형(치과/지원자)을 판단하고 분기
///
/// ── 분기 흐름 ────────────────────────────────────────────────
///   authStateChanges → OnboardingGate
///     ├─ 치과(공고자) 계정 → ClinicReadOnlyShell (공고 열람 전용)
///     └─ 지원자 계정      → HomeShell (온보딩 여부 반영)
/// ────────────────────────────────────────────────────────────
class OnboardingGate extends StatefulWidget {
  final int initialTabIndex;
  final int initialGrowthSubTabIndex;

  const OnboardingGate({
    super.key,
    this.initialTabIndex = 0,
    this.initialGrowthSubTabIndex = -1,
  });

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool? _shouldOnboard; // null=판단 중, true=온보딩 필요, false=스킵
  bool? _isClinic; // null=판단 중, true=치과 계정, false=지원자

  @override
  void initState() {
    super.initState();
    AdminActivityService.warmupCache();
    _check();
  }

  Future<void> _check() async {
    final results = await Future.wait([
      OnboardingService.shouldRunOnboarding(),
      ClinicAuthService.isClinicAccount(),
    ]);
    if (mounted) {
      setState(() {
        _shouldOnboard = results[0];
        _isClinic = results[1];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldOnboard == null || _isClinic == null) {
      return const Scaffold(backgroundColor: AppColors.appBg);
    }
    if (_isClinic!) {
      return const ClinicReadOnlyShell();
    }
    return HomeShell(
      startWithOnboarding: _shouldOnboard!,
      initialTabIndex: widget.initialTabIndex,
      initialGrowthSubTabIndex: widget.initialGrowthSubTabIndex,
    );
  }
}
