import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../config/reward_constants.dart';

/// 돌보기(1탭) 상태 서비스
///
/// 재우기/깨우기 + 아침 인사 + 리추얼 상태를 Firestore에 저장.
/// users/{uid} 문서의 caringState 필드를 사용.
class CaringStateService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static DocumentReference<Map<String, dynamic>>? get _userRef {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  // ═══════════════════════ 읽기 ═══════════════════════

  /// 현재 돌보기 상태 로드
  static Future<CaringState> loadState() async {
    try {
      final ref = _userRef;
      if (ref == null) return CaringState.initial();

      final doc = await ref.get();
      final data = doc.data();
      if (data == null) return CaringState.initial();

      final cs = data['caringState'] as Map<String, dynamic>?;
      if (cs == null) return CaringState.initial();

      return CaringState.fromMap(cs);
    } catch (e) {
      debugPrint('⚠️ CaringStateService.loadState error: $e');
      return CaringState.initial();
    }
  }

  // ═══════════════════════ 쓰기 ═══════════════════════

  /// 상태 저장 (merge)
  static Future<void> _save(Map<String, dynamic> fields) async {
    try {
      final ref = _userRef;
      if (ref == null) return;

      await ref.set({
        'caringState': fields,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ CaringStateService._save error: $e');
    }
  }

  /// 아침 인사 완료 처리 (출석 체크 통합)
  static Future<String> completeGreeting() async {
    try {
      final ref = _userRef;
      if (ref == null) return '로그인이 필요합니다.';

      final now = DateTime.now();
      final todayKey = _dateKey(now);

      // 출석 포인트 적립 (아침 인사 = 출석)
      await ref.set({
        'caringState': {
          'hasGreetedDate': todayKey,
          'isSleeping': false,
          'lastWakeAt': Timestamp.fromDate(now),
        },
        'emotionPoints': FieldValue.increment(RewardPolicy.attendance),
        'lastCheckIn': Timestamp.fromDate(now),
      }, SetOptions(merge: true));

      return '좋은 아침이에요.';
    } catch (e) {
      debugPrint('⚠️ CaringStateService.completeGreeting error: $e');
      return '오류가 발생했어요.';
    }
  }

  /// 재우기
  static Future<void> sleep() async {
    final now = DateTime.now();
    await _save({
      'isSleeping': true,
      'sleepStartedAt': Timestamp.fromDate(now),
    });
  }

  /// 깨우기 (아침 인사 없이 단순 깨우기)
  static Future<void> wake() async {
    final now = DateTime.now();
    await _save({
      'isSleeping': false,
      'lastWakeAt': Timestamp.fromDate(now),
    });
  }

  // ═══════════════════════ 유틸 ═══════════════════════

  /// 오늘 날짜 키 (YYYY-MM-DD)
  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// 오늘 인사 완료 여부 판정
  static bool hasGreetedToday(CaringState state) {
    final todayKey = _dateKey(DateTime.now());
    return state.hasGreetedDate == todayKey;
  }
}

/// 돌보기 상태 값 객체
class CaringState {
  final bool isSleeping;
  final String? hasGreetedDate; // "YYYY-MM-DD" 형태
  final DateTime? sleepStartedAt;
  final DateTime? lastWakeAt;

  const CaringState({
    this.isSleeping = false,
    this.hasGreetedDate,
    this.sleepStartedAt,
    this.lastWakeAt,
  });

  factory CaringState.initial() => const CaringState();

  factory CaringState.fromMap(Map<String, dynamic> m) {
    return CaringState(
      isSleeping: m['isSleeping'] ?? false,
      hasGreetedDate: m['hasGreetedDate'],
      sleepStartedAt: (m['sleepStartedAt'] as Timestamp?)?.toDate(),
      lastWakeAt: (m['lastWakeAt'] as Timestamp?)?.toDate(),
    );
  }
}




