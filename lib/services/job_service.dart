import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/job.dart';

class JobService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /* ── 공고 리스트 (필터 적용) ───────────────────────── */
  Future<List<Job>> fetchJobs({
    String careerFilter = '전체',
    String regionFilter = '전체',
    RangeValues? salaryRange,
  }) async {
    final qs = await _db
        .collection('jobs')
        .orderBy('postedAt', descending: true)
        .get();

    List<Job> jobs = qs.docs.map(Job.fromDoc).toList();

    if (careerFilter != '전체') {
      jobs = jobs.where((j) => j.career == careerFilter).toList();
    }
    if (regionFilter != '전체') {
      jobs = jobs.where((j) => j.address.contains(regionFilter)).toList();
    }
    if (salaryRange != null) {
      jobs = jobs.where((j) {
        final min = j.salaryRange.first;
        final max = j.salaryRange.last;
        return max >= salaryRange.start && min <= salaryRange.end;
      }).toList();
    }
    return jobs;
  }

  /* ── 단건 조회 ───────────────────────── */
  Future<Job> fetchJob(String id) async {
    final doc = await _db.collection('jobs').doc(id).get();
    return Job.fromJson(doc.id, doc.data()!);
  }

  /* ── 북마크 ───────────────────────────── */
  CollectionReference<Map<String, dynamic>> _bkCol() => _db
      .collection('users')
      .doc(_auth.currentUser!.uid)
      .collection('bookmarks');

  Future<void> bookmarkJob(String id) =>
      _bkCol().doc(id).set({'ts': FieldValue.serverTimestamp()});
  Future<void> unbookmarkJob(String id) => _bkCol().doc(id).delete();

  Stream<List<String>> watchBookmarkedJobIds() =>
      _bkCol().snapshots().map((qs) => qs.docs.map((d) => d.id).toList());

  Future<List<Job>> fetchBookmarkedJobs() async {
    final ids = (await _bkCol().get()).docs.map((d) => d.id).toList();
    if (ids.isEmpty) return [];
    final qs = await _db
        .collection('jobs')
        .where(FieldPath.documentId, whereIn: ids)
        .get();
    return qs.docs.map(Job.fromDoc).toList();
  }
}
