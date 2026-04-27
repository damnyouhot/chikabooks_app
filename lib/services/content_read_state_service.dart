import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ContentReadKeys {
  ContentReadKeys._();

  static const bondPolls = 'bond_polls';
  static const seniorQuestions = 'senior_questions';
  static const todayQuiz = 'today_quiz';
  static const todayWords = 'today_words';
  static const hiraPolicyUpdates = 'hira_policy_updates';
  static const ebooks = 'ebooks';
  static const savedHiraUpdates = 'saved_hira_updates';
  static const savedWords = 'saved_words';
  static const jobs = 'jobs';
}

class ContentReadStateService {
  ContentReadStateService._();

  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  static DocumentReference<Map<String, dynamic>>? _readStateDoc(String key) {
    final uid = _uid;
    if (uid == null) return null;
    return _db
        .collection('users')
        .doc(uid)
        .collection('content_read_states')
        .doc(key);
  }

  static Stream<Set<int>> watchNewIndices(Map<int, List<String>> keysByIndex) {
    if (keysByIndex.isEmpty || _uid == null) return Stream.value(const {});

    final keys = keysByIndex.values.expand((list) => list).toSet();
    late final StreamController<Set<int>> controller;
    final subscriptions = <StreamSubscription<dynamic>>[];
    final latestByKey = <String, DateTime?>{};
    final seenByKey = <String, DateTime?>{};

    bool hasNew(String key) {
      final latest = latestByKey[key];
      if (latest == null) return false;
      final seen = seenByKey[key];
      return seen == null || latest.isAfter(seen);
    }

    void emit() {
      if (controller.isClosed) return;
      controller.add({
        for (final entry in keysByIndex.entries)
          if (entry.value.any(hasNew)) entry.key,
      });
    }

    controller = StreamController<Set<int>>.broadcast(
      onListen: () {
        for (final key in keys) {
          subscriptions.add(
            _latestStreamFor(key).listen(
              (value) {
                latestByKey[key] = value;
                emit();
              },
              onError: (Object error, StackTrace stackTrace) {
                debugPrint('⚠️ ContentRead latest($key): $error');
              },
            ),
          );
          subscriptions.add(
            _seenStreamFor(key).listen(
              (value) {
                seenByKey[key] = value;
                emit();
              },
              onError: (Object error, StackTrace stackTrace) {
                debugPrint('⚠️ ContentRead seen($key): $error');
              },
            ),
          );
        }
      },
      onCancel: () async {
        for (final sub in subscriptions) {
          await sub.cancel();
        }
        subscriptions.clear();
      },
    );

    return controller.stream;
  }

  static Future<void> markSeen(String key) => markSeenKeys([key]);

  static Future<void> markSeenKeys(Iterable<String> keys) async {
    final uid = _uid;
    if (uid == null) return;
    final uniqueKeys = keys.toSet();
    if (uniqueKeys.isEmpty) return;

    try {
      final batch = _db.batch();
      for (final key in uniqueKeys) {
        final ref = _db
            .collection('users')
            .doc(uid)
            .collection('content_read_states')
            .doc(key);
        batch.set(ref, {
          'key': key,
          'seenAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('⚠️ ContentReadStateService.markSeenKeys: $e');
    }
  }

  static Stream<DateTime?> _seenStreamFor(String key) {
    final ref = _readStateDoc(key);
    if (ref == null) return Stream.value(null);
    return ref.snapshots().map((doc) {
      final data = doc.data();
      return (data?['seenAt'] as Timestamp?)?.toDate();
    });
  }

  static Stream<DateTime?> _latestStreamFor(String key) {
    return switch (key) {
      ContentReadKeys.bondPolls => _latestFromQuery(
        _db
            .collection('polls')
            .where(
              'startsAt',
              isLessThanOrEqualTo: Timestamp.fromDate(DateTime.now()),
            )
            .orderBy('startsAt', descending: true)
            .limit(1),
        const ['startsAt', 'createdAt'],
      ),
      ContentReadKeys.seniorQuestions => _latestFromQuery(
        _db
            .collection('seniorQuestions')
            .orderBy('createdAt', descending: true)
            .limit(1),
        const ['createdAt'],
      ),
      ContentReadKeys.todayQuiz => _todayQuizStream(),
      ContentReadKeys.todayWords => Stream.value(_todayKstStartUtc()),
      ContentReadKeys.hiraPolicyUpdates => _latestFromQuery(
        _db
            .collection('content_hira_updates')
            .orderBy('publishedAt', descending: true)
            .limit(1),
        const ['publishedAt', 'fetchedAt'],
      ),
      ContentReadKeys.ebooks => _latestFromQuery(
        _db
            .collection('ebooks')
            .orderBy('publishedAt', descending: true)
            .limit(1),
        const ['publishedAt', 'createdAt'],
      ),
      ContentReadKeys.savedHiraUpdates => _latestUserSubcollection(
        'saved_hira_updates',
        'savedAt',
        const ['savedAt', 'publishedAt'],
      ),
      ContentReadKeys.savedWords => _latestUserSubcollection(
        'saved_words',
        'savedAt',
        const ['savedAt'],
      ),
      ContentReadKeys.jobs => _latestFromQuery(
        _db.collection('jobs').orderBy('createdAt', descending: true).limit(1),
        const ['createdAt', 'postedAt'],
      ),
      _ => Stream.value(null),
    };
  }

  static Stream<DateTime?> _todayQuizStream() {
    return _db.collection('quiz_schedule').doc(_todayKey()).snapshots().map((
      doc,
    ) {
      final data = doc.data();
      if (data == null) return null;
      return (data['createdAt'] as Timestamp?)?.toDate() ?? _todayKstStartUtc();
    });
  }

  static Stream<DateTime?> _latestUserSubcollection(
    String collection,
    String orderField,
    List<String> timestampFields,
  ) {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _latestFromQuery(
      _db
          .collection('users')
          .doc(uid)
          .collection(collection)
          .orderBy(orderField, descending: true)
          .limit(1),
      timestampFields,
    );
  }

  static Stream<DateTime?> _latestFromQuery(
    Query<Map<String, dynamic>> query,
    List<String> timestampFields,
  ) {
    return query.snapshots().map((snap) {
      if (snap.docs.isEmpty) return null;
      final data = snap.docs.first.data();
      for (final field in timestampFields) {
        final value = data[field];
        if (value is Timestamp) return value.toDate();
      }
      return null;
    });
  }

  static String _todayKey() {
    final nowKst = DateTime.now().toUtc().add(const Duration(hours: 9));
    return '${nowKst.year}-${nowKst.month.toString().padLeft(2, '0')}-'
        '${nowKst.day.toString().padLeft(2, '0')}';
  }

  static DateTime _todayKstStartUtc() {
    final nowKst = DateTime.now().toUtc().add(const Duration(hours: 9));
    return DateTime.utc(
      nowKst.year,
      nowKst.month,
      nowKst.day,
    ).subtract(const Duration(hours: 9));
  }
}
