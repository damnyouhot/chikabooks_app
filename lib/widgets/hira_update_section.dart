import 'package:flutter/material.dart';
import '../models/hira_update.dart';
import '../services/hira_update_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_muted_card.dart';
import 'hira_update_card.dart';
import 'hira_update_compact_item.dart';
import 'hira_web_view_sheet.dart';

class HiraUpdateSection extends StatefulWidget {
  /// 수가 조회 등에서 탭 전환 후 같은 키워드로 심층 검색을 요청할 때 사용
  final ValueNotifier<String?>? policySearchRequest;

  const HiraUpdateSection({super.key, this.policySearchRequest});

  @override
  State<HiraUpdateSection> createState() => _HiraUpdateSectionState();
}

class _HiraUpdateSectionState extends State<HiraUpdateSection> {
  late Future<List<HiraUpdate>> _localFuture;
  final _searchCtrl = TextEditingController();
  String _query = '';

  bool _isDeepSearching = false;
  HiraSearchResponse? _deepResult;
  String? _deepError;
  int _deepPage = 1;

  /// `all` = 전 탭 병합, 그 외 = 심평원 tabGbn (01, 02, 99, …)
  String _deepTabId = 'all';

  @override
  void initState() {
    super.initState();
    _localFuture = HiraUpdateService.getAllUpdates();
    widget.policySearchRequest?.addListener(_onExternalPolicySearch);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final n = widget.policySearchRequest;
      if (n != null && n.value != null && n.value!.trim().length >= 2) {
        _onExternalPolicySearch();
      }
    });
  }

  @override
  void didUpdateWidget(covariant HiraUpdateSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.policySearchRequest != widget.policySearchRequest) {
      oldWidget.policySearchRequest?.removeListener(_onExternalPolicySearch);
      widget.policySearchRequest?.addListener(_onExternalPolicySearch);
    }
  }

  @override
  void dispose() {
    widget.policySearchRequest?.removeListener(_onExternalPolicySearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onExternalPolicySearch() {
    final notifier = widget.policySearchRequest;
    if (notifier == null || !mounted) return;
    final raw = notifier.value;
    if (raw == null) return;
    final kw = raw.trim();
    if (kw.length < 2) return;
    notifier.value = null;
    _searchCtrl.text = kw;
    setState(() => _query = kw);
    _doDeepSearch(page: 1, tab: 'all');
  }

  void _refresh() {
    setState(() {
      _localFuture = HiraUpdateService.getAllUpdates();
      _deepResult = null;
      _deepError = null;
      _deepTabId = 'all';
      _deepPage = 1;
    });
  }

  List<HiraUpdate> _applyFilter(List<HiraUpdate> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((u) {
      return u.title.toLowerCase().contains(q) ||
          u.body.toLowerCase().contains(q) ||
          u.keywords.any((k) => k.toLowerCase().contains(q));
    }).toList();
  }

  /// 현재 탭에 표시할 결과 목록 (로컬 캐시 or 서버 결과)
  List<HiraSearchResult> get _activeResults {
    final r = _deepResult;
    if (r == null) return [];
    if (_deepTabId == 'all') return r.results;
    if (r.tabResults.containsKey(_deepTabId)) {
      return r.tabResults[_deepTabId]!;
    }
    // slice(0,3)에 안 들어간 탭 등: 단일 탭 API는 results만 채우는 경우
    return r.results;
  }

  /// 현재 탭의 총건수
  int get _activeCount {
    final r = _deepResult;
    if (r == null) return 0;
    if (_deepTabId == 'all') return r.totalAllCount;
    return r.tabCounts[_deepTabId] ??
        r.tabs
            .firstWhere(
              (t) => t.id == _deepTabId,
              orElse: () => HiraSearchTabInfo(id: '', label: '', count: 0),
            )
            .count;
  }

  Future<void> _doDeepSearch({int page = 1, String? tab}) async {
    final keyword = _query.trim();
    if (keyword.length < 2) return;

    final nextTab = tab ?? _deepTabId;

    // 로컬 탭 전환: 기존 응답에 tabResults가 있으면 API 재호출 없이 즉시 전환
    if (nextTab != 'all' &&
        _deepResult != null &&
        _deepResult!.tabResults.containsKey(nextTab)) {
      setState(() {
        _deepTabId = nextTab;
      });
      return;
    }
    // 'all' 탭 전환: 이미 로드된 results가 있으면 재호출 없이 전환
    if (nextTab == 'all' && _deepResult != null && page == _deepPage) {
      setState(() {
        _deepTabId = 'all';
      });
      return;
    }

    setState(() {
      _isDeepSearching = true;
      _deepError = null;
      _deepPage = page;
      _deepTabId = nextTab;
    });

    try {
      final result = await HiraUpdateService.searchInsurance(
        keyword: keyword,
        page: page,
        tab: nextTab,
      );
      if (mounted) {
        setState(() {
          _deepResult = result;
          _isDeepSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _deepError = '검색 중 오류가 발생했습니다';
          _isDeepSearching = false;
        });
      }
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _deepResult = null;
      _deepError = null;
      _deepPage = 1;
      _deepTabId = 'all';
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HiraUpdate>>(
      future: _localFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _deepResult == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final all = snapshot.data ?? [];

        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchBar(),
                if (_deepResult != null ||
                    _isDeepSearching ||
                    _deepError != null)
                  _buildDeepSearchSection()
                else
                  _buildLocalSection(all),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) {
          final trimmed = v.trim();
          setState(() {
            _query = trimmed;
            if (trimmed.isEmpty) {
              _deepResult = null;
              _deepError = null;
              _deepTabId = 'all';
              _deepPage = 1;
            }
          });
        },
        onSubmitted: (_) {
          if (_query.length >= 2) {
            _doDeepSearch(page: 1, tab: 'all');
          }
        },
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: '코드·키워드 검색 (예: 구강, K08, 스케일링)',
          hintStyle: TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary.withValues(alpha: 0.35),
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 20,
            color: AppColors.textPrimary.withValues(alpha: 0.4),
          ),
          suffixIcon:
              _query.isNotEmpty
                  ? GestureDetector(
                    onTap: _clearSearch,
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.textPrimary.withValues(alpha: 0.4),
                    ),
                  )
                  : null,
          filled: true,
          fillColor: AppColors.surfaceMuted,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ── 로컬 Firestore 데이터 섹션 ──
  Widget _buildLocalSection(List<HiraUpdate> all) {
    if (all.isEmpty) return _buildEmptyState();
    final updates = _applyFilter(all);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: _query.isEmpty ? '수가·급여 변경 리스트 (건강보험심사평가원)' : '"$_query" 검색결과',
          subtitle:
              _query.isEmpty
                  ? '최근 ${all.length}건의 변경사항'
                  : '${updates.length}건 일치',
        ),
        if (_query.isNotEmpty && _query.length >= 2) _buildDeepSearchHint(),
        if (updates.isEmpty && _query.isNotEmpty)
          _buildNoResultState()
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              children:
                  updates
                      .take(3)
                      .map((u) => HiraUpdateCard(update: u))
                      .toList(),
            ),
          ),
          if (updates.length > 3) ...[
            const SizedBox(height: AppSpacing.lg),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Text(
                '이전 항목',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDisabled,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                children:
                    updates
                        .skip(3)
                        .map((u) => HiraUpdateCompactItem(update: u))
                        .toList(),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildDeepSearchHint() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: GestureDetector(
        onTap: () => _doDeepSearch(page: 1, tab: 'all'),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(Icons.travel_explore, size: 18, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '심평원 전체 DB에서 "$_query" 검색하기',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }

  // ── 심평원 전체 검색 결과 섹션 ──
  Widget _buildDeepSearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: '심평원 보험인정기준 검색',
          subtitle: _isDeepSearching ? '검색 중...' : '분류 칩을 눌러 해당 유형만 볼 수 있어요',
        ),

        if (_deepResult != null && !_isDeepSearching) _buildTabFilterChips(),
        if (_deepResult != null && !_isDeepSearching) _buildDeepPageLine(),

        if (_isDeepSearching)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_deepError != null)
          _buildErrorState()
        else if (_deepResult != null && _activeResults.isEmpty)
          _buildNoResultState()
        else if (_deepResult != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              children:
                  _activeResults
                      .map((r) => _DeepSearchResultItem(result: r))
                      .toList(),
            ),
          ),
          if (_activeResults.length < _activeCount) _buildPagination(),
        ],
      ],
    );
  }

  Widget _buildTabFilterChips() {
    final r = _deepResult!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          _DeepFilterChip(
            label: '전체 ${r.totalAllCount}건',
            selected: _deepTabId == 'all',
            emphasize: true,
            onTap: () => _doDeepSearch(page: 1, tab: 'all'),
          ),
          if (r.tabs.isNotEmpty)
            ...r.tabs
                .where((t) => t.count > 0)
                .map(
                  (t) => _DeepFilterChip(
                    label: '${t.label} ${t.count}건',
                    selected: _deepTabId == t.id,
                    onTap: () => _doDeepSearch(page: 1, tab: t.id),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildDeepPageLine() {
    final r = _deepResult!;
    final count = _activeCount;
    if (count <= 0) {
      return const SizedBox.shrink();
    }
    final pp = r.perPage.clamp(1, 50);
    final totalPages = ((count + pp - 1) / pp).ceil().clamp(1, 99999);
    final line =
        _deepTabId == 'all'
            ? '${r.page}/$totalPages 페이지 · 합산 ${r.totalAllCount}건'
            : '${r.page}/$totalPages 페이지 · 이 분류 $count건 (전체 ${r.totalAllCount}건)';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.xl,
        AppSpacing.xs,
      ),
      child: Text(
        line,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textDisabled,
        ),
      ),
    );
  }

  Widget _buildPagination() {
    final pp = _deepResult!.perPage.clamp(1, 50);
    final totalPages = ((_activeCount + pp - 1) / pp).ceil().clamp(1, 99999);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_deepPage > 1)
            _PaginationButton(
              label: '이전',
              onTap: () => _doDeepSearch(page: _deepPage - 1),
            ),
          const SizedBox(width: AppSpacing.md),
          Text(
            '$_deepPage / $totalPages',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          if (_deepPage < totalPages)
            _PaginationButton(
              label: '다음',
              onTap: () => _doDeepSearch(page: _deepPage + 1),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm - 2),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
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
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textDisabled,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      child: AppMutedCard(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          children: const [
            Icon(Icons.info_outline, size: 40, color: AppColors.textDisabled),
            SizedBox(height: AppSpacing.md),
            Text(
              '최신 변경사항이 없습니다',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              '새로운 수가·급여 변경사항이 발표되면\n자동으로 업데이트됩니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textDisabled,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultState() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      child: AppMutedCard(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          children: [
            const Icon(
              Icons.search_off,
              size: 40,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '"$_query"에 대한 결과가 없습니다',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              '다른 키워드로 검색해 보세요',
              style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      child: AppMutedCard(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              size: 40,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _deepError ?? '오류가 발생했습니다',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GestureDetector(
              onTap: () => _doDeepSearch(page: _deepPage),
              child: Text(
                '다시 시도',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeepFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool emphasize;
  final VoidCallback onTap;

  const _DeepFilterChip({
    required this.label,
    required this.selected,
    this.emphasize = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.segmentSelected : AppColors.surfaceMuted;
    final fg = selected ? AppColors.onSegmentSelected : AppColors.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border:
                emphasize && !selected
                    ? Border.all(
                      color: AppColors.accent.withValues(alpha: 0.35),
                    )
                    : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

// ── 심평원 전체검색 결과 아이템 ──
class _DeepSearchResultItem extends StatelessWidget {
  final HiraSearchResult result;
  const _DeepSearchResultItem({required this.result});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppMutedCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        onTap:
            () => HiraWebViewSheet.show(
              context,
              url: result.link,
              title: result.title,
              searchContext: result,
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Text(
                    result.category,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    result.reference,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              result.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(
                  result.date,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDisabled,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Icon(
                  Icons.visibility_outlined,
                  size: 12,
                  color: AppColors.textDisabled,
                ),
                const SizedBox(width: 3),
                Text(
                  '${result.views}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDisabled,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.open_in_new,
                  size: 14,
                  color: AppColors.textDisabled,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PaginationButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
