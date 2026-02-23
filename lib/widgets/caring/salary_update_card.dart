import 'package:flutter/material.dart';
import 'dart:async';

/// 🏥 급여 변경 임박 카드 (3초 간격 자동 로테이션)
class SalaryUpdateCard extends StatefulWidget {
  const SalaryUpdateCard({super.key});

  @override
  State<SalaryUpdateCard> createState() => _SalaryUpdateCardState();
}

class _SalaryUpdateCardState extends State<SalaryUpdateCard> {
  int _currentIndex = 0;
  Timer? _timer;

  // 더미 데이터
  final List<Map<String, String>> _updates = [
    {
      'title': '2026 스케일링 급여 개정',
      'date': '3월 1일',
      'dday': 'D-12',
    },
    {
      'title': '치주질환 급여 인정 기준 변경',
      'date': '3월 10일',
      'dday': 'D-21',
    },
    {
      'title': '근관치료 행위 산정 지침 개정',
      'date': '3월 15일',
      'dday': 'D-26',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAutoRotation();
  }

  void _startAutoRotation() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _updates.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final update = _updates[_currentIndex];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 타이틀
            Row(
              children: [
                Text(
                  '🏥',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 4),
                Text(
                  '급여 변경 임박',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 애니메이션 페이드
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Column(
                key: ValueKey(_currentIndex),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목 (24자 이내)
                  Text(
                    update['title']!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // 시행일 + D-day
                  Text(
                    '시행일: ${update['date']} (${update['dday']})',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
