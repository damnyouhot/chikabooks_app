import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_badge.dart';
import '../../models/ebook.dart';
import '../../services/ebook_service.dart';
import '../../widgets/shimmer_list_tile.dart';
import 'ebook_detail_page.dart';

class EbookListPage extends StatelessWidget {
  const EbookListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EbookService>();

    return StreamBuilder<List<Ebook>>(
      stream: service.watchEbooks(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('오류: ${snap.error}'));
        }
        if (snap.connectionState == ConnectionState.waiting || !snap.hasData) {
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 7,
            itemBuilder: (_, __) => const ShimmerListTile(),
          );
        }

        final list = snap.data!;
        if (list.isEmpty) {
          return Center(
            child: Text(
              '등록된 전자책이 없습니다.',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            // ── 1. 추천 섹션 (상단) ──
            SliverToBoxAdapter(
              child: _RecommendedSection(allEbooks: list),
            ),

            // ── 2. 전체 전자책 그리드 ──
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: 0.66,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _EbookGridCard(ebook: list[i]),
                  childCount: list.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── 추천 섹션 (가로 스크롤) ─────────────────────────────────

class _RecommendedSection extends StatelessWidget {
  final List<Ebook> allEbooks;
  const _RecommendedSection({required this.allEbooks});

  List<Ebook> get _recommended {
    // 무료 전자책 우선, 부족하면 전체에서 채우기
    final free = allEbooks.where((e) => e.price == 0).take(3).toList();
    if (free.length < 3) {
      final extra = allEbooks
          .where((e) => !free.contains(e))
          .take(3 - free.length)
          .toList();
      return [...free, ...extra];
    }
    return free;
    }

  @override
  Widget build(BuildContext context) {
    final books = _recommended;
    if (books.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (ctx, _) {
        final screenW = MediaQuery.of(ctx).size.width;
        // 카드 너비: 화면 34%, 최소 120·최대 160
        final cardW = (screenW * 0.34).clamp(120.0, 160.0);
        final sectionH = cardW * 1.57;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
            // 섹션 헤더
        const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.md,
              ),
          child: Row(
            children: [
                  Text('🌟', style: TextStyle(fontSize: 20)),
                  SizedBox(width: AppSpacing.sm),
              Text(
                '이번 주 추천',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
            // 가로 스크롤 카드 목록
        SizedBox(
              height: sectionH,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: books.length,
                itemBuilder: (context, i) =>
                    _RecommendedCard(book: books[i], width: cardW),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(height: 1, color: AppColors.divider),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xs,
              ),
              child: Text(
                '전체 전자책',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── 추천 카드 (가로 스크롤용) ──────────────────────────────

class _RecommendedCard extends StatelessWidget {
  final Ebook book;
  final double width;
  const _RecommendedCard({required this.book, required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
              builder: (_) =>
                  EbookDetailPage(ebook: book, hideActions: true),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 표지
                      Expanded(
                        child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                          child: Image.network(
                            book.coverUrl,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => Container(
                      color: AppColors.disabledBg,
                      child: const Icon(
                        Icons.image_not_supported,
                        color: AppColors.textDisabled,
                      ),
                            ),
                          ),
                        ),
                      ),
              const SizedBox(height: AppSpacing.sm),
                      // 제목
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // 저자
                      Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                          fontSize: 11,
                  color: AppColors.textSecondary,
                        ),
                      ),
              // 무료 뱃지
                      if (book.price == 0)
                        Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: AppBadge(
                    label: '무료',
                    bgColor: AppColors.accent.withOpacity(0.12),
                    textColor: AppColors.accent,
                  ),
                ),
            ],
            ),
          ),
        ),
    );
  }
  }

// ── 전체 그리드 카드 ──────────────────────────────────────

class _EbookGridCard extends StatelessWidget {
  final Ebook ebook;
  const _EbookGridCard({required this.ebook});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EbookDetailPage(ebook: ebook, hideActions: true),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 표지
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Image.network(
                ebook.coverUrl,
                fit: BoxFit.contain,
                width: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.disabledBg,
                  child: const Icon(
                    Icons.image_not_supported,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // 제목
          Text(
            ebook.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          // 저자
          Text(
            ebook.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
