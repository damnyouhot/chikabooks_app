import 'package:cloud_firestore/cloud_firestore.dart';

/// ══════════════════════════════════════════════════
/// 이번 주 작은 기념 스탬프 (합산형)
/// ══════════════════════════════════════════════════
///
/// Firestore 구조:
///   partnerGroups/{groupId}/weeklyStamps/{weekKey}
///     → WeeklyStampState (주간 스탬프 상태)
///
///   partnerGroups/{groupId}/weeklyStamps/{weekKey}/daily/{dateKey}
///     → DailyStampLog (일별 참여 로그, 서버 전용 쓰기)

/// ── 주간 스탬프 상태 ──
/// 월~일 7칸 중 채워진 날 관리
class WeeklyStampState {
  final String weekKey; // "2026-W07"
  final Map<int, bool> filledDays; // {0: true, 1: false, ...} (0=월 ~ 6=일)
  final int filledCount;
  final DateTime? updatedAt;

  const WeeklyStampState({
    required this.weekKey,
    this.filledDays = const {},
    this.filledCount = 0,
    this.updatedAt,
  });

  factory WeeklyStampState.empty(String weekKey) => WeeklyStampState(
        weekKey: weekKey,
        filledDays: {for (var i = 0; i < 7; i++) i: false},
        filledCount: 0,
      );

  factory WeeklyStampState.fromMap(Map<String, dynamic> m) {
    final raw = m['filledDays'] as Map<String, dynamic>? ?? {};
    final days = <int, bool>{};
    for (var i = 0; i < 7; i++) {
      days[i] = raw['$i'] == true;
    }
    return WeeklyStampState(
      weekKey: m['weekKey'] ?? '',
      filledDays: days,
      filledCount: m['filledCount'] ?? days.values.where((v) => v).length,
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'weekKey': weekKey,
        'filledDays': {for (final e in filledDays.entries) '${e.key}': e.value},
        'filledCount': filledCount,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// 특정 요일이 채워졌는지 (0=월 ~ 6=일)
  bool isFilled(int dayIndex) => filledDays[dayIndex] ?? false;
}

/// ── 일별 참여 로그 ──
/// Cloud Function이 원자적으로 기록
class DailyStampLog {
  final String dateKey; // "2026-02-13"
  final int dayOfWeek; // 0=월 ~ 6=일

  // 조건 A~D 참여자 uid 목록
  final List<String> pollVoters; // A. 공감 투표
  final List<String> sentenceReactors; // B. 한 문장 리액션
  final List<String> goalCheckers; // C. 목표 체크
  final List<String> sentenceWriters; // D. 한 문장 작성

  final bool stampFilled; // 이 날 스탬프 채워졌는지
  final DateTime? updatedAt;

  const DailyStampLog({
    required this.dateKey,
    required this.dayOfWeek,
    this.pollVoters = const [],
    this.sentenceReactors = const [],
    this.goalCheckers = const [],
    this.sentenceWriters = const [],
    this.stampFilled = false,
    this.updatedAt,
  });

  factory DailyStampLog.fromMap(Map<String, dynamic> m) {
    return DailyStampLog(
      dateKey: m['dateKey'] ?? '',
      dayOfWeek: m['dayOfWeek'] ?? 0,
      pollVoters: _toStringList(m['pollVoters']),
      sentenceReactors: _toStringList(m['sentenceReactors']),
      goalCheckers: _toStringList(m['goalCheckers']),
      sentenceWriters: _toStringList(m['sentenceWriters']),
      stampFilled: m['stampFilled'] ?? false,
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'dateKey': dateKey,
        'dayOfWeek': dayOfWeek,
        'pollVoters': pollVoters,
        'sentenceReactors': sentenceReactors,
        'goalCheckers': goalCheckers,
        'sentenceWriters': sentenceWriters,
        'stampFilled': stampFilled,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// 참여한 고유 활동 종류 수 (최소 2개 이상이면 스탬프 가능)
  int get uniqueActivityCount {
    int count = 0;
    if (pollVoters.isNotEmpty) count++;
    if (sentenceReactors.isNotEmpty) count++;
    if (goalCheckers.isNotEmpty) count++;
    if (sentenceWriters.isNotEmpty) count++;
    return count;
  }

  /// 스탬프 조건 충족 여부: (A or B) + (C or D)
  bool get meetsStampCondition {
    final hasAorB = pollVoters.isNotEmpty || sentenceReactors.isNotEmpty;
    final hasCorD = goalCheckers.isNotEmpty || sentenceWriters.isNotEmpty;
    return hasAorB && hasCorD;
  }

  static List<String> _toStringList(dynamic raw) {
    if (raw is List) return raw.cast<String>();
    return [];
  }
}





