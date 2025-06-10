import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/job.dart';

class JobService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<List<Job>> fetchJobs({
    String careerFilter = '전체',
    String regionFilter = '전체',
    RangeValues? salaryRange,
  }) async {
    final snapshot = await _db
        .collection('jobs')
        .orderBy('postedAt', descending: true)
        .get();
    List<Job> jobs = snapshot.docs.map((d) => Job.fromDoc(d)).toList();

    if (careerFilter != '전체') {
      jobs = jobs.where((job) => job.career == careerFilter).toList();
    }
    if (regionFilter != '전체') {
      jobs = jobs.where((job) => job.address.contains(regionFilter)).toList();
    }
    if (salaryRange != null) {
      jobs = jobs.where((job) {
        final minSalary = job.salaryRange.first;
        final maxSalary = job.salaryRange.last;
        return maxSalary >= salaryRange.start && minSalary <= salaryRange.end;
      }).toList();
    }

    return jobs;
  }

  Future<Job> fetchJob(String id) async {
    final doc = await _db.collection('jobs').doc(id).get();
    return Job.fromDoc(doc);
  }

  Stream<List<String>> watchBookmarkedJobIds() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return [];
      return List<String>.from(doc.data()?['bookmarkedJobs'] ?? []);
    });
  }

  Future<void> bookmarkJob(String jobId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({
      'bookmarkedJobs': FieldValue.arrayUnion([jobId])
    });
  }

  Future<void> unbookmarkJob(String jobId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({
      'bookmarkedJobs': FieldValue.arrayRemove([jobId])
    });
  }

  Future<List<Job>> fetchBookmarkedJobs() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final userDoc = await _db.collection('users').doc(uid).get();
    final List<String> bookmarkedIds =
        List<String>.from(userDoc.data()?['bookmarkedJobs'] ?? []);

    if (bookmarkedIds.isEmpty) return [];

    final jobDocs = await _db
        .collection('jobs')
        .where(FieldPath.documentId, whereIn: bookmarkedIds)
        .get();
    return jobDocs.docs.map((doc) => Job.fromDoc(doc)).toList();
  }
}
