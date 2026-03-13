import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme/app_colors.dart';

/// 로딩 상태용 shimmer 리스트 타일
///
/// baseColor/highlightColor: AppColors 기반으로 통일
class ShimmerListTile extends StatelessWidget {
  const ShimmerListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.disabledBg,
      highlightColor: AppColors.surfaceMuted,
      child: ListTile(
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        title: Container(
          height: 16,
          color: AppColors.white,
        ),
        subtitle: Container(
          height: 12,
          color: AppColors.white,
        ),
      ),
    );
  }
}
