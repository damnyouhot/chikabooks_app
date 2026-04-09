import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/admin_activity_service.dart';
import '../../../services/app_error_logger.dart';
import '../../../services/onboarding_service.dart';
import '../../../services/user_profile_service.dart';

/// 웹 이력서·공고 플로우 및 설정 등에서 공유하는 로그아웃·계정 삭제 로직.
class WebAccountActionsService {
  WebAccountActionsService._();

  static Future<void> _clearSessionCaches() async {
    AdminActivityService.clearCache();
    AppErrorLogger.clearCache();
    UserProfileService.clearCache();
  }

  static Future<void> _signOutGoogleAndFirebase() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
  }

  /// 로그아웃 확인 후 세션 정리.
  ///
  /// [afterLogout]이 null이면 `/login`으로 이동하고 스낵바를 띄웁니다(웹 플로우 기본).
  /// 설정 화면 등에서는 `Navigator.pop` 등을 [afterLogout]에 넘깁니다.
  static Future<void> confirmLogout(
    BuildContext context, {
    void Function(BuildContext ctx)? afterLogout,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('로그아웃할까요?'),
            content: const Text('로그아웃하면 다시 로그인해야 내 서재와 구매한 책을 볼 수 있어요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('로그아웃'),
              ),
            ],
          ),
    );

    if (result != true) return;

    await _clearSessionCaches();
    await _signOutGoogleAndFirebase();

    if (!context.mounted) return;

    if (afterLogout != null) {
      afterLogout(context);
    } else {
      context.go('/login');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃 되었어요.')),
      );
    }
  }

  /// 계정 완전 삭제(Callable `deleteMyAccount`).
  ///
  /// [onSuccess]가 null이면 로딩 닫은 뒤 `/login`으로 이동합니다.
  /// 설정 화면에서는 추가 `Navigator.pop` 등을 [onSuccess]에 넘깁니다.
  static Future<void> confirmDeleteAccount(
    BuildContext context, {
    void Function(BuildContext ctx)? onSuccess,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm1 = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('⚠️ 계정을 삭제할까요?'),
            content: const Text(
              '삭제하면 복구할 수 없어요.\n\n'
              '• 개인 기록 및 목표\n'
              '• 파트너 그룹 멤버십\n'
              '• 작성한 게시물 (익명 처리)\n'
              '• 프로필 정보\n\n'
              '모든 데이터가 삭제됩니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                child: const Text('다음'),
              ),
            ],
          ),
    );

    if (confirm1 != true) return;
    if (!context.mounted) return;

    String inputText = '';
    final confirm2 = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('마지막 확인'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('정말로 삭제하려면 아래에 "삭제"라고 입력해주세요.'),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (v) => inputText = v.trim(),
                  decoration: const InputDecoration(
                    hintText: '삭제',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx, inputText == '삭제');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                child: const Text('계정 삭제'),
              ),
            ],
          ),
    );

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
            (_) => const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('계정을 삭제하는 중입니다...'),
                    ],
                  ),
                ),
              ),
            ),
      );
    }

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-northeast3',
      ).httpsCallable('deleteMyAccount');

      await callable.call();

      await OnboardingService.forceSchedule();

      await _clearSessionCaches();

      try {
        await GoogleSignIn().signOut();
        await FirebaseAuth.instance.signOut();
      } catch (_) {}

      if (!context.mounted) return;

      Navigator.of(context).pop();

      if (onSuccess != null) {
        onSuccess(context);
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

      if (!context.mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('계정 삭제 실패: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}
