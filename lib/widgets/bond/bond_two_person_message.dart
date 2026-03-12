import 'package:flutter/material.dart';
import '../../core/theme/tab_theme.dart';

const _b = TabTheme.bond;

/// 2인 그룹 특별 메시지
class BondTwoPersonMessage extends StatelessWidget {
  const BondTwoPersonMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _b.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _b.accent.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _b.accent.withOpacity(0.2),
            ),
            child: Icon(Icons.people, size: 20, color: _b.onBg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '이번 주는 두 사람의 페이지야',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _b.onBg,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '가끔은 조용한 주도 좋지',
                  style: TextStyle(
                    fontSize: 13,
                    color: _b.onBg.withOpacity(0.6),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
