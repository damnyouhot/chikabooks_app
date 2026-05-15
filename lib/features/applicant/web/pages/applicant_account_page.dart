import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../auth/services/web_account_actions_service.dart';
import '../widgets/applicant_web_shell.dart';

/// `/me/account` (지원자) — 계정 설정 페이지.
///
/// `ApplicantWebShell` 안에 들어가므로 좌측 사이드바가 유지되고 본문은
/// [AppApplicant.contentMaxWidth] 폭으로 자동 제한된다.
///
/// Sprint 2 범위:
///  - 기본 프로필 카드 (이름·이메일·사진)
///  - 연결된 로그인 수단(SNS/이메일) 표시
///  - 로그아웃 / 계정 삭제 진입점 → `WebAccountActionsService` 재사용
class ApplicantAccountPage extends StatelessWidget {
  const ApplicantAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ApplicantWebShell(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          final user = snap.data ?? FirebaseAuth.instance.currentUser;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _PageHeader(),
              const SizedBox(height: 24),
              if (user == null)
                const _NotLoggedInCard()
              else ...[
                _ProfileCard(user: user),
                const SizedBox(height: 24),
                const _SectionLabel('연결된 로그인 수단'),
                const SizedBox(height: 12),
                _LinkedProvidersCard(user: user),
                const SizedBox(height: 24),
                const _SectionLabel('계정 관리'),
                const SizedBox(height: 12),
                const _DangerZoneCard(),
                const SizedBox(height: 60),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '계정 설정',
            style: GoogleFonts.notoSansKr(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '내 프로필과 연결된 로그인 수단을 확인하고, 로그아웃·탈퇴를 관리할 수 있어요.',
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
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
      style: GoogleFonts.notoSansKr(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppColors.textSecondary,
        letterSpacing: -0.2,
      ),
    );
  }
}

class _NotLoggedInCard extends StatelessWidget {
  const _NotLoggedInCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(Icons.lock_outline_rounded,
              size: 40, color: AppColors.textDisabled),
          const SizedBox(height: 12),
          Text(
            '로그인이 필요한 페이지에요.',
            style: GoogleFonts.notoSansKr(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final email = user.email ?? '이메일 미연결';
    final displayName = (user.displayName?.trim().isNotEmpty == true)
        ? user.displayName!.trim()
        : email;
    final initial = displayName.isNotEmpty
        ? displayName.substring(0, 1).toUpperCase()
        : '?';
    final photo = user.photoURL;

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
            backgroundColor: AppColors.accent.withValues(alpha: 0.12),
            backgroundImage: photo != null ? NetworkImage(photo) : null,
            child: photo == null
                ? Text(
                    initial,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
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
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkedProvidersCard extends StatelessWidget {
  const _LinkedProvidersCard({required this.user});
  final User user;

  /// providerId(예: 'google.com', 'password', 'oidc.kakao')와 표시 레이블 매핑.
  static const _labels = <String, String>{
    'password': '이메일 / 비밀번호',
    'google.com': 'Google',
    'apple.com': 'Apple',
    'oidc.kakao': '카카오',
    'oidc.naver': '네이버',
  };

  static const _icons = <String, IconData>{
    'password': Icons.email_outlined,
    'google.com': Icons.g_mobiledata_rounded,
    'apple.com': Icons.apple_rounded,
    'oidc.kakao': Icons.chat_bubble_rounded,
    'oidc.naver': Icons.public_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final ids = user.providerData
        .map((p) => p.providerId)
        .where((id) => id.isNotEmpty)
        .toSet();

    if (ids.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(
          '연결된 로그인 수단이 없어요.',
          style: GoogleFonts.notoSansKr(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    final knownIds =
        ids.where((id) => _labels.containsKey(id)).toList(growable: false);
    final unknownIds =
        ids.where((id) => !_labels.containsKey(id)).toList(growable: false);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          for (int i = 0; i < knownIds.length; i++) ...[
            _ProviderRow(
              icon: _icons[knownIds[i]] ?? Icons.link_rounded,
              label: _labels[knownIds[i]] ?? knownIds[i],
            ),
            if (i < knownIds.length - 1 || unknownIds.isNotEmpty)
              const Divider(height: 1, color: AppColors.divider),
          ],
          for (int i = 0; i < unknownIds.length; i++) ...[
            _ProviderRow(
              icon: Icons.link_rounded,
              label: unknownIds[i],
            ),
            if (i < unknownIds.length - 1)
              const Divider(height: 1, color: AppColors.divider),
          ],
        ],
      ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Text(
              '연결됨',
              style: GoogleFonts.notoSansKr(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerZoneCard extends StatelessWidget {
  const _DangerZoneCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          _ActionRow(
            icon: Icons.logout_rounded,
            iconColor: AppColors.textSecondary,
            label: '로그아웃',
            description: '이 브라우저에서 현재 계정 세션을 종료합니다.',
            onTap: () => WebAccountActionsService.confirmLogout(context),
          ),
          const Divider(height: 1, color: AppColors.divider),
          _ActionRow(
            icon: Icons.delete_outline_rounded,
            iconColor: AppColors.error,
            label: '계정 탈퇴',
            description: '모든 데이터가 영구히 삭제되며, 복구할 수 없어요.',
            destructive: true,
            onTap: () => WebAccountActionsService.confirmDeleteAccount(context),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.description,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String description;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: destructive
                          ? AppColors.error
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textDisabled,
            ),
          ],
        ),
      ),
    );
  }
}
