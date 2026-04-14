import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../services/web_account_actions_service.dart';

/// 웹 이력서·공고 화면 우상단용 계정 메뉴(약관·환불·로그아웃·계정 삭제).
///
/// 모바일에서는 빈 위젯을 반환합니다.
class WebAccountMenuButton extends StatelessWidget {
  const WebAccountMenuButton({super.key});

  static TextStyle _itemStyle(BuildContext ctx) => GoogleFonts.notoSansKr(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      tooltip: '계정',
      offset: const Offset(0, 40),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(
          Icons.account_circle_outlined,
          size: 26,
          color: AppColors.textSecondary,
        ),
      ),
      itemBuilder: (ctx) {
        return [
          PopupMenuItem<String>(
            value: 'terms',
            child: Text('이용약관', style: _itemStyle(ctx)),
          ),
          PopupMenuItem<String>(
            value: 'privacy',
            child: Text('개인정보처리방침', style: _itemStyle(ctx)),
          ),
          PopupMenuItem<String>(
            value: 'refund',
            child: Text('환불 및 청약철회 정책', style: _itemStyle(ctx)),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'logout',
            child: Text('로그아웃', style: _itemStyle(ctx)),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            child: Text(
              '계정 삭제',
              style: GoogleFonts.notoSansKr(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(ctx).colorScheme.error,
              ),
            ),
          ),
        ];
      },
      onSelected: (value) async {
        if (!context.mounted) return;
        switch (value) {
          case 'terms':
            context.push('/terms');
          case 'privacy':
            context.push('/privacy');
          case 'refund':
            context.push('/refund');
          case 'logout':
            await WebAccountActionsService.confirmLogout(context);
          case 'delete':
            await WebAccountActionsService.confirmDeleteAccount(context);
        }
      },
    );
  }
}
