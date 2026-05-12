import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_modal_scaffold.dart';
import '../../../../services/clinic_inbox_service.dart';

/// 인박스 종 버튼 + 미읽음 배지 + 클릭 시 인박스 모달 오픈.
///
/// 광고 캠페인 알림 (만료 임박 / 자동연장 결과 / 환불 등) 을 한 곳에 모아 보여준다.
/// 적재는 서버 스케줄러(M5)가 담당, 클라이언트는 'read' 토글만 가능.
class CampaignInboxButton extends StatelessWidget {
  const CampaignInboxButton({super.key, this.iconColor});

  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: ClinicInboxService.watchUnreadCount(),
      initialData: 0,
      builder: (context, snap) {
        final unread = snap.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            IconButton(
              tooltip: '광고 알림',
              onPressed: () => _open(context),
              icon: Icon(
                Icons.notifications_none,
                color: iconColor ?? AppColors.textPrimary,
              ),
            ),
            if (unread > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardEmphasis,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onCardEmphasis,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  static Future<void> _open(BuildContext context) {
    return showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scroll) => _CampaignInboxPanel(scrollController: scroll),
      ),
    );
  }
}

class _CampaignInboxPanel extends StatelessWidget {
  const _CampaignInboxPanel({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.appBg,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Text(
                  '광고 알림',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => ClinicInboxService.markAllRead(),
                  child: Text(
                    '모두 읽음',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<ClinicInboxNotice>>(
              stream: ClinicInboxService.watchRecent(limit: 50),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snap.data ?? const <ClinicInboxNotice>[];
                if (items.isEmpty) {
                  return _Empty();
                }
                return ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.lg,
                  ),
                  itemBuilder: (_, i) => _InboxItem(notice: items[i]),
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemCount: items.length,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxItem extends StatelessWidget {
  const _InboxItem({required this.notice});
  final ClinicInboxNotice notice;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('M/d HH:mm');
    final color = _severityColor(notice.severity);
    return Material(
      color: notice.read ? AppColors.white : color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(AppPublisher.inputPanelRadius),
      child: InkWell(
        onTap: () {
          if (!notice.read) {
            ClinicInboxService.markRead(notice.id);
          }
        },
        borderRadius: BorderRadius.circular(AppPublisher.inputPanelRadius),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius:
                BorderRadius.circular(AppPublisher.inputPanelRadius),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: notice.read ? AppColors.disabledBg : color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notice.title,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notice.body,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.55,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      fmt.format(notice.createdAt.toLocal()),
                      style: GoogleFonts.notoSansKr(
                        fontSize: 10,
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'success':
        return AppColors.success;
      case 'warning':
        return AppColors.warning;
      case 'error':
        return AppColors.destructive;
      case 'info':
      default:
        return AppColors.cardPrimary;
    }
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                size: 40, color: AppColors.textDisabled),
            const SizedBox(height: 8),
            Text(
              '받은 알림이 없습니다.',
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
