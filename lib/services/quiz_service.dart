import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quiz.dart';

class QuizService {
  final _db = FirebaseFirestore.instance;

  // 모든 퀴즈 목록을 불러오는 함수
  Future<List<Quiz>> fetchQuizzes() async {
    final snapshot = await _db
        .collection('quizzes')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => Quiz.fromDoc(doc)).toList();
  }
}
