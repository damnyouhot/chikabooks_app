import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/widgets/app_modal_scaffold.dart';
import '../../../features/me/providers/me_providers.dart';
import '../../../features/me/services/me_session.dart';
import '../../../services/admin_activity_service.dart';
import '../../../services/app_error_logger.dart';
import '../../../services/naver_auth_service.dart';
import '../../../services/onboarding_service.dart';
import '../../../services/user_profile_service.dart';
import 'logout_reload.dart';

/// 웹 이력서·공고 플로우 및 설정 등에서 공유하는 로그아웃·계정 삭제 로직.
class WebAccountActionsService {
  WebAccountActionsService._();

  /// 계정 삭제 중복 호출 가드.
  /// 더블 클릭/네트워크 재시도로 인해 같은 함수가 동시에 두 번 들어가는 것을 막는다.
  static bool _deletionInFlight = false;

  static Future<void> _clearSessionCaches([BuildContext? context]) async {
    AdminActivityService.clearCache();
    AppErrorLogger.clearCache();
    UserProfileService.clearCache();

    // /me 영역 세션 ValueNotifier 강제 리셋 (이전 사용자의 활성 지점 잔존 방지).
    MeSession.activeBranchId.value = null;

    // Riverpod 의 모든 사용자별 stream provider 를 명시적으로 폐기한다.
    // currentUidProvider 가 authStateChanges 로 자동 갱신되긴 하지만,
    // SDK 의 미세 타이밍에 따라 옛 stream 이 잠깐 새 사용자 화면에 보일 수
    // 있어, 명시적으로 invalidate 해서 즉시 빈 상태로 재시작하도록 강제한다.
    if (context != null) {
      try {
        final container = ProviderScope.containerOf(context, listen: false);
        container.invalidate(clinicProfilesProvider);
        container.invalidate(walletProvider);
        container.invalidate(walletLedgerProvider);
        container.invalidate(notificationPrefsProvider);
        container.invalidate(applicantPoolProvider);
        container.invalidate(meOverviewProvider);
        container.invalidate(currentUidProvider);
        container.invalidate(firebaseAuthStateProvider);
      } catch (e) {
        debugPrint('⚠️ Riverpod invalidate 실패(무시): $e');
      }
    }
  }

