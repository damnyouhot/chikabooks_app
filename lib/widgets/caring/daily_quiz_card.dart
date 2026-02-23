import 'package:flutter/material.dart';
import '../../models/daily_quiz.dart';

/// 🧠 오늘의 1문제 카드
class DailyQuizCard extends StatelessWidget {
  final DailyQuiz? quiz;
  final VoidCallback? onStart;

  const DailyQuizCard({super.key, this.quiz, this.onStart});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 타이틀
            Row(
              children: [
                Text('🧠', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 3),
                Text(
                  '오늘의 1문제',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 질문
            Text(
              quiz == null
                  ? '로딩 중...'
                  : quiz!.question.isEmpty
                  ? '오늘의 퀴즈가 준비되지 않았어요'
                  : quiz!.question,
              style: TextStyle(fontSize: 11, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // CTA 버튼
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed:
                    quiz != null && quiz!.question.isNotEmpty ? onStart : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('바로 풀기', style: TextStyle(fontSize: 10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
