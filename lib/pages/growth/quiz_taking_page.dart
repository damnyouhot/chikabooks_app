import 'package:flutter/material.dart';
import '../../models/quiz.dart';
import '../../services/growth_service.dart';

class QuizTakingPage extends StatefulWidget {
  final Quiz quiz;
  const QuizTakingPage({super.key, required this.quiz});

  @override
  State<QuizTakingPage> createState() => _QuizTakingPageState();
}

class _QuizTakingPageState extends State<QuizTakingPage> {
  int? _selectedOptionIndex;
  bool _submitted = false;

  void _submitAnswer() {
    setState(() {
      _submitted = true;
    });

    final isCorrect = _selectedOptionIndex == widget.quiz.answerIndex;

    if (isCorrect) {
      GrowthService.recordEvent(type: 'quiz', value: 1.0);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(isCorrect ? '정답입니다! 🎉' : '아쉬워요, 오답입니다.'),
        content: Text(isCorrect ? '경험치가 상승했습니다!' : '다음 기회에 다시 도전해보세요!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('퀴즈 풀기')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.quiz.question,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            ...List.generate(widget.quiz.options.length, (index) {
              final option = widget.quiz.options[index];
              final bool isSelected = _selectedOptionIndex == index;
              Color? tileColor;

              // ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼ withOpacity 경고 수정 ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
              if (_submitted) {
                if (index == widget.quiz.answerIndex) {
                  tileColor = Colors.green.shade100; // 정답
                } else if (isSelected) {
                  tileColor = Colors.red.shade100; // 선택한 오답
                }
              }
              // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲ withOpacity 경고 수정 ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲

              return Card(
                color: tileColor,
                child: RadioListTile<int>(
                  title: Text(option),
                  value: index,
                  groupValue: _selectedOptionIndex,
                  onChanged: _submitted
                      ? null
                      : (value) {
                          setState(() {
                            _selectedOptionIndex = value;
                          });
                        },
                ),
              );
            }),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_selectedOptionIndex == null || _submitted)
                    ? null
                    : _submitAnswer,
                child: const Text('제출하기', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
