import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
            padding: const EdgeInsets.all(16),
            itemCount: 7,
            itemBuilder: (_, __) => const ShimmerListTile(),
          );
        }

        final list = snap.data!;
        if (list.isEmpty) {
          return const Center(child: Text('등록된 전자책이 없습니다.'));
        }

        return CustomScrollView(
          slivers: [
            // ── 1. 추천 섹션 (상단) ──
            SliverToBoxAdapter(
              child: _buildRecommendedSection(context, list),
            ),

            // ── 2. 전체 전자책 그리드 ──
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: 0.66,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final ebook = list[i];
                    return _buildEbookCard(context, ebook);
                  },
                  childCount: list.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 추천 섹션 (가로 스크롤)
  Widget _buildRecommendedSection(BuildContext context, List<Ebook> allEbooks) {
    // 추천 로직: 최신순 상위 3개 (또는 무료 전자책 우선)
    final recommended = allEbooks
        .where((e) => e.price == 0) // 무료 전자책 우선
        .take(3)
        .toList();

    // 무료가 3개 미만이면 전체에서 최신순으로 채우기
    if (recommended.length < 3) {
      final remaining = allEbooks
          .where((e) => !recommended.contains(e))
          .take(3 - recommended.length)
          .toList();
      recommended.addAll(remaining);
    }

    if (recommended.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Text(
                '🌟',
                style: TextStyle(fontSize: 20),
              ),
              SizedBox(width: 8),
              Text(
                '이번 주 추천',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recommended.length,
            itemBuilder: (context, i) {
              final book = recommended[i];
              return Container(
                width: 140,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EbookDetailPage(ebook: book),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 표지
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            book.coverUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.image_not_supported),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 제목
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // 저자
                      Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                      // 가격 (무료 강조)
                      if (book.price == 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E88E5).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '무료',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E88E5),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text(
            '전체 전자책',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// 전자책 카드 (그리드용)
  Widget _buildEbookCard(BuildContext context, Ebook ebook) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EbookDetailPage(ebook: ebook),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 표지
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                ebook.coverUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 제목
          Text(
            ebook.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          // 저자
          Text(
            ebook.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}




