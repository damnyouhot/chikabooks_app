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
import '../../models/quiz_pool_item.dart';

const String _kShareBaseUrl = 'https://chikabooks3rd.web.app';

/// 오늘의 퀴즈 카드를 이미지로 캡처해 SNS 공유
class QuizShareCapture {
  QuizShareCapture._();

  static const double _kCardWidth = 360;

  static Future<void> share(
    BuildContext context, {
    required int qIndex,
    required String question,
    required List<String> options,
    required String questionType,
    required String quizId,
    required String dateKey,
  }) async {
    // 비동기 전에 앵커 계산 (async gap 이후 context 사용 방지)
    final shareOrigin = sharePositionOriginForShare(context);
    final shareUrl =
        '$_kShareBaseUrl/quiz?date=${Uri.encodeComponent(dateKey)}&quizId=${Uri.encodeComponent(quizId)}';

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
                  child: _QuizShareCard(
                    qIndex: qIndex,
                    question: question,
                    options: options,
                    questionType: questionType,
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
          '${dir.path}/quiz_share_${quizId}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(path, mimeType: 'image/png')],
        text: '오늘의 퀴즈를 풀어보세요.\n$shareUrl',
        sharePositionOrigin: shareOrigin,
      );
    } finally {
      entry.remove();
    }
  }
}

class _QuizShareCard extends StatelessWidget {
  const _QuizShareCard({
    required this.qIndex,
    required this.question,
    required this.options,
    required this.questionType,
  });

  final int qIndex;
  final String question;
  final List<String> options;
  final String questionType;

  @override
  Widget build(BuildContext context) {
    final typeLabel = QuizPoolItem.badgeLabelForType(questionType);
    final isNational = questionType == QuizPoolItem.kNationalExam;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.quiz_outlined,
                size: 18,
                color: AppColors.textDisabled,
              ),
              const SizedBox(width: 8),
              const Text(
                '오늘의 퀴즈',
                style: TextStyle(
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
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AppBadge(
                        label: 'Q$qIndex',
                        bgColor: AppColors.pollBadgeBg,
                        textColor: AppColors.pollBadgeText,
                      ),
                      const SizedBox(width: 8),
                      AppBadge(
                        label: typeLabel,
                        bgColor:
                            isNational
                                ? AppColors.accent.withValues(alpha: 0.14)
                                : AppColors.disabledBg,
                        textColor:
                            isNational
                                ? AppColors.accent
                                : AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    10,
                    AppSpacing.xl,
                    AppSpacing.md,
                  ),
                  child: Text(
                    question,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.45,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, AppSpacing.sm),
                  child: Column(
                    children: List.generate(
                      options.length,
                      (i) => _optionRow(i, options[i]),
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
                        Icons.menu_book_outlined,
                        size: 14,
                        color: AppColors.textDisabled,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '하이진랩에서 정답 확인하기',
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

  Widget _optionRow(int index, String option) {
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
            Container(
              width: 18,
              height: 18,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.textDisabled.withValues(alpha: 0.5),
                  width: 0.8,
                ),
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + index),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.pollOptionText,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
