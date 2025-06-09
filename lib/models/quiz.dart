import 'package:cloud_firestore/cloud_firestore.dart';

class Quiz {
  final String id;
  final String question;
  final List<String> options;
  final int answerIndex; // 정답 옵션의 인덱스 (0~3)

  Quiz({
    required this.id,
    required this.question,
    required this.options,
    required this.answerIndex,
  });

  factory Quiz.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Quiz(
      id: doc.id,
      question: data['question'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      answerIndex: data['answerIndex'] ?? 0,
    );
  }
}
