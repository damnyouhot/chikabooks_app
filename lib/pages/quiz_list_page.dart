import 'package:flutter/material.dart';

class QuizListPage extends StatelessWidget {
  const QuizListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 퀴즈')),
      body: const Center(
        child: Text(
          '퀴즈 기능은 곧 제공될 예정입니다. ✏️',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