  /// 모든 소셜 로그인 SDK + Firebase 세션을 정리한다.
  ///
  /// 카카오/네이버 SDK 세션을 끊지 않으면 탈퇴/로그아웃 직후 자동 재로그인으로
  /// 같은 UID가 즉시 재생성(=부활)되는 문제가 발생하므로, 모두 best-effort로 정리한다.
  /// 각 SDK 호출은 미설치/미설정 플랫폼에서 예외를 던질 수 있으므로 개별 try/catch로 감싼다.
  static Future<void> _clearAllSocialSessions() async {
    try {
      await GoogleSignIn().signOut();
    } catch (e) {
      debugPrint('⚠️ Google signOut 실패(무시): $e');
    }
    try {
      await kakao.UserApi.instance.logout();
    } catch (e) {
      // 카카오 SDK 미초기화/세션 없음/웹 미지원 등 — 정상 케이스 다수
      debugPrint('⚠️ Kakao logout 실패(무시): $e');
    }
    try {
      await NaverAuthService.signOut();
    } catch (e) {
      debugPrint('⚠️ Naver signOut 실패(무시): $e');
    }
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('⚠️ FirebaseAuth signOut 실패(무시): $e');
    }
  }

  /// 세션 캐시 정리 후 모든 소셜 SDK + Firebase 로그아웃(확인 다이얼로그 없음).
  ///
  /// [afterLogout]이 null이면 `/login`으로 이동하고 스낵바를 띄웁니다(웹 플로우 기본).
  /// 설정 화면 등에서는 `Navigator.pop` 등을 [afterLogout]에 넘깁니다.
  static Future<void> confirmLogout(
    BuildContext context, {
    void Function(BuildContext ctx)? afterLogout,
  }) async {
    await _clearSessionCaches(context);
    await _clearAllSocialSessions();

    if (!context.mounted) return;

    if (afterLogout != null) {
      afterLogout(context);
      return;
    }

    // 웹: 메모리에 남은 옛 사용자 상태(stream cache, 위젯 상태)를
    // 가장 확실하게 끊는 방법은 페이지 reload. SPA 라이프사이클을 통째로
    // 새로 시작하므로 계정 간 데이터 누수가 0% 가 된다.
    if (kIsWeb) {
      reloadToLogin();
      return;
    }

    context.go('/login');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('로그아웃 되었어요.')),
    );
  }

  /// 계정 완전 삭제(Callable `deleteMyAccount`).
  ///
  /// [onSuccess]가 null이면 로딩 닫은 뒤 `/login`으로 이동합니다.
  /// 설정 화면에서는 추가 `Navigator.pop` 등을 [onSuccess]에 넘깁니다.
  static Future<void> confirmDeleteAccount(
    BuildContext context, {
    void Function(BuildContext ctx)? onSuccess,
  }) async {
    if (_deletionInFlight) {
      debugPrint('⚠️ confirmDeleteAccount 중복 호출 차단 (이미 진행 중)');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm1 = await showDialog<bool>(
      context: context,
      builder:
          (_) => const AppConfirmModal(
            title: '계정을 삭제할까요?',
            message:
                '삭제하면 복구할 수 없어요.\n\n'
                '• 개인 기록 및 목표\n'
                '• 파트너 그룹 멤버십\n'
                '• 작성한 게시물 (익명 처리)\n'
                '• 프로필 정보\n\n'
                '모든 데이터가 삭제됩니다.',
            confirmLabel: '다음',
            destructive: true,
          ),
    );

    if (confirm1 != true) return;
    if (!context.mounted) return;

    final confirmCtrl = TextEditingController();
    final confirm2 = await showDialog<bool>(
      context: context,
      builder:
          (dialogCtx) => AppModalDialog(
            insetPadding: const EdgeInsets.all(AppSpacing.xl),
            borderOpacity: 0.7,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '마지막 확인',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  '정말로 삭제하려면 아래에 "삭제"라고 입력해주세요.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: confirmCtrl,
                  decoration: const InputDecoration(
                    hintText: '삭제',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          backgroundColor: AppColors.surfaceMuted,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed:
                            () => Navigator.pop(
                              dialogCtx,
                              confirmCtrl.text.trim() == '삭제',
                            ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.cardEmphasis,
                          foregroundColor: AppColors.onCardEmphasis,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('계정 삭제'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
    confirmCtrl.dispose();

    if (!context.mounted) return;
    if (confirm2 != true) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('입력값이 일치하지 않아 취소되었습니다.')),
        );
      }
      return;
    }

    if (context.mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder:
            (_) => AppModalDialog(
              insetPadding: const EdgeInsets.all(AppSpacing.xl),
              borderOpacity: 0.7,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  SizedBox(height: AppSpacing.lg),
                  Text(
                    '계정을 삭제하는 중입니다...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                ],
              ),
            ),
      );
    }

    _deletionInFlight = true;
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-northeast3',
      ).httpsCallable('deleteMyAccount');

      await callable.call();

      if (!context.mounted) return;

      await OnboardingService.forceSchedule();

      if (!context.mounted) return;

      await _clearSessionCaches(context);
      await _clearAllSocialSessions();

      if (!context.mounted) return;

      Navigator.of(context).pop();

      if (onSuccess != null) {
        onSuccess(context);
      } else if (kIsWeb) {
        reloadToLogin();
        return;
      } else {
        context.go('/login');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 계정이 완전히 삭제되었습니다.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ 계정 삭제 실패: $e');

      // 실패해도 로컬 세션은 끊어 사용자가 같은 SNS 토큰으로 즉시
      // 부활하지 않도록 한다(서버에서 일부만 정리됐을 가능성에 대비).
      if (context.mounted) {
        try {
          await _clearSessionCaches(context);
          await _clearAllSocialSessions();
        } catch (_) {}
      }

      if (!context.mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_describeDeletionError(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );

      // 안전 장치: 어떤 결과든 로그인 화면으로 이동시켜 비정상 잔여 세션을 방지.
      if (onSuccess == null && context.mounted) {
        context.go('/login');
      }
    } finally {
      _deletionInFlight = false;
    }
  }

  /// 사용자에게 보여줄 에러 문구를 정리한다.
  /// `[firebase_functions/internal] INTERNAL`처럼 본문이 비어 있는 경우엔
  /// 추측성 메시지 대신 중립적인 안내를 사용한다.
  static String _describeDeletionError(Object error) {
    if (error is FirebaseFunctionsException) {
      final msg = error.message?.trim();
      if (msg == null || msg.isEmpty || msg.toUpperCase() == 'INTERNAL') {
        return '계정 삭제 중 일시적인 오류가 발생했어요. 잠시 후 다시 시도해주세요.';
      }
      return '계정 삭제 실패: $msg';
    }
    return '계정 삭제 실패: $error';
  }
}
