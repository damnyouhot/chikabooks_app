import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/ebook.dart';
import '../../services/ebook_service.dart';
import '../../widgets/shimmer_list_tile.dart';
import 'ebook_detail_page.dart';

// ── 정렬 기준 ──────────────────────────────────────────────
enum EbookSort {
  newest('최신 순'),
  oldest('오래된 순'),
  titleAsc('제목 순'),
  purchaseDesc('구매 많은 순');

  const EbookSort(this.label);
  final String label;
}

// ── 카테고리 목록 (스토리지 폴더명) ─────────────────────────
const _kCategories = [
  '전체',
  '임상스킬',
  '자기계발',
  'CS업무',
  '데스크업무',
  '보험청구',
  '워홀, 유학',
  '기타',
];

// 고정 바 높이 — 두 줄(카테고리 드롭다운 + 정렬 칩 행) + 구분선 + 타이틀
const double _kBarHeight = 128.0;

class EbookListPage extends StatefulWidget {
  const EbookListPage({super.key});

  @override
  State<EbookListPage> createState() => _EbookListPageState();
}

class _EbookListPageState extends State<EbookListPage> {
  String _selectedCategory = '전체';
  EbookSort _selectedSort = EbookSort.newest;

  List<Ebook>? _allEbooks;
  QueryDocumentSnapshot<Map<String, dynamic>>? _pageCursor;
  bool _hasMoreCatalog = false;

  bool _loading = true;
  String? _error;
  bool _initialized = false;

  /// [RefreshIndicator] 등으로 목록을 다시 불러올 때 이전 페이지 순차 로드와 충돌하지 않게 함
  int _catalogLoadGen = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadEbooks();
    }
  }

  Future<void> _loadEbooks() async {
    final gen = ++_catalogLoadGen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = context.read<EbookService>();
      final first = await service.fetchEbooksPage();
      if (!mounted || gen != _catalogLoadGen) return;
      setState(() {
        _allEbooks = first.books;
        _pageCursor = first.lastDocument;
        _hasMoreCatalog = first.hasMore;
        _loading = false;
      });
      await _loadRemainingCatalogPages(gen);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  /// 첫 페이지 이후 나머지 전자책을 순차 로드 (정렬·필터가 전체 목록을 쓰도록)
  Future<void> _loadRemainingCatalogPages(int gen) async {
    final service = context.read<EbookService>();
    while (mounted && gen == _catalogLoadGen && _hasMoreCatalog && _pageCursor != null) {
      final next = await service.fetchEbooksPage(startAfter: _pageCursor);
      if (!mounted || gen != _catalogLoadGen) return;
      setState(() {
        _allEbooks = [..._allEbooks!, ...next.books];
        _pageCursor = next.lastDocument;
        _hasMoreCatalog = next.hasMore;
      });
    }
  }

  List<Ebook> _applyFilters(List<Ebook> all) {
    var filtered = _selectedCategory == '전체'
        ? List<Ebook>.from(all)
        : all.where((e) => e.category == _selectedCategory).toList();

    switch (_selectedSort) {
      case EbookSort.newest:
        filtered.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      case EbookSort.oldest:
        filtered.sort((a, b) => a.publishedAt.compareTo(b.publishedAt));
      case EbookSort.titleAsc:
        filtered.sort((a, b) => a.title.compareTo(b.title));
      case EbookSort.purchaseDesc:
        filtered.sort((a, b) => b.price.compareTo(a.price));
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text('오류: $_error'));
    }
    if (_loading || _allEbooks == null) {
      return ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 7,
        itemBuilder: (_, __) => const ShimmerListTile(),
      );
    }

    final all = _allEbooks!;
    final filtered = _applyFilters(all);

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _allEbooks = null;
          _pageCursor = null;
          _hasMoreCatalog = false;
        });
        await _loadEbooks();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── 필터·정렬 바 (스크롤해도 상단 고정) ──
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterBarDelegate(
              allEbooks: all,
              selectedCategory: _selectedCategory,
              selectedSort: _selectedSort,
              onCategoryChanged: (c) =>
                  setState(() => _selectedCategory = c),
              onSortChanged: (s) => setState(() => _selectedSort = s),
            ),
          ),

          // ── 전자책 그리드 ──
          filtered.isEmpty
              ? const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      '해당 카테고리에 등록된 전자책이 없습니다.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: 0.66,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _EbookGridCard(ebook: filtered[i]),
                      childCount: filtered.length,
                    ),
                  ),
                ),
          if (filtered.isNotEmpty && _hasMoreCatalog)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.cardPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 고정 필터·정렬 바 Delegate ───────────────────────────────

