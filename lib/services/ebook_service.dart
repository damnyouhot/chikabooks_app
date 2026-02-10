import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
}
