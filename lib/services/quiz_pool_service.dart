import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/quiz_content_config.dart';
import '../models/quiz_pool_item.dart';
import '../models/quiz_schedule.dart';

/// 퀴즈 풀 & 스케줄 관리 서비스
///
/// Firestore 컬렉션:
///   quiz_pool/{autoId}                — 원본 문제 은행
///   quiz_schedule/{dateKey}           — 날짜별 배포 스케줄
///   quiz_meta/state                   — 전체 진행 상태
///   config/quiz_content               — 임상·국시 패크 ID (`QuizContentConfigService`)
///   quiz_packs/{packId}               — 패크 메타
///   users/{uid}/quiz_history/{dateKey} — 유저별 풀이 기록
class QuizPoolService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static const _poolCollection     = 'quiz_pool';
  static const _scheduleCollection = 'quiz_schedule';
  static const _metaDoc            = 'quiz_meta/state';
  static const _historyCollection  = 'quiz_history';

  // ── 날짜 포맷 헬퍼 ───────────────────────────────────────────
  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// KST(UTC+9) 기준 오늘 날짜 키.
  /// 에뮬레이터/해외 기기에서 UTC로 실행되더라도 한국 날짜 기준으로 통일.
  static String get todayKey {
    final nowKst = DateTime.now().toUtc().add(const Duration(hours: 9));
    return _dateKey(nowKst);
  }

  // ══════════════════════════════════════════════════════════════
  // 오늘의 퀴즈 (스케줄 기반)
  // ══════════════════════════════════════════════════════════════

  /// 오늘 날짜의 quiz_schedule 문서를 가져옴.
  /// 없으면 null 반환 (Cloud Function이 생성하기 전이거나 풀 없음).
  static Future<QuizSchedule?> getTodaySchedule({
    QuizContentConfig? contentConfig,
  }) async {
    try {
      final doc = await _db
          .collection(_scheduleCollection)
          .doc(todayKey)
          .get();
      if (!doc.exists) return null;
      return QuizSchedule.fromFirestore(doc, contentConfig: contentConfig);
    } catch (e) {
      debugPrint('⚠️ QuizPoolService.getTodaySchedule: $e');
      return null;
    }
  }

  /// 최근 N일간의 퀴즈 스케줄 목록 (지난 퀴즈 보기)
  static Future<List<QuizSchedule>> getRecentSchedules({
    int days = 3,
    QuizContentConfig? contentConfig,
  }) async {
    try {
      final results = <QuizSchedule>[];
      final todayKst = DateTime.now().toUtc().add(const Duration(hours: 9));
      for (int i = 1; i <= days; i++) {
        final date = todayKst.subtract(Duration(days: i));
        final doc = await _db
            .collection(_scheduleCollection)
            .doc(_dateKey(date))
            .get();
        if (doc.exists) {
          results.add(QuizSchedule.fromFirestore(doc, contentConfig: contentConfig));
        }
      }
      return results;
    } catch (e) {
      debugPrint('⚠️ QuizPoolService.getRecentSchedules: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════
  // 퀴즈 메타 (대시보드 진행 현황)
  // ══════════════════════════════════════════════════════════════

  static Future<QuizMetaState?> getMetaState() async {
    try {
      final doc = await _db.doc(_metaDoc).get();
      if (!doc.exists) return null;
      return QuizMetaState.fromFirestore(doc);
    } catch (e) {
      debugPrint('⚠️ QuizPoolService.getMetaState: $e');
      return null;
    }
  }

  static Stream<QuizMetaState?> watchMetaState() {
    return _db.doc(_metaDoc).snapshots().map((doc) {
      if (!doc.exists) return null;
      return QuizMetaState.fromFirestore(doc);
    });
  }

  // ══════════════════════════════════════════════════════════════
  // 유저 풀이 기록
  // ══════════════════════════════════════════════════════════════

  static String? get _uid => _auth.currentUser?.uid;

  /// 특정 날짜의 풀이 기록 조회
  static Future<UserQuizHistory?> getHistory(String dateKey) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final doc = await _db
          .collection('users')
          .doc(uid)
          .collection(_historyCollection)
          .doc(dateKey)
          .get();
      if (!doc.exists) return null;
      return UserQuizHistory.fromFirestore(doc);
    } catch (e) {
      debugPrint('⚠️ QuizPoolService.getHistory: $e');
      return null;
    }
  }

  /// 최근 N일간의 풀이 기록
  static Future<Map<String, UserQuizHistory>> getRecentHistories({
    int days = 4,
  }) async {
    final uid = _uid;
    if (uid == null) return {};
    try {
      final result = <String, UserQuizHistory>{};
      final todayKst = DateTime.now().toUtc().add(const Duration(hours: 9));
      for (int i = 0; i <= days; i++) {
        final date = todayKst.subtract(Duration(days: i));
        final key = _dateKey(date);
        final doc = await _db
            .collection('users')
            .doc(uid)
            .collection(_historyCollection)
            .doc(key)
            .get();
        if (doc.exists) result[key] = UserQuizHistory.fromFirestore(doc);
      }
      return result;
    } catch (e) {
      debugPrint('⚠️ QuizPoolService.getRecentHistories: $e');
      return {};
    }
  }

  /// 답안 저장
  /// - 이미 답한 quizId면 통계 increment 생략 (중복 카운트 방지)
  /// - answers 맵은 기존 값과 병합하여 저장 (다른 퀴즈 답 보존)
  /// - weekKey가 바뀌면 weekCorrect/weekWrong 초기화 후 저장
  static Future<void> saveAnswer({
    required String dateKey,
    required String quizId,
    required int selectedIndex,
    required List<String> allQuizIds,
    required bool isCorrect,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final userRef  = _db.collection('users').doc(uid);
      final histRef  = userRef.collection(_historyCollection).doc(dateKey);
      final statsRef = userRef.collection('quizStats').doc('summary');

      // 이번 주 월요일 dateKey (KST 기준)
      final nowKst = DateTime.now().toUtc().add(const Duration(hours: 9));
      final monday = nowKst.subtract(Duration(days: nowKst.weekday - 1));
      final weekKey = _dateKey(monday);

      final globalRef = _db.collection('quiz_global').doc('stats');

      await _db.runTransaction((tx) async {
        // ── 1. 기존 값 읽기 (트랜잭션 내 읽기는 쓰기 전에 모두 수행) ──
        final histSnap   = await tx.get(histRef);
        final statsSnap  = await tx.get(statsRef);
        final globalSnap = await tx.get(globalRef);

        final histData  = histSnap.data()  ?? <String, dynamic>{};
        final statsData = statsSnap.data() ?? <String, dynamic>{};

        // ── 2. 이미 이 quizId에 답했는지 확인 ──
        final existingAnswers = Map<String, dynamic>.from(
          histData['answers'] as Map<String, dynamic>? ?? {},
        );
        final alreadyAnswered = existingAnswers.containsKey(quizId);

        // ── 3. answers 맵 병합 (기존 답 유지 + 이번 답 추가) ──
        existingAnswers[quizId] = selectedIndex;

        final prevCorrectCount = (histData['correctCount'] as num?)?.toInt() ?? 0;
        final newCorrectCount  = alreadyAnswered
            ? prevCorrectCount        // 중복 풀이: 카운트 변경 없음
            : prevCorrectCount + (isCorrect ? 1 : 0);

        // ── 4. 히스토리 저장 (병합된 answers 전체 write) ──
        tx.set(histRef, {
          'quizIds':       allQuizIds,
          'answers':       existingAnswers,
          'correctCount':  newCorrectCount,
          'rewardGranted': histData['rewardGranted'] as bool? ?? false,
          'submittedAt':   FieldValue.serverTimestamp(),
        });

        // 이미 답했던 문제면 통계·집계 모두 변경 없음
        if (alreadyAnswered) return;

        // ── 5. 개인 통계 저장: 주차 변경 시 초기화 ──
        final storedWeekKey = statsData['weekKey'] as String?;
        final isSameWeek    = storedWeekKey == weekKey;

        final prevTotalCorrect = (statsData['totalCorrect'] as num?)?.toInt() ?? 0;
        final prevTotalWrong   = (statsData['totalWrong']   as num?)?.toInt() ?? 0;
        final prevWeekCorrect  = isSameWeek
            ? (statsData['weekCorrect'] as num?)?.toInt() ?? 0
            : 0;  // 새 주: 초기화
        final prevWeekWrong    = isSameWeek
            ? (statsData['weekWrong']   as num?)?.toInt() ?? 0
            : 0;  // 새 주: 초기화

        tx.set(statsRef, {
          'totalCorrect':    prevTotalCorrect + (isCorrect ? 1 : 0),
          'totalWrong':      prevTotalWrong   + (isCorrect ? 0 : 1),
          'weekKey':         weekKey,
          'weekCorrect':     prevWeekCorrect  + (isCorrect ? 1 : 0),
          'weekWrong':       prevWeekWrong    + (isCorrect ? 0 : 1),
          'countedInGlobal': true,
          'lastAnsweredAt':  FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

        // ── 6. 글로벌 순위 집계 (quiz_global/stats) ──
        final globalData = globalSnap.data() ?? <String, dynamic>{};
        final distribution = Map<String, dynamic>.from(
          globalData['scoreDistribution'] as Map<String, dynamic>? ?? {},
        );
        var totalParticipants =
            (globalData['totalParticipants'] as num?)?.toInt() ?? 0;

        // countedInGlobal 필드로 이 유저가 글로벌 집계에 포함됐는지 판단
        // (기존 유저도 코드 배포 후 처음 풀면 정상 등록됨)
        final isCountedInGlobal = statsData['countedInGlobal'] == true;
        final newTotalCorrect = prevTotalCorrect + (isCorrect ? 1 : 0);

        // 분포 내 이전 구간 존재 여부 확인:
        // isCountedInGlobal=true 이지만 scoreDistribution 에 없으면
        // cleanup 등으로 글로벌 데이터가 초기화된 "팬텀 유저" 케이스
        final prevBucketCount =
            (distribution[prevTotalCorrect.toString()] as num?)?.toInt() ?? 0;
        final isPhantomUser = isCountedInGlobal && prevBucketCount <= 0;

        if (!isCountedInGlobal || isPhantomUser) {
          // 신규 유저 OR 팬텀 유저: 글로벌 집계에 (재)등록
          totalParticipants += 1;
          final newKey = newTotalCorrect.toString();
          distribution[newKey] =
              ((distribution[newKey] as num?)?.toInt() ?? 0) + 1;
        } else if (isCorrect) {
          // 이미 집계된 유저 + 정답: 이전 구간 -1, 새 구간 +1
          final prevKey = prevTotalCorrect.toString();
          final newKey  = newTotalCorrect.toString();
          final prevBucket = ((distribution[prevKey] as num?)?.toInt() ?? 0) - 1;
          if (prevBucket > 0) {
            distribution[prevKey] = prevBucket;
          } else {
            distribution.remove(prevKey);
          }
          distribution[newKey] =
              ((distribution[newKey] as num?)?.toInt() ?? 0) + 1;
        }
        // 이미 집계된 유저 + 오답: totalCorrect 변화 없음 → 분포 변경 불필요

        debugPrint('📊 [Global] participants=$totalParticipants, '
            'dist=$distribution, counted=$isCountedInGlobal, '
            'newTotalCorrect=$newTotalCorrect');

        tx.set(globalRef, {
          'totalParticipants': totalParticipants,
          'scoreDistribution': distribution,
          'lastUpdatedAt':     FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      debugPrint('⚠️ QuizPoolService.saveAnswer: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // 관리자 전용 — 퀴즈 풀 조회 (대시보드)
  // ══════════════════════════════════════════════════════════════

  /// 전체 퀴즈 풀 (order 순 정렬)
  static Future<List<QuizPoolItem>> getPoolItems({int limit = 50}) async {
    try {
      final snap = await _db
          .collection(_poolCollection)
          .orderBy('order')
          .limit(limit)
          .get();
      return snap.docs.map(QuizPoolItem.fromFirestore).toList();
    } catch (e) {
      debugPrint('⚠️ QuizPoolService.getPoolItems: $e');
      return [];
    }
  }

  /// 특정 문제 비활성화 (isActive = false)
  static Future<void> deactivateItem(String docId) async {
    try {
      await _db.collection(_poolCollection).doc(docId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ QuizPoolService.deactivateItem: $e');
    }
  }
}

