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

  Stream<QuerySnapshot> watchBookmarks(String ebookId) {
    return _getPurchaseDocRef(ebookId)
        .collection('bookmarks')
        .orderBy('createdAt')
        .snapshots();
  }
}
