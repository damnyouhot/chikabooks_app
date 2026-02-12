import 'package:flutter/material.dart';
import '../../services/bond_score_service.dart';

/// 결 점수 카드 (숫자 + 짧은 라벨만, 차트/막대 금지)
class BondScoreCard extends StatelessWidget {
  final double score;

  const BondScoreCard({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final label = BondScoreService.scoreLabel(score);
    final scoreStr = score.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD54F).withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome,
              color: Color(0xFFFFD54F), size: 20),
          const SizedBox(width: 10),
          const Text(
            '결',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF424242),
            ),
          ),
          const Spacer(),
          Text(
            scoreStr,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6A5ACD),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _labelColor(score).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _labelColor(score),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _labelColor(double score) {
    if (score >= 70) return const Color(0xFFFF8A80);
    if (score >= 60) return const Color(0xFF81D4FA);
    if (score >= 50) return const Color(0xFFA5D6A7);
    if (score >= 40) return const Color(0xFFFFAB91);
    return Colors.grey;
  }
}



