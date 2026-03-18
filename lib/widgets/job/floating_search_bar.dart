import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// 지도 하단 고정 검색바
///
/// - 화면 하단에 고정
/// - 키보드가 올라오면 viewInsets.bottom을 읽어 자연스럽게 위로 밀림
/// - 포커스 시 "취소" 버튼 표시
/// - 원칙: Shadow 약하게 / 크기 약 70% 축소
class FloatingSearchBar extends StatefulWidget {
  final String searchQuery;
  final Function(String) onSearchChanged;
  final VoidCallback onFilterPressed;
  final String filterSummary;

  /// null이면 목록 버튼 숨김
  final VoidCallback? onListToggle;

  const FloatingSearchBar({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onFilterPressed,
    required this.filterSummary,
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
    // 키보드 높이 → 키보드가 올라오면 검색바도 자동으로 올라감
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;

    return Positioned(
      left: AppSpacing.md,
      right: AppSpacing.md,
      bottom: keyboardH > 0
          ? keyboardH + AppSpacing.sm // 키보드 바로 위
          : AppSpacing.md, // 기본: 화면 하단
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 8,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search,
                color: AppColors.textDisabled,
                size: 17,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  focusNode: _focusNode,
                  onChanged: widget.onSearchChanged,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: '치과명, 동네로 검색',
                    hintStyle: TextStyle(
                      fontSize: 13,
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
                  onTap: () => _focusNode.unfocus(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '취소',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              else
                InkWell(
                  onTap: widget.onFilterPressed,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.tune,
                      color: AppColors.textSecondary,
                      size: 15,
                    ),
                  ),
                ),
              if (!_focused && widget.onListToggle != null) ...[
                const SizedBox(width: 6),
                _ListToggleChip(onTap: widget.onListToggle!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── 목록 전환 칩 ──────────────────────────────────────────────────
class _ListToggleChip extends StatelessWidget {
  final VoidCallback onTap;
  const _ListToggleChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.list_alt_rounded,
              size: 13,
              color: AppColors.onAccent,
            ),
            SizedBox(width: 3),
            Text(
              '목록',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
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
