import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/share_position_origin.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_badge.dart';
import '../../models/poll.dart';
import '../../models/poll_option.dart';

const String _kShareBaseUrl = 'https://chikabooks3rd.web.app';

/// 공감 투표 카드를 이미지로 캡처해 SNS 공유
class PollShareCapture {
  PollShareCapture._();

  static const double _kCardWidth = 360;

  /// [isPastStyle] true면 지난 투표(날짜 뱃지·순위 행), false면 오늘의 투표 UI에 가깝게
  static Future<void> share(
    BuildContext context, {
    required Poll poll,
    required List<PollOption> options,
    required String badgeLabel,
    required bool isPastStyle,
    required int totalEmpathy,
  }) async {
    final shareOrigin = sharePositionOriginForShare(context);
    final shareUrl =
        '$_kShareBaseUrl/bond?pollId=${Uri.encodeComponent(poll.id)}';
    final shareText =
        isPastStyle
            ? '지난 공감 투표 결과를 확인해보세요.\n$shareUrl'
            : '오늘의 공감투표에 참여해보세요.\n$shareUrl';

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      throw StateError('Overlay 없음');
    }

    final key = GlobalKey();
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder:
          (ctx) => Positioned(
            left: -8000,
            top: 0,
            child: Material(
              color: AppColors.appBg,
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: _kCardWidth,
                  child: _PollShareCard(
                    poll: poll,
                    options: options,
                    badgeLabel: badgeLabel,
                    isPastStyle: isPastStyle,
                    totalEmpathy: totalEmpathy,
                  ),
                ),
              ),
            ),
          ),
    );

    overlay.insert(entry);

    try {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('캡처 영역을 찾을 수 없어요.');
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('이미지 변환에 실패했어요.');
      }

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/empathy_poll_${poll.id}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(path, mimeType: 'image/png')],
        text: shareText,
        sharePositionOrigin: shareOrigin,
      );
    } finally {
      entry.remove();
    }
  }
}

class _PollShareCard extends StatelessWidget {
  const _PollShareCard({
    required this.poll,
    required this.options,
    required this.badgeLabel,
    required this.isPastStyle,
    required this.totalEmpathy,
  });

  final Poll poll;
  final List<PollOption> options;
  final String badgeLabel;
  final bool isPastStyle;
  final int totalEmpathy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.how_to_vote_outlined,
                size: 18,
                color: AppColors.textDisabled,
              ),
              const SizedBox(width: 8),
              Text(
                isPastStyle ? '지난 공감 투표' : '오늘의 공감투표',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.lg,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppBadge(
                        label: badgeLabel,
                        bgColor:
                            isPastStyle
                                ? AppColors.cardPrimary
                                : AppColors.pollBadgeBg,
                        textColor:
                            isPastStyle
                                ? AppColors.onCardPrimary
                                : AppColors.pollBadgeText,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          poll.question,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: Column(
                    children: [
                      if (isPastStyle)
                        ...options.asMap().entries.map(
                          (e) => _pastOptionRow(
                            rank: e.key,
                            option: e.value,
                            totalEmpathy: totalEmpathy,
                          ),
                        )
                      else
                        ...options.map((o) => _todayOptionRow(option: o)),
                    ],
                  ),
                ),
                if (isPastStyle && totalEmpathy > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Center(
                      child: Text(
                        '$totalEmpathy명 참여',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ),
                  ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: AppSpacing.xl,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.favorite_outline,
                        size: 14,
                        color: AppColors.textDisabled,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isPastStyle ? '하이진랩' : '하이진랩에서 투표하기',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pastOptionRow({
    required int rank,
    required PollOption option,
    required int totalEmpathy,
  }) {
    final rankLabel = '${rank + 1}위';
    final pct =
        totalEmpathy > 0
            ? (option.empathyCount / totalEmpathy * 100).toStringAsFixed(1)
            : '0.0';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text(
              rankLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: rank < 3 ? FontWeight.w700 : FontWeight.w500,
                color:
                    rank == 0 ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              option.content,
              style: TextStyle(
                fontSize: 13,
                fontWeight: rank == 0 ? FontWeight.w600 : FontWeight.w400,
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$pct%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '(${option.empathyCount})',
            style: const TextStyle(fontSize: 11, color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }

  Widget _todayOptionRow({required PollOption option}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: AppColors.pollOptionBg.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _radioCircle(false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.content,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.pollOptionText,
                      height: 1.35,
                    ),
                  ),
                  if (!option.isSystem)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        option.displayAuthorLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _radioCircle(bool isSelected) {
    return Container(
      width: 18,
      height: 18,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            isSelected
                ? AppColors.pollOptionSelectedText.withValues(alpha: 0.15)
                : Colors.transparent,
        border: Border.all(
          color:
              isSelected
                  ? AppColors.pollOptionSelectedText.withValues(alpha: 0.6)
                  : AppColors.textDisabled.withValues(alpha: 0.5),
          width: isSelected ? 1.5 : 0.8,
        ),
      ),
      child:
          isSelected
              ? Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.pollOptionSelectedText,
                  ),
                ),
              )
              : null,
    );
  }
}
