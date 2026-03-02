import 'package:flutter/material.dart';
import 'bond_colors.dart';

/// 2인 그룹 특별 메시지
/// - "이번 주는 두 사람의 페이지야. 가끔은 조용한 주도 좋지."
/// - 3인이 안 찼다고 부족하게 보이면 안 됨
class BondTwoPersonMessage extends StatelessWidget {
  const BondTwoPersonMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BondColors.kAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: BondColors.kAccent.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BondColors.kAccent.withOpacity(0.2),
            ),
            child: const Icon(
              Icons.people,
              size: 20,
              color: BondColors.kText,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '이번 주는 두 사람의 페이지야',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BondColors.kText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '가끔은 조용한 주도 좋지',
                  style: TextStyle(
                    fontSize: 13,
                    color: BondColors.kText.withOpacity(0.6),
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










