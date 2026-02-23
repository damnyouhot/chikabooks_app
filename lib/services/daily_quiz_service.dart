import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/daily_quiz.dart';

/// 일일 퀴즈 관리 서비스
class DailyQuizService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'dailyQuizzes';

  /// 오늘의 퀴즈 가져오기 (카드용)
  static Future<DailyQuiz?> getTodayQuiz() async {
    try {
      final dateKey = DailyQuiz.getTodayKey();
      final doc = await _firestore.collection(_collection).doc(dateKey).get();

      if (!doc.exists) {
        print('⚠️ 오늘의 퀴즈가 없습니다: $dateKey');
        return null;
      }

      return DailyQuiz.fromFirestore(doc);
    } catch (e) {
      print('⚠️ DailyQuizService.getTodayQuiz 에러: $e');
      return null;
    }
  }

  /// 특정 날짜의 퀴즈 가져오기
  static Future<DailyQuiz?> getQuizByDate(DateTime date) async {
    try {
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final doc = await _firestore.collection(_collection).doc(dateKey).get();

      if (!doc.exists) {
        return null;
      }

      return DailyQuiz.fromFirestore(doc);
    } catch (e) {
      print('⚠️ DailyQuizService.getQuizByDate 에러: $e');
      return null;
    }
  }

  /// 최근 N일의 퀴즈 가져오기
  static Future<List<DailyQuiz>> getRecentQuizzes({int days = 7}) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));

      final snapshot =
          await _firestore
              .collection(_collection)
              .where(
                FieldPath.documentId,
                isGreaterThanOrEqualTo: _formatDate(startDate),
              )
              .where(
                FieldPath.documentId,
                isLessThanOrEqualTo: _formatDate(endDate),
              )
              .orderBy(FieldPath.documentId, descending: true)
              .get();

      return snapshot.docs.map((doc) => DailyQuiz.fromFirestore(doc)).toList();
    } catch (e) {
      print('⚠️ DailyQuizService.getRecentQuizzes 에러: $e');
      return [];
    }
  }

  /// 특정 카테고리 퀴즈 가져오기
  static Future<List<DailyQuiz>> getByCategory(
    String category, {
    int limit = 10,
  }) async {
    try {
      final snapshot =
          await _firestore
              .collection(_collection)
              .where('category', isEqualTo: category)
              .orderBy('createdAt', descending: true)
              .limit(limit)
              .get();

      return snapshot.docs.map((doc) => DailyQuiz.fromFirestore(doc)).toList();
    } catch (e) {
      print('⚠️ DailyQuizService.getByCategory 에러: $e');
      return [];
    }
  }

  /// 퀴즈 추가 (Admin용)
  /// dateKey를 문서 ID로 사용
  static Future<bool> add(DailyQuiz quiz) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(quiz.dateKey)
          .set(quiz.toFirestore());
      return true;
    } catch (e) {
      print('⚠️ DailyQuizService.add 에러: $e');
      return false;
    }
  }

  /// 퀴즈 수정 (Admin용)
  static Future<bool> update(String dateKey, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(_collection).doc(dateKey).update(data);
      return true;
    } catch (e) {
      print('⚠️ DailyQuizService.update 에러: $e');
      return false;
    }
  }

  /// 퀴즈 삭제 (Admin용)
  static Future<bool> delete(String dateKey) async {
    try {
      await _firestore.collection(_collection).doc(dateKey).delete();
      return true;
    } catch (e) {
      print('⚠️ DailyQuizService.delete 에러: $e');
      return false;
    }
  }

  /// 날짜 포맷 헬퍼 (YYYY-MM-DD)
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
