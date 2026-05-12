import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/hygiene_lab_english_title.dart';
import '../../../auth/services/web_account_actions_service.dart';

/// 웹 일반계정(지원자) 글로벌 상단 헤더.
///
/// 좌측 로고 / 가운데 검색바(슬롯) / 우측 알림·프로필.
/// 사이드바 토글 버튼은 좁은 폭에서만 노출하며, [onMenuTap]을 통해 외부에서 처리한다.
class ApplicantTopBar extends StatelessWidget {
  const ApplicantTopBar({
    super.key,
    this.onMenuTap,
    this.searchSlot,
    this.showMenu = false,
  });

  /// 좁은 폭에서 햄버거 버튼을 눌렀을 때 호출.
  final VoidCallback? onMenuTap;

  /// 가운데 영역에 들어갈 검색바. null 이면 빈 공간.
  final Widget? searchSlot;

  /// 햄버거 메뉴 노출 여부. 부모 셸이 폭에 따라 결정한다.
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppApplicant.topBarHeight,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          if (showMenu) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.menu_rounded,
                color: AppColors.textPrimary,
              ),
              onPressed: onMenuTap,
              tooltip: '메뉴',
            ),
          ] else
            const SizedBox(width: AppApplicant.contentHPadding),

          // ── 로고 ──
          InkWell(
            onTap: () => context.go('/'),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: HygieneLabEnglishTitle(fontSize: 22),
            ),
          ),

          const SizedBox(width: 24),

          // ── 검색바 슬롯 ──
          if (searchSlot != null)
            Expanded(child: searchSlot!)
          else
            const Spacer(),

          const SizedBox(width: 16),

          // ── 프로필 (알림 벨은 Phase 2 알림함 구현 후 노출) ──
          const _AccountButton(),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _AccountButton extends StatelessWidget {
  const _AccountButton();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snap) {
        final user = snap.data;
        if (user == null) {
          return TextButton.icon(
            onPressed: () => context.push('/login'),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: Text(
              '로그인',
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          );
        }

        final displayName = (user.displayName?.trim().isNotEmpty == true)
            ? user.displayName!.trim()
            : (user.email?.split('@').first ?? '내 계정');

        return PopupMenuButton<String>(
          tooltip: '내 계정',
          offset: const Offset(0, 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                  backgroundImage: user.photoURL != null
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: user.photoURL == null
                      ? Icon(
                          Icons.person_outline,
                          size: 16,
                          color: AppColors.accent,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  displayName,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          itemBuilder: (ctx) => [
            PopupMenuItem<String>(
              value: 'me',
              child: _menuRow(Icons.dashboard_outlined, '내 정보'),
            ),
            PopupMenuItem<String>(
              value: 'resumes',
              child: _menuRow(Icons.description_outlined, '이력서 관리'),
            ),
            PopupMenuItem<String>(
              value: 'applications',
              child: _menuRow(Icons.send_outlined, '내 지원 내역'),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'logout',
              child: _menuRow(Icons.logout_rounded, '로그아웃'),
            ),
          ],
          onSelected: (v) async {
            if (!context.mounted) return;
            switch (v) {
              case 'me':
                context.push('/me');
                break;
              case 'resumes':
                context.push('/me/resumes');
                break;
              case 'applications':
                context.push('/me/applications');
                break;
              case 'logout':
                await WebAccountActionsService.confirmLogout(context);
                break;
            }
          },
        );
      },
    );
  }

  Widget _menuRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.notoSansKr(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
