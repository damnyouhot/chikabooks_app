import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/ebook.dart';

class EbookService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Stream<List<Ebook>> watchEbooks() {
    return _db
        .collection('ebooks')
        .orderBy('publishedAt', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map((doc) => Ebook.fromDoc(doc)).toList());
  }

  /// 전체 전자책 1회 조회 (스트림 대신 — 리스트/카드용)
  Future<List<Ebook>> fetchAllEbooks() async {
    final qs = await _db
        .collection('ebooks')
        .orderBy('publishedAt', descending: true)
        .get();
    return qs.docs.map((doc) => Ebook.fromDoc(doc)).toList();
  }

  /// `publishedAt` 내림차순 페이지 조회 (목록 첫 화면·무한 스크롤용)
  static const int ebookPageSize = 24;

  Future<EbookPageResult> fetchEbooksPage({
    int limit = ebookPageSize,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collection('ebooks')
        .orderBy('publishedAt', descending: true)
        .limit(limit);
    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }
    final snap = await q.get();
    final books = snap.docs.map(Ebook.fromDoc).toList();
    final last = snap.docs.isEmpty ? null : snap.docs.last;
    final hasMore = snap.docs.length >= limit;
    return EbookPageResult(books: books, lastDocument: last, hasMore: hasMore);
  }

  Future<Ebook> fetchEbook(String id) async {
    final doc = await _db.collection('ebooks').doc(id).get();
    return Ebook.fromDoc(doc);
  }

  DocumentReference _getPurchaseDocRef(String ebookId) {
    final uid = _auth.currentUser!.uid;
    return _db
        .collection('users')
        .doc(uid)
        .collection('purchases')
        .doc(ebookId);
  }

  Future<void> addBookmark(
      String ebookId, String cfi, String chapterTitle) async {
    await _getPurchaseDocRef(ebookId).collection('bookmarks').add({
      'cfi': cfi,
      'title': chapterTitle,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeBookmark(String ebookId, String bookmarkId) async {
    await _getPurchaseDocRef(ebookId)
        .collection('bookmarks')
        .doc(bookmarkId)
        .delete();
  }

  /// 도서 구매 처리 (테스트용)
  Future<void> purchaseEbook(String ebookId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');

    await _db
        .collection('users')
        .doc(uid)
        .collection('purchases')
        .doc(ebookId)
        .set({
      'ebookId': ebookId,
      'purchasedAt': FieldValue.serverTimestamp(),
      'lastReadAt': FieldValue.serverTimestamp(),
      'progress': 0.0,
    }, SetOptions(merge: true));
  }

  /// 특정 도서 구매 여부 확인 (1회 조회)
  Future<bool> hasPurchased(String ebookId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('purchases')
        .doc(ebookId)
        .get();
    return doc.exists;
  }

  /// 구매한 도서 목록 스트림
  Stream<List<String>> watchPurchasedEbookIds() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(uid)
        .collection('purchases')
        .snapshots()
        .map((qs) => qs.docs.map((doc) => doc.id).toList());
  }

  /// 구매한 도서 ID 1회 조회 (스트림 대신)
  Future<List<String>> fetchPurchasedEbookIds() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final qs = await _db
        .collection('users')
        .doc(uid)
        .collection('purchases')
        .get();
    return qs.docs.map((doc) => doc.id).toList();
  }

  /// 읽기 진행도 저장 (PDF: lastPage, EPUB: lastCfi)
  Future<void> saveReadingProgress(
    String ebookId, {
    int? lastPage,
    String? lastCfi,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final data = <String, dynamic>{
      'lastReadAt': FieldValue.serverTimestamp(),
    };
    if (lastPage != null) data['lastPage'] = lastPage;
    if (lastCfi != null) data['lastCfi'] = lastCfi;

    await _getPurchaseDocRef(ebookId).set(data, SetOptions(merge: true));
  }

  /// 읽기 진행도 가져오기
  Future<Map<String, dynamic>?> getReadingProgress(String ebookId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _getPurchaseDocRef(ebookId).get();
    if (!doc.exists) return null;
    return doc.data() as Map<String, dynamic>?;
  }

  Stream<QuerySnapshot> watchBookmarks(String ebookId) {
    return _getPurchaseDocRef(ebookId)
        .collection('bookmarks')
        .orderBy('createdAt')
        .snapshots();
  }

  // ── 아임웹 구매내역 동기화 ──────────────────────────────────
  /// Cloud Function syncImwebPurchases를 호출해 아임웹 구매내역을 Firestore에 저장.
  ///
  /// 반환: { synced: int, skipped: int, message: String }
  Future<Map<String, dynamic>> syncImwebPurchases() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('로그인이 필요합니다.');

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw Exception('계정에 이메일이 연결되어 있지 않습니다.');
    }

    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('syncImwebPurchases');
      final result = await callable.call({'email': email});
      final data = Map<String, dynamic>.from(result.data as Map);
      debugPrint('✅ syncImwebPurchases 완료: $data');
      return data;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ syncImwebPurchases 오류: ${e.code} - ${e.message}');
      rethrow;
    }
  }
}

/// [fetchEbooksPage] 한 번의 결과
class EbookPageResult {
  const EbookPageResult({
    required this.books,
    required this.lastDocument,
    required this.hasMore,
  });

  final List<Ebook> books;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}
