// lib/pages/growth/growth_tab.dart
import 'package:flutter/material.dart';
import 'character_widget.dart';
import 'emotion_record_page.dart';

class GrowthTab extends StatelessWidget {
  const GrowthTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. 위에서 만든 캐릭터 위젯 표시
          const CharacterWidget(),
          const SizedBox(height: 48),

          // 2. '감정 기록하기' 버튼
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: const TextStyle(fontSize: 16),
            ),
            onPressed: () {
              // 버튼을 누르면 EmotionRecordPage로 이동
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EmotionRecordPage()),
              );
            },
            icon: const Icon(Icons.edit_note),
            label: const Text('오늘의 감정 기록하기'),
          )
        ],
      ),
    );
  }
}
