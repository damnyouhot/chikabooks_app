import 'package:flutter/material.dart';
import '../../models/quiz.dart';
import '../../services/quiz_service.dart';
import 'quiz_taking_page.dart'; // 퀴즈 풀기 페이지 import

class QuizListPage extends StatefulWidget {
  const QuizListPage({super.key});

  @override
  State<QuizListPage> createState() => _QuizListPageState();
}

class _QuizListPageState extends State<QuizListPage> {
  late Future<List<Quiz>> _quizzesFuture;

  @override
  void initState() {
    super.initState();
    _quizzesFuture = QuizService().fetchQuizzes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 퀴즈')),
      body: FutureBuilder<List<Quiz>>(
        future: _quizzesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            return const Center(child: Text('출제된 퀴즈가 없습니다.'));
          }

          final quizzes = snapshot.data!;
          return ListView.builder(
            itemCount: quizzes.length,
            itemBuilder: (context, index) {
              final quiz = quizzes[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(quiz.question,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // 퀴즈를 선택하면 퀴즈 풀기 페이지로 이동
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => QuizTakingPage(quiz: quiz)),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
