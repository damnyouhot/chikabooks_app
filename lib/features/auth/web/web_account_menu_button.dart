import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../services/web_account_actions_service.dart';

/// 웹 이력서·공고 화면 우상단용 계정 메뉴(로그아웃·계정 삭제).
///
/// 모바일에서는 빈 위젯을 반환합니다.
class WebAccountMenuButton extends StatelessWidget {
  const WebAccountMenuButton({super.key});

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
            value: 'logout',
            child: Text(
              '로그아웃',
              style: GoogleFonts.notoSansKr(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
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
        if (value == 'logout') {
          await WebAccountActionsService.confirmLogout(context);
        } else if (value == 'delete') {
          await WebAccountActionsService.confirmDeleteAccount(context);
        }
      },
    );
  }
}
