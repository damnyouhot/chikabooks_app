import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/share_position_origin.dart';
import '../../../core/widgets/app_badge.dart';
import '../models/senior_question.dart';
import '../services/senior_question_service.dart';

const String _kShareBaseUrl = 'https://chikabooks3rd.web.app';

/// 속닥속닥 글을 한 장의 카드 이미지로 캡처해 SNS 공유.
class SeniorQuestionShareCapture {
  SeniorQuestionShareCapture._();

  static const double _kCardWidth = 360;

  static Future<void> share(
    BuildContext context, {
    required SeniorQuestion question,
  }) async {
    final shareOrigin = sharePositionOriginForShare(context);
    final shareUrl =
        '$_kShareBaseUrl/bond?questionId=${Uri.encodeComponent(question.id)}';

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      throw StateError('Overlay 없음');
    }
    final previewComments =
        await SeniorQuestionService.fetchSharePreviewComments(question.id);

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
                  child: _SeniorQuestionShareCard(
                    question: question,
                    previewComments: previewComments,
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
          '${dir.path}/senior_question_${question.id}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(path, mimeType: 'image/png')],
        text: '속닥속닥 이야기를 확인해보세요.\n$shareUrl',
        sharePositionOrigin: shareOrigin,
      );
    } finally {
      entry.remove();
    }
  }
}

class _SeniorQuestionShareCard extends StatelessWidget {
  const _SeniorQuestionShareCard({
    required this.question,
    required this.previewComments,
  });

  final SeniorQuestion question;
  final List<SeniorComment> previewComments;

  @override
  Widget build(BuildContext context) {
    final hasImages = question.imageUrls.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.forum_outlined,
                size: 18,
                color: AppColors.textDisabled,
              ),
              const SizedBox(width: 8),
              const Text(
                '속닥속닥',
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
                    AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      AppBadge(
                        label: question.category,
                        bgColor: AppColors.pollBadgeBg,
                        textColor: AppColors.pollBadgeText,
                      ),
                      const Spacer(),
                      Text(
                        _dateLabel(question.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.lg,
                  ),
                  child: Text(
                    question.body,
                    maxLines: previewComments.isEmpty ? 8 : 5,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.42,
                    ),
                  ),
                ),
                if (hasImages)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      0,
                      AppSpacing.xl,
                      AppSpacing.md,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.52),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.image_outlined,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '사진 ${question.imageUrls.length}장 포함',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.lg,
                  ),
                  child: Text(
                    '${question.displayName} · 좋아요 ${question.likeCount} · 힘내요 ${question.cheerCount} · 댓글 ${question.commentCount}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ),
                if (previewComments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      0,
                      AppSpacing.xl,
                      AppSpacing.md,
                    ),
                    child: Column(
                      children: previewComments
                          .map(
                            (comment) => _ShareCommentPreview(comment: comment),
                          )
                          .toList(growable: false),
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
                        Icons.chat_bubble_outline,
                        size: 14,
                        color: AppColors.textDisabled,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '하이진랩에서 이야기 나누기',
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

  String _dateLabel(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }
}

class _ShareCommentPreview extends StatelessWidget {
  final SeniorComment comment;

  const _ShareCommentPreview({required this.comment});

  @override
  Widget build(BuildContext context) {
    final body = _commentPreviewBody(comment);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 13,
            color: AppColors.textDisabled,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${comment.displayName} ',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: body),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _commentPreviewBody(SeniorComment comment) {
    final body = comment.body.trim();
    if (body.isNotEmpty) return body;
    if (comment.stickerIds.isNotEmpty) return '스티커를 남겼어요';
    if (comment.imageUrls.isNotEmpty) return '사진 댓글을 남겼어요';
    return '댓글을 남겼어요';
  }
}
