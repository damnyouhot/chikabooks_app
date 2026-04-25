import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart' show AppRadius, AppSpacing;
import '../../auth/services/web_account_actions_service.dart';
import '../../jobs/web/web_typography.dart';
import '../widgets/me_page_shell.dart';

/// /me/account — 계정 설정 페이지
///
/// 기존 자산 재활용:
///  - 계정 탈퇴: [WebAccountActionsService.confirmDeleteAccount] (서버 deleteMyAccount)
///  - 로그아웃: [WebAccountActionsService.confirmLogout]
///
/// Sprint 2 범위: 프로필 표시 + 연결 SNS 표시 + 로그아웃/탈퇴 진입점
/// Sprint 6 확장: 멤버 초대(역할: owner/manager/viewer), 비밀번호 변경
class MeAccountPage extends StatelessWidget {
  const MeAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MePageShell(
      title: '계정 설정',
      activeMenuId: 'account',
      child: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          final user = snap.data ?? FirebaseAuth.instance.currentUser;
          if (user == null) {
            return const _NotLoggedIn();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileCard(user: user),
              const SizedBox(height: AppSpacing.xxl),
              _SectionLabel('연결된 로그인 수단'),
              const SizedBox(height: AppSpacing.md),
              _LinkedProvidersCard(user: user),
              const SizedBox(height: AppSpacing.xxl),
              _SectionLabel('함께 일할 멤버'),
              const SizedBox(height: AppSpacing.md),
              const _MemberInvitePlaceholder(),
              const SizedBox(height: AppSpacing.xxl),
              _SectionLabel('계정 관리'),
              const SizedBox(height: AppSpacing.md),
              _DangerZone(),
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: WebTypo.sectionTitle(color: AppColors.textPrimary),
    );
  }
}

// ── 프로필 카드 ───────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final email = user.email ?? '이메일 없음';
    final displayName =
        (user.displayName?.isNotEmpty ?? false) ? user.displayName! : email;
    final initial =
        displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.accent.withOpacity(0.12),
            backgroundImage: user.photoURL != null
                ? NetworkImage(user.photoURL!)
                : null,
            child: user.photoURL == null
                ? Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName,
                    style: WebTypo.sectionTitle(
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(email,
                    style: WebTypo.caption(
                        color: AppColors.textSecondary, size: 12.5)),
                const SizedBox(height: 4),
                Text('UID · ${_shortUid(user.uid)}',
                    style: WebTypo.caption(
                        color: AppColors.textSecondary, size: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _shortUid(String uid) {
    if (uid.length <= 12) return uid;
    return '${uid.substring(0, 6)}…${uid.substring(uid.length - 4)}';
  }
}

// ── 연결된 로그인 수단 ─────────────────────────────────
class _LinkedProvidersCard extends StatelessWidget {
  const _LinkedProvidersCard({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final providers = user.providerData
        .map((p) => p.providerId)
        .toSet()
        .toList()
      ..sort();

    final knownIcons = {
      'google.com': (Icons.g_mobiledata, '구글', const Color(0xFFEA4335)),
      'password': (Icons.email_outlined, '이메일', AppColors.accent),
      'apple.com': (Icons.apple, '애플', AppColors.textPrimary),
      'oidc.kakao': (Icons.chat_bubble_outline, '카카오', const Color(0xFFFEE500)),
      'oidc.naver': (Icons.public, '네이버', const Color(0xFF03C75A)),
    };

    // UID prefix 기반 fallback (커스텀 토큰 카카오/네이버 로그인)
    String? customProvider;
    if (user.uid.startsWith('kakao')) customProvider = 'kakao';
    if (user.uid.startsWith('naver')) customProvider = 'naver';

    final items = <Widget>[];
    for (final id in providers) {
      final entry = knownIcons[id];
      if (entry != null) {
        items.add(_ProviderChip(
            icon: entry.$1, label: entry.$2, color: entry.$3));
      } else {
        items.add(_ProviderChip(
            icon: Icons.lock_outline,
            label: id,
            color: AppColors.textSecondary));
      }
    }
    if (items.isEmpty && customProvider != null) {
      items.add(_ProviderChip(
        icon: customProvider == 'kakao'
            ? Icons.chat_bubble_outline
            : Icons.public,
        label: customProvider == 'kakao' ? '카카오' : '네이버',
        color: customProvider == 'kakao'
            ? const Color(0xFFFEE500)
            : const Color(0xFF03C75A),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.isEmpty
                ? [
                    Text('연결된 로그인 수단이 없어요.',
                        style: WebTypo.caption(
                            color: AppColors.textSecondary, size: 12.5))
                  ]
                : items,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '추가 연결·해제는 곧 지원될 예정이에요. 비밀번호 변경 기능도 준비 중입니다.',
                  style: WebTypo.caption(
                      color: AppColors.textSecondary, size: 11.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

// ── 멤버 초대 placeholder ──────────────────────────────
class _MemberInvitePlaceholder extends StatelessWidget {
  const _MemberInvitePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.group_add_outlined,
                color: AppColors.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('실장·인사담당 멤버 초대',
                    style:
                        WebTypo.sectionTitle(color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  '한 계정에 여러 사람이 역할(소유자/관리자/조회자)을 나눠 들어올 수 있어요. Sprint 6에 출시됩니다.',
                  style: WebTypo.caption(
                      color: AppColors.textSecondary, size: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: const Text(
              '준비중',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 위험 영역 (로그아웃/탈퇴) ───────────────────────────
class _DangerZone extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DangerRow(
            icon: Icons.logout,
            title: '로그아웃',
            desc: '이 브라우저에서 로그아웃합니다.',
            actionLabel: '로그아웃',
            actionColor: AppColors.textPrimary,
            onTap: () => WebAccountActionsService.confirmLogout(context),
          ),
          const Divider(height: 28, color: AppColors.divider),
          _DangerRow(
            icon: Icons.delete_forever_outlined,
            title: '계정 영구 삭제',
            desc: '모든 지점·공고·결제 데이터가 영구 삭제됩니다. 되돌릴 수 없어요.',
            actionLabel: '계정 삭제',
            actionColor: AppColors.error,
            onTap: () => WebAccountActionsService.confirmDeleteAccount(
              context,
              onSuccess: (ctx) {
                ctx.go('/login');
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('계정이 영구 삭제되었습니다.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerRow extends StatelessWidget {
  const _DangerRow({
    required this.icon,
    required this.title,
    required this.desc,
    required this.actionLabel,
    required this.actionColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String desc;
  final String actionLabel;
  final Color actionColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: actionColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style:
                      WebTypo.sectionTitle(color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(desc,
                  style: WebTypo.caption(
                      color: AppColors.textSecondary, size: 12.5)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: actionColor,
            side: BorderSide(color: actionColor.withOpacity(0.5)),
          ),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

// ── 로그인 안 됨 안내 ──────────────────────────────────
class _NotLoggedIn extends StatelessWidget {
  const _NotLoggedIn();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Icon(Icons.lock_outline,
              size: 36, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text('로그인이 필요합니다.',
              style: WebTypo.sectionTitle(color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('로그인'),
          ),
        ],
      ),
    );
  }
}
