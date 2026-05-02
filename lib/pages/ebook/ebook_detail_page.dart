// lib/pages/ebook/ebook_detail_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_modal_scaffold.dart';
import '../../models/ebook.dart';
import '../../services/ebook_service.dart';
import 'epub_reader_page.dart';
import 'pdf_reader_page.dart';

class EbookDetailPage extends StatefulWidget {
  final Ebook ebook;

  /// true이면 구매/읽기 버튼을 숨김 (성장하기 3번 탭 전용)
  final bool hideActions;

  const EbookDetailPage({
    super.key,
    required this.ebook,
    this.hideActions = false,
  });

  @override
  State<EbookDetailPage> createState() => _EbookDetailPageState();
}

class _EbookDetailPageState extends State<EbookDetailPage> {
  bool _isPurchased = false;
  bool _checkingPurchase = true;

  Ebook get ebook => widget.ebook;

  /// 파일 확장자로 PDF인지 확인
  bool get _isPdf => ebook.fileUrl.toLowerCase().contains('.pdf');

  @override
  void initState() {
    super.initState();
    _checkPurchaseStatus();
  }

  Future<void> _checkPurchaseStatus() async {
    // 무료 책은 항상 구매된 것으로 취급
    if (ebook.price == 0) {
      if (mounted) {
        setState(() {
          _isPurchased = true;
          _checkingPurchase = false;
        });
      }
      return;
    }

    try {
      final ebookService = context.read<EbookService>();
      final purchased = await ebookService.hasPurchased(ebook.id);
      if (mounted) {
        setState(() {
          _isPurchased = purchased;
          _checkingPurchase = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _checkingPurchase = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceText =
        ebook.price == 0
            ? '무료'
            : '${NumberFormat.decimalPattern().format(ebook.price)}원';

    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        title: Text(ebook.title),
        backgroundColor: AppColors.appBg,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 표지 이미지: 화면 너비의 45%, 최소160·최대240, 비율 2:3
            Center(
              child: LayoutBuilder(
                builder: (ctx, _) {
                  final screenW = MediaQuery.of(ctx).size.width;
                  final coverW = (screenW * 0.45).clamp(160.0, 240.0);
                  final coverH = coverW * 1.5;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    child: Image.network(
                      ebook.coverUrl,
                      width: coverW,
                      height: coverH,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) => Container(
                            width: coverW,
                            height: coverH,
                            color: AppColors.disabledBg,
                            child: const Icon(
                              Icons.book,
                              size: 64,
                              color: AppColors.textDisabled,
                            ),
                          ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // 제목
            Text(
              ebook.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),

            // 저자
            Text(
              '저자: ${ebook.author}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // 파일 형식 뱃지 (PDF / EPUB)
            AppBadge(
              label: _isPdf ? 'PDF' : 'EPUB',
              bgColor:
                  _isPdf
                      ? AppColors.error.withOpacity(0.1)
                      : AppColors.accent.withOpacity(0.1),
              textColor: _isPdf ? AppColors.error : AppColors.accent,
            ),
            const SizedBox(height: AppSpacing.lg),

            // 설명
            Text(
              ebook.description,
              style: const TextStyle(color: AppColors.textPrimary, height: 1.6),
            ),
            const SizedBox(height: AppSpacing.xxl + 8),

            // 구매/읽기 버튼 (hideActions가 true면 숨김 — 3번 탭)
            if (!widget.hideActions) ...[
              SizedBox(
                width: double.infinity,
                child:
                    _checkingPurchase
                        ? const Center(child: CircularProgressIndicator())
                        : FilledButton(
                          onPressed: () => _onButtonPressed(context),
                          child: Text(
                            _isPurchased
                                ? '이어서 읽기'
                                : ebook.price == 0
                                ? '바로 읽기'
                                : '$priceText • 구매 후 읽기',
                          ),
                        ),
              ),

              // 이미 구매한 경우 안내
              if (_isPurchased && ebook.price > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '✓ 이미 구매한 책입니다.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              // 무료가 아니고 미구매인 경우 안내 문구
              if (!_isPurchased && ebook.price > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '* 현재 테스트 모드: 결제 없이 바로 읽을 수 있습니다.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _onButtonPressed(BuildContext context) async {
    // 이미 구매했거나 무료면 바로 읽기
    if (_isPurchased) {
      _navigateToReader(context);
      return;
    }

    // 미구매 유료 책 → 구매 처리
    final ebookService = context.read<EbookService>();
    try {
      await ebookService.purchaseEbook(ebook.id);
      if (!mounted) return;
      if (!context.mounted) return;
      setState(() => _isPurchased = true);
      _showPurchaseCompleteDialog(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('구매 처리 중 오류가 발생했습니다: $e')));
      }
    }
  }

  /// 구매 완료 팝업
  void _showPurchaseCompleteDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder:
          (dialogCtx) => AppModalDialog(
            insetPadding: const EdgeInsets.all(AppSpacing.xl),
            cardPadding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (layoutCtx, _) {
                    final iconSize = (MediaQuery.sizeOf(layoutCtx).width * 0.18)
                        .clamp(64.0, 96.0);
                    return Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        size: iconSize * 0.625,
                        color: AppColors.success,
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                const Text(
                  '구매 완료! 🎉',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  ebook.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: AppColors.accent.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '구매한 책은 "내 서재"에서 언제든 다시 읽을 수 있어요!',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.accent.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(dialogCtx).pop();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.library_books, size: 18),
                        label: const Text('내 서재'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(dialogCtx).pop();
                          _navigateToReader(context);
                        },
                        icon: const Icon(Icons.auto_stories, size: 18),
                        label: const Text('이어서 읽기'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  /// 리더 페이지로 이동
  void _navigateToReader(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                _isPdf
                    ? PdfReaderPage(ebook: ebook)
                    : EpubReaderPage(ebook: ebook),
      ),
    );
  }
}
