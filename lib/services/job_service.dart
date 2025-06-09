import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/job.dart';
import 'package:flutter/foundation.dart';

class JobService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<List<Job>> fetchJobs({String careerFilter = '전체'}) async {
    Query query = _db.collection('jobs').orderBy('postedAt', descending: true);

    if (careerFilter != '전체') {
      query = query.where('career', isEqualTo: careerFilter);
    }

    final snapshot = await query.get();
    debugPrint('🗂️ 불러온 공고 수: ${snapshot.docs.length} (필터: $careerFilter)');
    return snapshot.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      return Job.fromJson(data, docId: d.id);
    }).toList();
  }

  Future<Job> fetchJob(String id) async {
    final doc = await _db.collection('jobs').doc(id).get();
    return Job.fromJson(doc.data()!, docId: doc.id);
  }

  // ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼ 북마크 관련 함수들 추가 ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
  // 현재 사용자의 북마크된 직업 ID 목록을 실시간으로 감시
  Stream<List<String>> watchBookmarkedJobIds() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return [];
      return List<String>.from(doc.data()?['bookmarkedJobs'] ?? []);
    });
  }

  // 북마크 추가
  Future<void> bookmarkJob(String jobId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({
      'bookmarkedJobs': FieldValue.arrayUnion([jobId])
    });
  }

  // 북마크 제거
  Future<void> unbookmarkJob(String jobId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({
      'bookmarkedJobs': FieldValue.arrayRemove([jobId])
    });
  }

  // 북마크된 직업 목록 불러오기
  Future<List<Job>> fetchBookmarkedJobs() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final userDoc = await _db.collection('users').doc(uid).get();
    final List<String> bookmarkedIds =
        List<String>.from(userDoc.data()?['bookmarkedJobs'] ?? []);

    if (bookmarkedIds.isEmpty) return [];

    // ID 목록으로 여러 문서를 한 번에 가져오기
    final jobDocs = await _db
        .collection('jobs')
        .where(FieldPath.documentId, whereIn: bookmarkedIds)
        .get();
    return jobDocs.docs.map((doc) => Job.fromDoc(doc)).toList();
  }
  // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲ 북마크 관련 함수들 추가 ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
}
