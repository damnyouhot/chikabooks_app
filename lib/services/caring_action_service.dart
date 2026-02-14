import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../data/caring_ments.dart';
import '../models/activity_log.dart';
import '../services/caring_state_service.dart';
import '../services/bond_score_service.dart';

/// 돌보기(나 탭) 액션 처리 서비스
///
/// 밥주기/교감/글쓰기/목표 액션의 멘트 선택, 결 점수 적용, 상태 업데이트 담당
class CaringActionService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static final _random = Random();

  static DocumentReference<Map<String, dynamic>>? get _userRef {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  // ═══════════════════════ 하루 정산 ═══════════════════════

  /// 앱 시작 시 호출: 날짜 변경 확인 및 정산
  static Future<void> dailySettle() async {
    try {
      final state = await CaringStateService.loadState();
      final todayKey = _dateKey(DateTime.now());

      // 날짜가 같으면 정산 불필요
      if (state.lastActionDate == todayKey) return;

      // 날짜 변경됨: 어제 정산
      double bondDelta = 0.0;

      // 1) 밥 정산
      if (state.fedCountToday == 0) {
        // 어제 0회 → 감점 + 스트릭 증가
        bondDelta -= 0.1;
        final newStreak = state.skipDaysStreak + 1;
        if (newStreak == 2) bondDelta -= 0.1; // 2일 연속
        if (newStreak >= 3) bondDelta -= 0.2; // 3일 이상

        await _saveState(state.copyWith(
          skipDaysStreak: newStreak,
          lastFedSlots: [],
          fedCountToday: 0,
          touchCountToday: 0,
          diaryCountToday: 0,
          lastActionDate: todayKey,
        ));
      } else if (state.fedCountToday == 4) {
        // 어제 4회 올클 → 보너스
        bondDelta += 0.1;

        await _saveState(state.copyWith(
          skipDaysStreak: 0,
          lastFedSlots: [],
          fedCountToday: 0,
          touchCountToday: 0,
          diaryCountToday: 0,
          lastActionDate: todayKey,
        ));
      } else {
        // 어제 1~3회 → 스트릭 리셋
        await _saveState(state.copyWith(
          skipDaysStreak: 0,
          lastFedSlots: [],
          fedCountToday: 0,
          touchCountToday: 0,
          diaryCountToday: 0,
          lastActionDate: todayKey,
        ));
      }

      // 결 점수 적용
      if (bondDelta != 0.0) {
        await BondScoreService.applyEvent(
          _auth.currentUser!.uid,
          ActivityType.slotPost,
          customDelta: bondDelta,
        );
      }

      debugPrint('✅ dailySettle: bondDelta=$bondDelta');
    } catch (e) {
      debugPrint('⚠️ CaringActionService.dailySettle error: $e');
    }
  }

  // ═══════════════════════ 밥주기 (Feed) ═══════════════════════

  /// 밥주기 시도
  static Future<FeedResult> tryFeed() async {
    try {
      final state = await CaringStateService.loadState();
      final now = DateTime.now();
      final todayKey = _dateKey(now);

      // 날짜 변경 체크 (정산이 안 된 상태라면 먼저 정산)
      if (state.lastActionDate != todayKey) {
        await dailySettle();
        // 정산 후 다시 로드
        final newState = await CaringStateService.loadState();
        return _processFeed(newState, now, todayKey);
      }

      return _processFeed(state, now, todayKey);
    } catch (e) {
      debugPrint('⚠️ CaringActionService.tryFeed error: $e');
      return FeedResult(
        success: false,
        rejectMent: '오류가 발생했어요.',
      );
    }
  }

  static Future<FeedResult> _processFeed(
    CaringState state,
    DateTime now,
    String todayKey,
  ) async {
    // 현재 시간대 확인
    final slotId = _getTimeSlot(now);

    // 중복 체크
    if (state.lastFedSlots.contains(slotId)) {
      final rejectMent = _pickRandom(CaringMents.feedReject);
      return FeedResult(success: false, rejectMent: rejectMent);
    }

    // 성공: 슬롯 추가, 카운트 증가
    final newSlots = [...state.lastFedSlots, slotId];
    final newCount = state.fedCountToday + 1;

    await _saveState(state.copyWith(
      lastFedSlots: newSlots,
      fedCountToday: newCount,
      skipDaysStreak: 0, // 밥 주면 스트릭 리셋
      lastActionDate: todayKey,
    ));

    // 결 점수 +0.1
    await BondScoreService.applyEvent(
      _auth.currentUser!.uid,
      ActivityType.slotPost,
      customDelta: 0.1,
    );

    // 멘트 선택 (skipStreak 반영)
    final ment = _pickFeedSuccessMent(state.skipDaysStreak);

    return FeedResult(
      success: true,
      ment: ment,
      bondDelta: 0.1,
    );
  }

  static String _pickFeedSuccessMent(int skipStreak) {
    List<String> pool;
    if (skipStreak == 0) {
      pool = CaringMents.feedSuccessNormal;
    } else if (skipStreak <= 2) {
      pool = CaringMents.feedSuccessSkip1_2;
    } else if (skipStreak <= 5) {
      pool = CaringMents.feedSuccessSkip3_5;
    } else {
      pool = CaringMents.feedSuccessSkip6Plus;
    }
    return _pickRandom(pool);
  }

  // ═══════════════════════ 교감 (Touch) ═══════════════════════

  /// 교감 시도
  static Future<TouchResult> tryTouch() async {
    try {
      final state = await CaringStateService.loadState();
      final now = DateTime.now();
      final todayKey = _dateKey(now);

      // 날짜 변경 체크
      if (state.lastActionDate != todayKey) {
        await dailySettle();
        final newState = await CaringStateService.loadState();
        return _processTouch(newState, todayKey);
      }

      return _processTouch(state, todayKey);
    } catch (e) {
      debugPrint('⚠️ CaringActionService.tryTouch error: $e');
      return TouchResult(ment: '오류가 발생했어요.', bondDelta: 0.0);
    }
  }

  static Future<TouchResult> _processTouch(
    CaringState state,
    String todayKey,
  ) async {
    // 상한 체크 (하루 3회)
    if (state.touchCountToday >= 3) {
      return TouchResult(
        ment: _pickRandom(CaringMents.touchFirst),
        bondDelta: 0.0,
      );
    }

    final newCount = state.touchCountToday + 1;

    await _saveState(state.copyWith(
      touchCountToday: newCount,
      lastActionDate: todayKey,
    ));

    // 결 점수 +0.05
    await BondScoreService.applyEvent(
      _auth.currentUser!.uid,
      ActivityType.slotPost,
      customDelta: 0.05,
    );

    // 멘트 선택 (컨텍스트 기반)
    final ment = _pickTouchMent(state);

    return TouchResult(ment: ment, bondDelta: 0.05);
  }

  static String _pickTouchMent(CaringState state) {
    // 첫 교감
    if (state.touchCountToday == 0) {
      return _pickRandom(CaringMents.touchFirst);
    }

    // 밥 0회인 날
    if (state.fedCountToday == 0) {
      return _pickRandom(CaringMents.touchNoFeed);
    }

    // 글 쓴 날 (diaryCountToday > 0)
    if (state.diaryCountToday > 0) {
      return _pickRandom(CaringMents.touchWrote);
    }

    // 연속 방문 (임시: skipStreak == 0)
    if (state.skipDaysStreak == 0) {
      return _pickRandom(CaringMents.touchStreak);
    }

    // 오랜만 (skipStreak > 0)
    return _pickRandom(CaringMents.touchLongGap);
  }

  // ═══════════════════════ 글쓰기 (Diary) ═══════════════════════

  /// 글쓰기 완료 (다이어리 저장 후 호출)
  static Future<DiaryResult> completeDiary() async {
    try {
      final state = await CaringStateService.loadState();
      final now = DateTime.now();
      final todayKey = _dateKey(now);

      // 날짜 변경 체크
      if (state.lastActionDate != todayKey) {
        await dailySettle();
        final newState = await CaringStateService.loadState();
        return _processDiary(newState, todayKey);
      }

      return _processDiary(state, todayKey);
    } catch (e) {
      debugPrint('⚠️ CaringActionService.completeDiary error: $e');
      return DiaryResult(ment: '오류가 발생했어요.', bondDelta: 0.0);
    }
  }

  static Future<DiaryResult> _processDiary(
    CaringState state,
    String todayKey,
  ) async {
    // 상한 체크 (하루 2회)
    double bondDelta = 0.0;
    if (state.diaryCountToday == 0) {
      bondDelta = 0.1; // 첫 글
    } else if (state.diaryCountToday == 1) {
      bondDelta = 0.05; // 두 번째 글
    }
    // 2회 이상이면 포인트 없음

    final newCount = state.diaryCountToday + 1;

    await _saveState(state.copyWith(
      diaryCountToday: newCount,
      lastActionDate: todayKey,
    ));

    if (bondDelta > 0.0) {
      await BondScoreService.applyEvent(
        _auth.currentUser!.uid,
        ActivityType.slotPost,
        customDelta: bondDelta,
      );
    }

    // 멘트 선택 (단순 랜덤)
    final ment = _pickRandom(CaringMents.diary);

    return DiaryResult(ment: ment, bondDelta: bondDelta);
  }

  // ═══════════════════════ 목표 (Goal) ═══════════════════════

  /// 목표 액션별 멘트 + 결 점수
  static Future<GoalResult> handleGoalAction(GoalAction action) async {
    try {
      double bondDelta = 0.0;
      List<String> mentPool;

      switch (action) {
        case GoalAction.created:
          bondDelta = 0.05;
          mentPool = CaringMents.goalCreated;
          break;
        case GoalAction.checked:
          bondDelta = 0.1;
          mentPool = CaringMents.goalChecked;
          break;
        case GoalAction.completed:
          bondDelta = 0.3;
          mentPool = CaringMents.goalCompleted;
          break;
        case GoalAction.missed:
          bondDelta = 0.0;
          mentPool = CaringMents.goalMissed;
          break;
        case GoalAction.restarted:
          bondDelta = 0.0;
          mentPool = CaringMents.goalRestarted;
          break;
      }

      if (bondDelta > 0.0) {
        await BondScoreService.applyEvent(
          _auth.currentUser!.uid,
          ActivityType.slotPost,
          customDelta: bondDelta,
        );
      }

      final ment = _pickRandom(mentPool);
      return GoalResult(ment: ment, bondDelta: bondDelta);
    } catch (e) {
      debugPrint('⚠️ CaringActionService.handleGoalAction error: $e');
      return GoalResult(ment: '오류가 발생했어요.', bondDelta: 0.0);
    }
  }

  // ═══════════════════════ 유틸 ═══════════════════════

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static String _getTimeSlot(DateTime dt) {
    final hour = dt.hour;
    if (hour >= 6 && hour < 11) return 'morning';
    if (hour >= 11 && hour < 16) return 'lunch';
    if (hour >= 16 && hour < 21) return 'dinner';
    return 'night'; // 21~23 (00~05는 night로 간주)
  }

  static String _pickRandom(List<String> pool) {
    if (pool.isEmpty) return '';
    return pool[_random.nextInt(pool.length)];
  }

  static Future<void> _saveState(CaringState state) async {
    try {
      final ref = _userRef;
      if (ref == null) return;

      await ref.set({
        'caringState': state.toMap(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ CaringActionService._saveState error: $e');
    }
  }
}

// ═══════════════════════ 결과 객체들 ═══════════════════════

class FeedResult {
  final bool success;
  final String? ment; // 성공 멘트
  final String? rejectMent; // 거절 멘트
  final double bondDelta;

  FeedResult({
    required this.success,
    this.ment,
    this.rejectMent,
    this.bondDelta = 0.0,
  });
}

class TouchResult {
  final String ment;
  final double bondDelta;

  TouchResult({required this.ment, required this.bondDelta});
}

class DiaryResult {
  final String ment;
  final double bondDelta;

  DiaryResult({required this.ment, required this.bondDelta});
}

class GoalResult {
  final String ment;
  final double bondDelta;

  GoalResult({required this.ment, required this.bondDelta});
}

enum GoalAction {
  created,
  checked,
  completed,
  missed,
  restarted,
}

