import 'package:flutter/material.dart';

/// 📍 내 주변 신규 구인 카드
class JobsInfoCard extends StatelessWidget {
  final Map<String, dynamic>? data;
  final VoidCallback? onTap;

  const JobsInfoCard({super.key, this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    final count = data?['count'] ?? 0;
    final clinicName = data?['clinicName'] ?? '';
    final otherCount = count > 1 ? count - 1 : 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 타이틀
              Row(
                children: [
                  Text('📍', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 3),
                  Text(
                    '내 주변 신규 구인',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // 메인 텍스트
              Text(
                data == null
                    ? '로딩 중...'
                    : count == 0
                    ? '새로운 구인 공고가 없어요'
                    : '오늘 새로 올라온 $count건',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 2),
              // 서브 텍스트
              if (count > 0 && clinicName.isNotEmpty)
                Text(
                  otherCount > 0 ? '$clinicName 외 $otherCount건' : clinicName,
                  style: TextStyle(fontSize: 10, color: Colors.black54),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
