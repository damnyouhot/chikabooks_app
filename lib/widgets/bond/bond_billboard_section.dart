import 'package:flutter/material.dart';
import '../billboard_carousel.dart';
import 'bond_colors.dart';

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
              const Text(
                '✨ 전광판',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: BondColors.kText,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.mic_none,
                size: 16,
                color: BondColors.kText.withOpacity(0.4),
              ),
              const SizedBox(width: 4),
              Text(
                '우리가 같이 고른 이야기들',
                style: TextStyle(
                  fontSize: 11,
                  color: BondColors.kText.withOpacity(0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 자동 순환 전광판
          const BillboardCarousel(),
        ],
      ),
    );
  }
}