class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  final List<Ebook> allEbooks;
  final String selectedCategory;
  final EbookSort selectedSort;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<EbookSort> onSortChanged;

  _FilterBarDelegate({
    required this.allEbooks,
    required this.selectedCategory,
    required this.selectedSort,
    required this.onCategoryChanged,
    required this.onSortChanged,
  });

  /// 스크롤 시 높이가 줄면 `SizedBox`가 부모보다 커져 BOTTOM OVERFLOW가 난다.
  /// min/max 동일 + [build]에서 현재 extent 사용으로 맞춘다.
  @override
  double get minExtent => _kBarHeight;
  @override
  double get maxExtent => _kBarHeight;

  @override
  bool shouldRebuild(_FilterBarDelegate old) =>
      old.selectedCategory != selectedCategory ||
      old.selectedSort != selectedSort ||
      old.allEbooks.length != allEbooks.length;

  List<String> _visibleCategories() {
    final found = allEbooks.map((e) => e.category).toSet();
    return _kCategories
        .where((c) => c == '전체' || found.contains(c))
        .toList();
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final visibleCats = _visibleCategories();
    final extent =
        (maxExtent - shrinkOffset).clamp(minExtent, maxExtent).toDouble();

    return Material(
      color: AppColors.appBg,
      elevation: overlapsContent ? 2 : 0,
      child: SizedBox(
        height: extent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // ── 줄 1: 책 분류 드롭다운 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: _CategoryDropdown(
              categories: visibleCats,
              selected: selectedCategory,
              onChanged: onCategoryChanged,
            ),
          ),

          const SizedBox(height: 6),

          // ── 줄 2: 정렬 칩들 (가로 스크롤) ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: EbookSort.values.map((sort) {
                final isSelected = sort == selectedSort;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _SortChip(
                    label: sort.label,
                    isSelected: isSelected,
                    onTap: () => onSortChanged(sort),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, color: AppColors.divider),

          // ── 섹션 타이틀 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                const Text(
                  '전체 전자책',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (selectedCategory != '전체') ...[
                  const SizedBox(width: 6),
                  Text(
                    '· $selectedCategory',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        ),  // Column
      ),    // SizedBox
    );
  }
}

// ── 카테고리 드롭다운 (바텀시트) ─────────────────────────────

class _CategoryDropdown extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onChanged;

  const _CategoryDropdown({
    required this.categories,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isFiltered = selected != '전체';

    return GestureDetector(
      onTap: () => _showPicker(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isFiltered ? AppColors.cardPrimary : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '책 분류',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isFiltered
                    ? AppColors.creamWhite
                    : AppColors.textSecondary,
              ),
            ),
            if (isFiltered) ...[
              const SizedBox(width: 4),
              Text(
                '· $selected',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.creamWhite,
                ),
              ),
            ],
            const SizedBox(width: 2),
            Icon(
              Icons.expand_more_rounded,
              size: 15,
              color: isFiltered
                  ? AppColors.creamWhite
                  : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textDisabled,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '책 분류',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            ...categories.map(
              (cat) => ListTile(
                dense: true,
                title: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        cat == selected ? FontWeight.w700 : FontWeight.w400,
                    color: cat == selected
                        ? AppColors.cardPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                trailing: cat == selected
                    ? const Icon(
                        Icons.check_rounded,
                        color: AppColors.cardPrimary,
                        size: 18,
                      )
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  onChanged(cat);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── 정렬 칩 ──────────────────────────────────────────────────

class _SortChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cardEmphasis : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: isSelected
              ? null
              : Border.all(
                  color: AppColors.textDisabled.withValues(alpha: 0.45),
                ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            color: isSelected
                ? AppColors.creamWhite
                : AppColors.textSecondary,
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
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Image.network(
                ebook.coverUrl,
                fit: BoxFit.cover,
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
          Text(
            ebook.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
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
