import 'package:flutter/material.dart';
import '../models/hira_update.dart';
import '../services/hira_update_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_muted_card.dart';

class FeeLookupSection extends StatefulWidget {
  /// 현재 검색어로 「제도 변경」 탭으로 이동 후 심층 검색
  final void Function(String keyword)? onOpenPolicySearch;

  const FeeLookupSection({super.key, this.onOpenPolicySearch});

  @override
  State<FeeLookupSection> createState() => _FeeLookupSectionState();
}

class _FeeLookupSectionState extends State<FeeLookupSection> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _isSearching = false;
  FeeSearchResponse? _result;
  String? _error;
  int _currentPage = 1;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _doSearch({int page = 1}) async {
    final keyword = _query.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _isSearching = true;
      _error = null;
      _currentPage = page;
    });

    try {
      final result = await HiraUpdateService.searchFeeSchedule(
        keyword: keyword,
        page: page,
      );
      if (mounted) {
        setState(() {
          _result = result;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '수가 조회 중 오류가 발생했습니다';
          _isSearching = false;
        });
      }
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _result = null;
      _error = null;
      _currentPage = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showGuide = !_isSearching && _error == null && _result == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSearchBar(),
        Expanded(
          child:
              showGuide
                  ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: _buildGuideState(),
                    ),
                  )
                  : _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                    child:
                        _error != null
                            ? _buildErrorState()
                            : _buildResultSection(context),
                  ),
        ),
      ],
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
        onChanged: (v) => setState(() => _query = v.trim()),
        onSubmitted: (_) {
          if (_query.isNotEmpty) _doSearch();
        },
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: '수가코드 또는 행위명 검색 (예: 다197가, 스케일링)',
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

  Widget _buildGuideState() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      child: AppMutedCard(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          children: [
            Icon(
              Icons.medical_information_outlined,
              size: 44,
              color: AppColors.accent.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              '수가 코드·행위명으로 검색하세요',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              '건강보험심사평가원 공공데이터를 기반으로\n진료행위별 수가(단가·상대가치점수)를 조회합니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                _QuickSearchChip(
                  label: '치석제거',
                  onTap: () => _quickSearch('치석제거'),
                ),
                _QuickSearchChip(
                  label: '복합레진',
                  onTap: () => _quickSearch('복합레진'),
                ),
                _QuickSearchChip(label: '발치', onTap: () => _quickSearch('발치')),
                _QuickSearchChip(
                  label: '근관치료',
                  onTap: () => _quickSearch('근관치료'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _quickSearch(String keyword) {
    _searchCtrl.text = keyword;
    setState(() => _query = keyword);
    _doSearch();
  }

  Widget _buildResultSection(BuildContext context) {
    if (_result!.items.isEmpty) {
      return _buildNoResultState();
    }

    final totalPages = (_result!.totalCount / _result!.perPage).ceil();
    final canPolicyJump =
        widget.onOpenPolicySearch != null && _query.trim().length >= 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.lg,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '전체 ${_result!.totalCount}건 ($_currentPage/$totalPages 페이지)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
              if (canPolicyJump)
                OutlinedButton(
                  onPressed: () => widget.onOpenPolicySearch!(_query.trim()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: BorderSide(
                      color: AppColors.accent.withValues(alpha: 0.45),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: Text(
                    "'$_query'로 제도 변경 조회하기",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            children:
                _result!.items
                    .map(
                      (item) => _FeeItemCard(
                        item: item,
                        onTap: () => _FeeDetailSheet.show(context, item),
                      ),
                    )
                    .toList(),
          ),
        ),
        if (totalPages > 1) _buildPagination(totalPages),
      ],
    );
  }

  Widget _buildPagination(int totalPages) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_currentPage > 1)
            _PaginationBtn(
              label: '이전',
              onTap: () => _doSearch(page: _currentPage - 1),
            ),
          const SizedBox(width: AppSpacing.md),
          Text(
            '$_currentPage / $totalPages',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          if (_currentPage < totalPages)
            _PaginationBtn(
              label: '다음',
              onTap: () => _doSearch(page: _currentPage + 1),
            ),
        ],
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
              '"$_query"에 대한 수가 정보가 없습니다',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              '코드 또는 행위명을 다시 확인해 보세요',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textDisabled,
              ),
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
              _error ?? '오류가 발생했습니다',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GestureDetector(
              onTap: () => _doSearch(page: _currentPage),
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

class _FeeItemCard extends StatelessWidget {
  final FeeScheduleItem item;
  final VoidCallback onTap;
  const _FeeItemCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AppMutedCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
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
                        item.code,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (item.payType.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color:
                              item.payType == '급여'
                                  ? const Color(
                                    0xFF2E7D32,
                                  ).withValues(alpha: 0.08)
                                  : const Color(
                                    0xFFE65100,
                                  ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(
                          item.payType,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color:
                                item.payType == '급여'
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFE65100),
                          ),
                        ),
                      ),
                    ],
                    if (item.category.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          item.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDisabled,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  item.codeName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '상대가치 ${item.relativeValue.toStringAsFixed(2)}점',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (item.startDate.isNotEmpty)
                            Text(
                              '적용 ${_formatFeeDate(item.startDate)}~',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDisabled,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          _PriceChip(label: '의원', price: item.priceClinic),
                          const SizedBox(width: AppSpacing.xs),
                          _PriceChip(label: '병원', price: item.priceHospital),
                          const SizedBox(width: AppSpacing.xs),
                          _PriceChip(label: '종합', price: item.priceGeneral),
                          const SizedBox(width: AppSpacing.xs),
                          _PriceChip(label: '상급', price: item.priceAdvanced),
                        ],
                      ),
                    ],
                  ),
                ),
                if (item.note.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.note,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatFeeDate(String raw) {
  if (raw.length == 8) {
    return '${raw.substring(0, 4)}.${raw.substring(4, 6)}.${raw.substring(6)}';
  }
  return raw;
}

String _formatPriceWon(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

class _FeeDetailSheet extends StatelessWidget {
  final FeeScheduleItem item;
  const _FeeDetailSheet({required this.item});

  static Future<void> show(BuildContext context, FeeScheduleItem item) {
    final h = MediaQuery.sizeOf(context).height;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.appBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder:
          (ctx) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(ctx).bottom),
            child: SizedBox(
              height: h * 0.78,
              child: _FeeDetailSheet(item: item),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '수가 상세',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            children: [
              Text(
                item.code,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                item.codeName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
              if (item.payType.isNotEmpty || item.category.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (item.payType.isNotEmpty)
                      _DetailChip(
                        label: item.payType,
                        isPay: item.payType == '급여',
                      ),
                    if (item.category.isNotEmpty)
                      Text(
                        item.category,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _DetailRow(
                label: '상대가치점수',
                value: '${item.relativeValue.toStringAsFixed(2)}점',
              ),
              if (item.startDate.isNotEmpty)
                _DetailRow(
                  label: '적용 시작',
                  value: '${_formatFeeDate(item.startDate)}~',
                ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                '기관별 단가 (원)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _DetailPriceTable(item: item),
              if (item.note.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  '비고',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  item.note,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  final bool isPay;
  const _DetailChip({required this.label, required this.isPay});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color:
            isPay
                ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                : const Color(0xFFE65100).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isPay ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textDisabled,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailPriceTable extends StatelessWidget {
  final FeeScheduleItem item;
  const _DetailPriceTable({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppMutedCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          _row('의원', item.priceClinic),
          const Divider(height: AppSpacing.lg),
          _row('병원', item.priceHospital),
          const Divider(height: AppSpacing.lg),
          _row('종합병원', item.priceGeneral),
          const Divider(height: AppSpacing.lg),
          _row('상급종합', item.priceAdvanced),
        ],
      ),
    );
  }

  Widget _row(String label, int price) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          price > 0 ? _formatPriceWon(price) : '-',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: price > 0 ? AppColors.textPrimary : AppColors.textDisabled,
          ),
        ),
      ],
    );
  }
}

class _PriceChip extends StatelessWidget {
  final String label;
  final int price;
  const _PriceChip({required this.label, required this.price});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.textDisabled,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            price > 0 ? _fmt(price) : '-',
            style: TextStyle(
              fontSize: price > 0 ? 12 : 11,
              fontWeight: FontWeight.w700,
              color: price > 0 ? AppColors.textPrimary : AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _QuickSearchChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickSearchChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.textDisabled.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PaginationBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PaginationBtn({required this.label, required this.onTap});

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
