import 'package:flutter/material.dart';
import '../billboard_carousel.dart';
import '../../core/theme/app_colors.dart';

// AppColors 직접 참조 (TabTheme 제거)

/// 전광판 섹션 (추대된 게시물)
class BondBillboardSection extends StatelessWidget {
  const BondBillboardSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '✨ 전국구 게시판',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.mic_none, size: 16, color: AppColors.textDisabled),
              const SizedBox(width: 4),
              Text(
                '만장일치 추대된 이야기들',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const BillboardCarousel(),
        ],
      ),
    );
  }
}



