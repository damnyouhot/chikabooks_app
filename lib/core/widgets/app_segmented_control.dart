import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_badge.dart';

/// ══════════════════════════════════════════════════════════════
/// AppSegmentedControl — 세그먼트 탭 컨트롤
///
/// 사용 위치:
///   - 성장하기 탭 메인 탭바 (오늘 퀴즈 / 오늘 단어 / 보험정보 / 내 서재 — 스토어 탭은 숨김)
///   - 내 서재 서브 탭바 (치과책방 / 저장한 변경사항)
///
/// 원칙:
///   - 컨테이너: AppColors.surfaceMuted (회색)
///   - 선택 인디케이터: AppColors.segmentSelected (Blue)
///   - 선택 텍스트: AppColors.onSegmentSelected (White)
///   - 미선택 텍스트: AppColors.onSegmentUnselected (textSecondary)
///   - boxShadow 없음 / Border 없음
/// ══════════════════════════════════════════════════════════════
class AppSegmentedControl extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.controller,
    required this.labels,
    this.margin,
    this.containerRadius,
    this.indicatorRadius,
    this.wipIndices = const {},
    this.newIndices = const {},
  });

  final TabController controller;
  final List<String> labels;

  /// 컨테이너 외부 margin. 기본값: symmetric(horizontal: 20, vertical: 8)
  final EdgeInsetsGeometry? margin;

  /// 컨테이너 radius. 기본값: AppRadius.md = 10
  final double? containerRadius;

  /// 인디케이터 radius. 기본값: AppRadius.sm = 8
  final double? indicatorRadius;

  /// '작업중' 뱃지를 표시할 탭 인덱스 집합
  final Set<int> wipIndices;

  /// 확인하지 않은 새 콘텐츠가 있는 탭 인덱스 집합
  final Set<int> newIndices;

  @override
  Widget build(BuildContext context) {
    final cr = containerRadius ?? AppRadius.md;
    final ir = indicatorRadius ?? AppRadius.sm;

    return Container(
      margin:
          margin ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm,
          ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(cr),
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final visibleNewIndices = newIndices.difference({controller.index});
          return TabBar(
            controller: controller,
            indicator: BoxDecoration(
              color: AppColors.segmentSelected,
              borderRadius: BorderRadius.circular(ir),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.all(3),
            dividerColor: Colors.transparent,
            labelColor: AppColors.onSegmentSelected,
            unselectedLabelColor: AppColors.onSegmentUnselected,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
            tabs:
                labels.asMap().entries.map((entry) {
                  final i = entry.key;
                  final label = entry.value;
                  final showNew = visibleNewIndices.contains(i);
                  if (!wipIndices.contains(i) && !showNew) {
                    return Tab(
                      height: 46,
                      child: _SegmentLabel(label: label, showNew: false),
                    );
                  }
                  return Tab(
                    height: 46,
                    child: _SegmentLabel(
                      label: label,
                      showNew: showNew,
                      trailing:
                          wipIndices.contains(i)
                              ? const PrepInProgressBadge()
                              : null,
                    ),
                  );
                }).toList(),
          );
        },
      ),
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel({
    required this.label,
    required this.showNew,
    this.trailing,
  });

  final String label;
  final bool showNew;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label),
              if (trailing != null) ...[const SizedBox(width: 4), trailing!],
            ],
          ),
          if (showNew)
            const Positioned(top: -6, right: 4, child: _NewContentBadge()),
        ],
      ),
    );
  }
}

class _NewContentBadge extends StatefulWidget {
  const _NewContentBadge();

  @override
  State<_NewContentBadge> createState() => _NewContentBadgeState();
}

class _NewContentBadgeState extends State<_NewContentBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.45,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD84D),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          'NEW',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: AppColors.blue,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
