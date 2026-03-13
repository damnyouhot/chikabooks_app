import 'package:flutter/material.dart';
import '../models/inbox_card.dart';
import '../services/partner_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_badge.dart';

/// 파트너 인박스 요약 카드
///
/// 읽지 않은 파트너 활동을 사람별로 묶어서 표시
class PartnerInboxCard extends StatelessWidget {
  const PartnerInboxCard({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<InboxCard>>(
      stream: PartnerService.streamInboxCards(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final cards = snap.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                '파트너 소식',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            ...cards.map((card) => _InboxCardItem(card: card)),
          ],
        );
      },
    );
  }
}

class _InboxCardItem extends StatelessWidget {
  final InboxCard card;

  const _InboxCardItem({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 날짜
          Text(
            card.date,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textDisabled,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),

          // 사람별 활동
          ...card.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    // 지역 · 경력
                    AppBadge(
                      label: item.locationLabel,
                      bgColor: AppColors.accent.withOpacity(0.10),
                      textColor: AppColors.accent,
                    ),
                    const SizedBox(width: 8),
                    // 활동 요약
                    Expanded(
                      child: Text(
                        item.lines.join(', '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              )),

          // 읽음 처리 버튼
          if (card.unread)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  await PartnerService.markInboxRead(card.id);
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
