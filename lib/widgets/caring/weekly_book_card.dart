import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';

/// 📖 이주의 책 카드
class WeeklyBookCard extends StatelessWidget {
  final Map<String, dynamic>? data;
  final VoidCallback? onPreview;

  const WeeklyBookCard({super.key, this.data, this.onPreview});

  @override
  Widget build(BuildContext context) {
    final bookTitle    = data?['title']        as String? ?? '';
    final bookSubtitle = data?['subtitle']     as String? ?? '';
    final thumbnailUrl = data?['thumbnailUrl'] as String?;

    return AppMutedCard(
      radius: AppRadius.sm,
      padding: const EdgeInsets.all(AppSpacing.sm),
      onTap: onPreview,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타이틀
          const Row(
            children: [
              Text('📖', style: TextStyle(fontSize: 13)),
              SizedBox(width: 3),
              Text(
                '이주의 책',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 로딩 상태
          if (data == null)
            const Text(
              '로딩 중...',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            )
          // 데이터 없음
          else if (bookTitle.isEmpty)
            const Text(
              '이주의 책이 선정되지 않았어요',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            )
          // 책 정보
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 작은 표지 썸네일
                Container(
                  width: 34,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.disabledBg,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    image: thumbnailUrl != null
                        ? DecorationImage(
                            image: NetworkImage(thumbnailUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: thumbnailUrl == null
                      ? const Icon(
                          Icons.book,
                          size: 18,
                          color: AppColors.textDisabled,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                // 우측 텍스트
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bookTitle,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (bookSubtitle.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          '― $bookSubtitle',
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      OutlinedButton(
                        onPressed: onPreview,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          side: const BorderSide(color: AppColors.divider),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm + 2,
                            vertical: AppSpacing.xs - 1,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('1분 미리보기', style: TextStyle(fontSize: 9)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
