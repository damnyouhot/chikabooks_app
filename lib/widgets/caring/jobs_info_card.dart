import 'package:flutter/material.dart';

/// 📍 내 주변 신규 구인 카드 (더미 데이터)
class JobsInfoCard extends StatelessWidget {
  final VoidCallback? onTap;

  const JobsInfoCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
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
              // 메인 텍스트 (가장 크게)
              Text(
                '오늘 새로 올라온 3건',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 2),
              // 서브 텍스트
              Text(
                '서울대치과 외 2건',
                style: TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
