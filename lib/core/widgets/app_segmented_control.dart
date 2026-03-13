import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// ══════════════════════════════════════════════════════════════
/// AppSegmentedControl — 세그먼트 탭 컨트롤
///
/// 사용 위치:
///   - 성장하기 탭 메인 탭바 (오늘 퀴즈 / 제도 변경 / 치과책방 / 내 서재)
///   - 내 서재 서브 탭바 (전자책 / 저장한 변경사항)
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
  });

  final TabController controller;
  final List<String> labels;

  /// 컨테이너 외부 margin. 기본값: symmetric(horizontal: 20, vertical: 8)
  final EdgeInsetsGeometry? margin;

  /// 컨테이너 radius. 기본값: AppRadius.md = 10
  final double? containerRadius;

  /// 인디케이터 radius. 기본값: AppRadius.sm = 8
  final double? indicatorRadius;

  @override
  Widget build(BuildContext context) {
    final cr = containerRadius ?? AppRadius.md;
    final ir = indicatorRadius ?? AppRadius.sm;

    return Container(
      margin: margin ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm,
          ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(cr),
      ),
      child: TabBar(
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
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        tabs: labels.map((label) => Tab(text: label)).toList(),
      ),
    );
  }
}

