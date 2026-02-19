import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/hira_update.dart';

/// HIRA 수가/급여 변경 업데이트 서비스
class HiraUpdateService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// 오늘의 Digest 가져오기
  static Future<HiraDigest?> getTodayDigest() async {
    try {
      final dateKey = _getCurrentDateKey();
      final doc = await _db
          .collection('content_hira_digest')
          .doc(dateKey)
          .get();

      if (!doc.exists || doc.data() == null) {
        debugPrint('⚠️ No digest found for $dateKey');
        return null;
      }

      return HiraDigest.fromMap(dateKey, doc.data()!);
    } catch (e) {
      debugPrint('⚠️ HiraUpdateService.getTodayDigest error: $e');
      return null;
    }
  }

  /// 여러 업데이트 가져오기
  static Future<List<HiraUpdate>> getUpdates(List<String> docIds) async {
    if (docIds.isEmpty) return [];

    try {
      final updates = <HiraUpdate>[];
      
      for (final id in docIds) {
        final doc = await _db
            .collection('content_hira_updates')
            .doc(id)
            .get();

        if (doc.exists && doc.data() != null) {
          updates.add(HiraUpdate.fromMap(id, doc.data()!));
        }
      }

      return updates;
    } catch (e) {
      debugPrint('⚠️ HiraUpdateService.getUpdates error: $e');
      return [];
    }
  }

  /// 업데이트 저장 (스크랩)
  static Future<bool> saveUpdate(HiraUpdate update) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return false;

      await _db
          .collection('users')
          .doc(uid)
          .collection('saved_hira_updates')
          .doc(update.id)
          .set({
        'savedAt': FieldValue.serverTimestamp(),
        'title': update.title,
        'link': update.link,
        'publishedAt': Timestamp.fromDate(update.publishedAt),
        'impactLevel': update.impactLevel,
      });

      debugPrint('✅ Saved HIRA update: ${update.id}');
      return true;
    } catch (e) {
      debugPrint('⚠️ HiraUpdateService.saveUpdate error: $e');
      return false;
    }
  }

  /// 업데이트 저장 취소
  static Future<bool> unsaveUpdate(String updateId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return false;

      await _db
          .collection('users')
          .doc(uid)
          .collection('saved_hira_updates')
          .doc(updateId)
          .delete();

      debugPrint('✅ Unsaved HIRA update: $updateId');
      return true;
    } catch (e) {
      debugPrint('⚠️ HiraUpdateService.unsaveUpdate error: $e');
      return false;
    }
  }

  /// 저장 여부 실시간 감시
  static Stream<bool> watchSaved(String updateId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(false);

    return _db
        .collection('users')
        .doc(uid)
        .collection('saved_hira_updates')
        .doc(updateId)
        .snapshots()
        .map((snap) => snap.exists);
  }

  /// 저장된 업데이트 목록 가져오기
  static Stream<List<HiraUpdate>> watchSavedUpdates() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(uid)
        .collection('saved_hira_updates')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
      final ids = snap.docs.map((doc) => doc.id).toList();
      return await getUpdates(ids);
    });
  }

  /// 현재 날짜 키 (YYYY-MM-DD)
  static String _getCurrentDateKey() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }
}

