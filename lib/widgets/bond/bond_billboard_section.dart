import 'package:flutter/material.dart';
import '../billboard_carousel.dart';
import '../../core/theme/tab_theme.dart';

const _b = TabTheme.bond;

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
                  color: _b.onBg,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.mic_none, size: 16, color: _b.onBg.withOpacity(0.4)),
              const SizedBox(width: 4),
              Text(
                '만장일치 추대된 이야기들',
                style: TextStyle(
                  fontSize: 11,
                  color: _b.onBg.withOpacity(0.5),
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
