/// 관리자 대시보드에서 사용하는 데이터 모델 모음
library;

// ─── KPI 카드 ───────────────────────────────────────────────
class DashboardKpi {
  final String label;
  final String value;
  final String? sublabel; // 예: "최근 7일"

  const DashboardKpi({
    required this.label,
    required this.value,
    this.sublabel,
  });
}

// ─── 퍼널 단계 ───────────────────────────────────────────────
class FunnelStep {
  final String label;
  final int count;
  final double? conversionRate; // 이전 단계 대비 전환율 (0.0~1.0)

  const FunnelStep({
    required this.label,
    required this.count,
    this.conversionRate,
  });
}

// ─── 기능 반응 항목 ──────────────────────────────────────────
class FeatureReactionItem {
  final String eventType; // activityLogs.type
  final String label;     // 화면에 표시할 한국어 이름
  final int clickCount;
  final int userCount;

  const FeatureReactionItem({
    required this.eventType,
    required this.label,
    required this.clickCount,
    required this.userCount,
  });

  /// activityLogs.type → 한국어 라벨 매핑
  static String labelFor(String type) {
    const map = {
      'tapCharacter': '캐릭터 클릭',
      'tapEmotionStart': '감정기록 시작',
      'tapEmotionSave': '감정기록 저장',
      'viewJobDetail': '구직 공고 상세',
      'tapJobSave': '공고 저장',
      'tapJobApply': '공고 지원',
      'tapCareerEdit': '커리어 카드 수정',
      'viewHome': '홈 탭 이동',
      'viewBond': '결속 탭 이동',
      'viewGrowth': '성장 탭 이동',
      'viewCareer': '커리어 탭 이동',
      'loginSuccess': '로그인 성공',
    };
    return map[type] ?? type;
  }
}

// ─── 오류 항목 ───────────────────────────────────────────────
class AppErrorItem {
  final String id;
  final DateTime timestamp;
  final String errorMessage;
  final String? page;
  final String? feature;
  final String? appVersion;
  final String? uid;
  final bool isFatal;

  const AppErrorItem({
    required this.id,
    required this.timestamp,
    required this.errorMessage,
    this.page,
    this.feature,
    this.appVersion,
    this.uid,
    this.isFatal = false,
  });

  factory AppErrorItem.fromMap(String id, Map<String, dynamic> m) {
    return AppErrorItem(
      id: id,
      timestamp: (m['timestamp'] as dynamic)?.toDate() ?? DateTime.now(),
      errorMessage: m['errorMessage'] as String? ?? '(메시지 없음)',
      page: m['page'] as String?,
      feature: m['feature'] as String?,
      appVersion: m['appVersion'] as String?,
      uid: m['uid'] as String?,
      isFatal: m['isFatal'] as bool? ?? false,
    );
  }
}

// ─── 연차 분포 항목 ──────────────────────────────────────────
class CareerGroupCount {
  final String group; // student, 1y, 2_3y, 4_7y, 8y_plus
  final int count;

  const CareerGroupCount({required this.group, required this.count});

  String get label {
    const map = {
      'student': '학생',
      '1y': '1년차',
      '2_3y': '2~3년차',
      '4_7y': '4~7년차',
      '8y_plus': '8년차+',
    };
    return map[group] ?? group;
  }
}

