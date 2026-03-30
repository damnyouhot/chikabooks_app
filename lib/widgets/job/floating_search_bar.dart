import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// 지도 하단 고정 검색바 — [JobListingsScreen] 하단바와 동일한 스케일·필터 칩
///
/// - 키보드가 올라오면 viewInsets.bottom을 읽어 자연스럽게 위로 밀림
/// - 포커스 시 "취소" 버튼 표시
class FloatingSearchBar extends StatefulWidget {
  final String searchQuery;
  final Function(String) onSearchChanged;
  final VoidCallback onFilterPressed;
  final String filterSummary;
  final int activeFilterCount;

  /// null이면 목록 버튼 숨김
  final VoidCallback? onListToggle;

  const FloatingSearchBar({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onFilterPressed,
    required this.filterSummary,
    this.activeFilterCount = 0,
    this.onListToggle,
  });

  @override
  State<FloatingSearchBar> createState() => _FloatingSearchBarState();
}

class _FloatingSearchBarState extends State<FloatingSearchBar> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final bottom = keyboardH > 0
        ? keyboardH + AppSpacing.sm
        : AppSpacing.md + safeBottom;

    return Positioned(
      left: AppSpacing.md,
      right: AppSpacing.md,
      bottom: bottom,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.search,
                color: AppColors.textDisabled,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  focusNode: _focusNode,
                  onChanged: widget.onSearchChanged,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: '치과명, 동네로 검색',
                    hintStyle: TextStyle(
                      fontSize: 15,
                      color: AppColors.textDisabled,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (_focused)
                GestureDetector(
                  onTap: () {
                    _focusNode.unfocus();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '취소',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              else ...[
                _FloatingFilterChip(
                  count: widget.activeFilterCount,
                  onTap: widget.onFilterPressed,
                ),
                if (widget.onListToggle != null) ...[
                  const SizedBox(width: 8),
                  _FloatingListToggleChip(onTap: widget.onListToggle!),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── 필터 칩 (목록 탭과 동일) ───────────────────────────────────────
class _FloatingFilterChip extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _FloatingFilterChip({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: AppColors.onAccent,
                ),
                SizedBox(width: 4),
                Text(
                  '필터',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onAccent,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (count > 0)
          Positioned(
            right: -2,
            top: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.appBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accent, width: 1.2),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// ── 목록 전환 칩 (지도 탭 — 목록과 동일 스케일) ─────────────────────
class _FloatingListToggleChip extends StatelessWidget {
  final VoidCallback onTap;

  const _FloatingListToggleChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.list_alt_rounded,
              size: 18,
              color: AppColors.onAccent,
            ),
            SizedBox(width: 4),
            Text(
              '목록',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.onAccent,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
