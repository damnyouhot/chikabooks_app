import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hira_update.dart';
import 'hira_update_detail_sheet.dart';

// ── 디자인 팔레트 ──
const _kText = Color(0xFF5D6B6B);
const _kShadow2 = Color(0xFFD5E5E5);
const _kCardBg = Colors.white;
const _kHighRed = Color(0xFFE57373);
const _kMidOrange = Color(0xFFFFB74D);
const _kLowGray = Color(0xFFBDBDBD);

/// HIRA 업데이트 간단 리스트 아이템 (4번째 이후)
class HiraUpdateCompactItem extends StatelessWidget {
  final HiraUpdate update;

  const HiraUpdateCompactItem({
    super.key,
    required this.update,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _kShadow2.withOpacity(0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 배지
            _buildImpactBadge(),
            const SizedBox(width: 10),
            
            // 제목
            Expanded(
              child: Text(
                update.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: _kText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 10),
            
            // 날짜
            Text(
              _formatDate(update.publishedAt),
              style: TextStyle(
                fontSize: 11,
                color: _kText.withOpacity(0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            
            // 화살표
            Icon(
              Icons.chevron_right,
              size: 16,
              color: _kText.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  /// 배지
  Widget _buildImpactBadge() {
    Color badgeColor;
    String badgeText;

    switch (update.impactLevel) {
      case 'HIGH':
        badgeColor = _kHighRed;
        badgeText = '중요';
        break;
      case 'MID':
        badgeColor = _kMidOrange;
        badgeText = '보통';
        break;
      default:
        badgeColor = _kLowGray;
        badgeText = '참고만';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: badgeColor.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
      ),
    );
  }

  /// 날짜 포맷 (MM.DD)
  String _formatDate(DateTime date) {
    return DateFormat('MM.dd').format(date);
  }

  /// 상세 BottomSheet 열기
  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HiraUpdateDetailSheet(update: update),
    );
  }
}

