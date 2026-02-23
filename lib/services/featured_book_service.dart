import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/featured_book.dart';

/// 추천 책 관리 서비스
class FeaturedBookService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionFeatured = 'featuredBooks';
  static const String _collectionBooks = 'books';

  /// 현재 주차의 추천 책 가져오기 (카드용)
  static Future<Map<String, dynamic>?> getCurrentFeaturedBook() async {
    try {
      final now = DateTime.now();

      // featuredBooks에서 현재 주차 책 찾기
      final snapshot =
          await _firestore
              .collection(_collectionFeatured)
              .where('isActive', isEqualTo: true)
              .where('weekStart', isLessThanOrEqualTo: Timestamp.fromDate(now))
              .where('weekEnd', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
              .orderBy('weekStart', descending: false)
              .orderBy('order', descending: false)
              .limit(1)
              .get();

      if (snapshot.docs.isEmpty) {
        print('⚠️ 현재 주차의 추천 책이 없습니다');
        return null;
      }

      final featuredBook = FeaturedBook.fromFirestore(snapshot.docs.first);

      // books 컬렉션에서 책 정보 가져오기
      final bookDoc =
          await _firestore
              .collection(_collectionBooks)
              .doc(featuredBook.bookId)
              .get();

      if (!bookDoc.exists) {
        print('⚠️ 책 정보를 찾을 수 없습니다: ${featuredBook.bookId}');
        return null;
      }

      final bookData = bookDoc.data() as Map<String, dynamic>;

      // featuredBook + book 정보 합쳐서 반환
      return {
        'featuredBookId': featuredBook.id,
        'bookId': featuredBook.bookId,
        'title': bookData['title'] ?? '',
        'subtitle': featuredBook.subtitle,
        'coverUrl': bookData['coverUrl'] ?? bookData['coverImageUrl'] ?? '',
        'author': bookData['author'] ?? '',
        'weekStart': featuredBook.weekStart,
        'weekEnd': featuredBook.weekEnd,
      };
    } catch (e) {
      print('⚠️ FeaturedBookService.getCurrentFeaturedBook 에러: $e');
      return null;
    }
  }

  /// 모든 활성 추천 책 가져오기
  static Future<List<FeaturedBook>> getAllActive() async {
    try {
      final snapshot =
          await _firestore
              .collection(_collectionFeatured)
              .where('isActive', isEqualTo: true)
              .orderBy('weekStart', descending: true)
              .get();

      return snapshot.docs
          .map((doc) => FeaturedBook.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('⚠️ FeaturedBookService.getAllActive 에러: $e');
      return [];
    }
  }

  /// 추천 책 추가 (Admin용)
  static Future<String?> add(FeaturedBook featuredBook) async {
    try {
      final docRef = await _firestore
          .collection(_collectionFeatured)
          .add(featuredBook.toFirestore());
      return docRef.id;
    } catch (e) {
      print('⚠️ FeaturedBookService.add 에러: $e');
      return null;
    }
  }

  /// 추천 책 수정 (Admin용)
  static Future<bool> update(String id, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(_collectionFeatured).doc(id).update(data);
      return true;
    } catch (e) {
      print('⚠️ FeaturedBookService.update 에러: $e');
      return false;
    }
  }

  /// 추천 책 삭제 (Admin용)
  static Future<bool> delete(String id) async {
    try {
      await _firestore.collection(_collectionFeatured).doc(id).delete();
      return true;
    } catch (e) {
      print('⚠️ FeaturedBookService.delete 에러: $e');
      return false;
    }
  }
}
