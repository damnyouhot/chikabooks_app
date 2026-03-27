import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
      debugPrint('🔍 HIRA: Looking for digest with dateKey: $dateKey');
      
      final doc = await _db
          .collection('content_hira_digest')
          .doc(dateKey)
          .get();

      debugPrint('🔍 HIRA: Document exists: ${doc.exists}');
      if (doc.exists) {
        debugPrint('🔍 HIRA: Document data: ${doc.data()}');
      }

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

  /// 전체 업데이트 목록 실시간 감시 (3개월, 치과만, 최신순)
  static Stream<List<HiraUpdate>> watchAllUpdates() {
    final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
    
    debugPrint('🔍 HIRA: Watching all updates since ${threeMonthsAgo.toString()}');
    
    return _db
        .collection('content_hira_updates')
        .where('isDental', isEqualTo: 'yes')
        .where('publishedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(threeMonthsAgo))
        .orderBy('publishedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint('✅ HIRA: Stream update - ${snapshot.docs.length} total updates');
      return snapshot.docs
          .map((doc) => HiraUpdate.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  /// 전체 업데이트 목록 가져오기 (3개월, 치과만, 최신순)
  static Future<List<HiraUpdate>> getAllUpdates() async {
    try {
      final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
      
      debugPrint('🔍 HIRA: Fetching all updates since ${threeMonthsAgo.toString()}');
      
      final snapshot = await _db
          .collection('content_hira_updates')
          .where('isDental', isEqualTo: 'yes')
          .where('publishedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(threeMonthsAgo))
          .orderBy('publishedAt', descending: true)
          .get();

      debugPrint('✅ HIRA: Found ${snapshot.docs.length} total updates');
      
      return snapshot.docs
          .map((doc) => HiraUpdate.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('⚠️ HiraUpdateService.getAllUpdates error: $e');
      return [];
    }
  }

  /// 여러 업데이트 가져오기
  static Future<List<HiraUpdate>> getUpdates(List<String> docIds) async {
    if (docIds.isEmpty) {
      debugPrint('⚠️ HIRA: docIds is empty');
      return [];
    }

    try {
      debugPrint('🔍 HIRA: Fetching ${docIds.length} updates: $docIds');
      final updates = <HiraUpdate>[];
      
      for (final id in docIds) {
        final doc = await _db
            .collection('content_hira_updates')
            .doc(id)
            .get();

        debugPrint('🔍 HIRA: Doc $id exists: ${doc.exists}');
        if (doc.exists && doc.data() != null) {
          updates.add(HiraUpdate.fromMap(id, doc.data()!));
        }
      }

      debugPrint('✅ HIRA: Successfully loaded ${updates.length} updates');
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

  /// 심평원 보험인정기준 전체 DB 검색 (Cloud Function 프록시)
  static Future<HiraSearchResponse> searchInsurance({
    required String keyword,
    int page = 1,
    String tab = 'all',
    int perPage = 30,
  }) async {
    try {
      debugPrint('🔍 HIRA search: keyword="$keyword" page=$page tab=$tab');
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('searchHiraInsurance');
      final result = await callable.call<dynamic>(<String, dynamic>{
        'keyword': keyword,
        'page': page,
        'tab': tab,
        'perPage': perPage,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      debugPrint('✅ HIRA search: ${data['totalCount']} total results');
      return HiraSearchResponse.fromMap(data);
    } catch (e) {
      debugPrint('⚠️ HiraUpdateService.searchInsurance error: $e');
      rethrow;
    }
  }

  /// 수가 조회 (data.go.kr API 프록시)
  static Future<FeeSearchResponse> searchFeeSchedule({
    required String keyword,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      debugPrint('🔍 Fee search: keyword="$keyword" page=$page');
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('searchFeeSchedule');
      final result = await callable.call<dynamic>(<String, dynamic>{
        'keyword': keyword,
        'page': page,
        'perPage': perPage,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      debugPrint('✅ Fee search: ${data['totalCount']} total results');
      return FeeSearchResponse.fromMap(data);
    } catch (e) {
      debugPrint('⚠️ HiraUpdateService.searchFeeSchedule error: $e');
      rethrow;
    }
  }

  /// 현재 날짜 키 (YYYY-MM-DD)
  static String _getCurrentDateKey() {
    final now = DateTime.now();
    final dateKey = DateFormat('yyyy-MM-dd').format(now);
    debugPrint('🔍 HIRA: Current DateTime: $now → dateKey: $dateKey');
    return dateKey;
  }
}

