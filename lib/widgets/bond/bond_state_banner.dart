import 'package:flutter/material.dart';
import 'bond_colors.dart';

/// 상태 안내 배너 (단일 통합)
/// - no_group: 조용한 페이지
/// - pause: 쉬는 중
/// - expiring_soon: 곧 끝나
/// - two_person: 두 사람의 페이지
class BondStateBanner extends StatelessWidget {
  final String state; // 'no_group', 'pause', 'expiring_soon', 'two_person', 'active'
  final int memberCount;

  const BondStateBanner({
    super.key,
    required this.state,
    this.memberCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    // active 상태면 배너 숨김
    if (state == 'active' && memberCount != 2) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _getBorderColor(),
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
              color: _getIconBackgroundColor(),
            ),
            child: Icon(
              _getIcon(),
              size: 20,
              color: _getIconColor(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTitle(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BondColors.kText,
                    height: 1.4,
                  ),
                ),
                if (_getSubtitle().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _getSubtitle(),
                    style: TextStyle(
                      fontSize: 12,
                      color: BondColors.kText.withOpacity(0.6),
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (state) {
      case 'no_group':
        return const Color(0xFFF5F5F5);
      case 'pause':
        return const Color(0xFFFFF9E6);
      case 'expiring_soon':
        return const Color(0xFFFFF3E0);
      case 'two_person':
        return BondColors.kAccent.withOpacity(0.08);
      default:
        return Colors.white;
    }
  }

  Color _getBorderColor() {
    switch (state) {
      case 'no_group':
        return Colors.grey[300]!;
      case 'pause':
        return const Color(0xFFFFE082);
      case 'expiring_soon':
        return const Color(0xFFFFB74D);
      case 'two_person':
        return BondColors.kAccent.withOpacity(0.2);
      default:
        return Colors.grey[200]!;
    }
  }

  Color _getIconBackgroundColor() {
    switch (state) {
      case 'no_group':
        return const Color(0xFF1E88E5).withOpacity(0.1);
      case 'pause':
        return Colors.orange.withOpacity(0.1);
      case 'expiring_soon':
        return const Color(0xFFF57C00).withOpacity(0.1);
      case 'two_person':
        return BondColors.kAccent.withOpacity(0.2);
      default:
        return Colors.grey[200]!;
    }
  }

  Color _getIconColor() {
    switch (state) {
      case 'no_group':
        return const Color(0xFF1E88E5);
      case 'pause':
        return Colors.orange[700]!;
      case 'expiring_soon':
        return const Color(0xFFF57C00);
      case 'two_person':
        return BondColors.kText;
      default:
        return Colors.grey[600]!;
    }
  }

  IconData _getIcon() {
    switch (state) {
      case 'no_group':
        return Icons.auto_stories_outlined;
      case 'pause':
        return Icons.pause_circle_outline;
      case 'expiring_soon':
        return Icons.access_time;
      case 'two_person':
        return Icons.people;
      default:
        return Icons.info_outline;
    }
  }

  String _getTitle() {
    switch (state) {
      case 'no_group':
        return '이번 주는 조용한 페이지야';
      case 'pause':
        return '지금은 쉬는 중이야';
      case 'expiring_soon':
        return '이번 주가 곧 끝나';
      case 'two_person':
        return '이번 주는 두 사람의 페이지야';
      default:
        return '';
    }
  }

  String _getSubtitle() {
    switch (state) {
      case 'no_group':
        return '월요일 오전 9시, 새로운 동행이 자동으로 이어져';
      case 'pause':
        return '언제든 다시 시작할 수 있어';
      case 'expiring_soon':
        return '월요일 오전 9시에 새 파트너와 함께해';
      case 'two_person':
        return '가끔은 조용한 주도 좋지';
      default:
        return '';
    }
  }
}










