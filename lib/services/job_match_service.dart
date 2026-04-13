import '../models/job.dart';

/// 커리어 프로파일 ↔ 공고 매칭 점수 계산 유틸
///
/// - [computeScore]: 0~100 점수 반환 (순수 함수, Firestore 직접 의존 없음)
/// - [buildCareerSummary]: 검색 바 2행에 표시할 요약 문자열 생성
class JobMatchService {
  // ────────────────────────────────────────────────────────────────
  // 매칭 점수 계산 (최대 100점)
  // ────────────────────────────────────────────────────────────────

  /// 커리어 프로파일과 공고 간 매칭 점수 계산 (0~100)
  ///
  /// [job]              대상 공고
  /// [profile]          Firestore careerProfile Map (null이면 0 반환)
  /// [totalCareerMonths] 총 경력 개월수 (profile에서 미리 계산해서 전달)
  static int computeScore({
    required Job job,
    required Map<String, dynamic>? profile,
    int totalCareerMonths = 0,
  }) {
    if (profile == null) return 0;

    int score = 0;

    // ① 직종 매칭 (30점)
    //    identity.specialtyTags와 job.type 키워드 교차 검사
    final identity =
        (profile['identity'] as Map?)?.cast<String, dynamic>() ?? {};
    final specialtyTags =
        List<String>.from(identity['specialtyTags'] as List? ?? []);
    if (specialtyTags.isNotEmpty) {
      final jobWords = job.type.split(RegExp(r'[\s/·]'));
      final matched = specialtyTags.any(
        (tag) => jobWords.any(
          (w) => w.isNotEmpty && (tag.contains(w) || w.contains(tag)),
        ),
      );
      if (matched) score += 30;
    }

    // ② 경력 매칭 (25점)
    final jobCareer = job.career;
    if (jobCareer.contains('무관')) {
      score += 25; // 경력 무관 공고
    } else if (jobCareer.contains('신입') && totalCareerMonths <= 6) {
      score += 25; // 신입 공고 + 사용자 경력 ≤ 6개월
    } else {
      final reqMonths = _parseRequiredMonths(jobCareer);
      if (totalCareerMonths >= reqMonths) {
        score += 25; // 경력 충분
      } else if (reqMonths > 0 && totalCareerMonths >= reqMonths ~/ 2) {
        score += 10; // 경력 절반 이상
      }
    }

    // ③ 역세권 보너스 (10점)
    if (job.isNearStation) score += 10;

    // ④ 급여 수준 (20점)
    if (job.salaryRange.isNotEmpty) {
      final min = job.salaryRange[0];
      if (min >= 3200) {
        score += 20;
      } else if (min >= 2800) {
        score += 14;
      } else if (min >= 2400) {
        score += 7;
      }
    }

    // ⑤ 스킬 매칭 (10점, 기존 15→10으로 축소)
    final skills =
        (profile['skills'] as Map?)?.cast<String, dynamic>() ?? {};
    final enabledLabels = skills.entries
        .where((e) => (e.value as Map?)?['enabled'] == true)
        .map((e) => _skillLabel(e.key))
        .where((label) => label.isNotEmpty)
        .toList();
    if (enabledLabels.isNotEmpty) {
      final hits = job.benefits
          .where(
            (b) => enabledLabels.any(
              (label) => b.contains(label) || label.contains(b),
            ),
          )
          .length;
      score += (hits * 5).clamp(0, 10);
    }

    // ⑥ 태그 매칭 보너스 (5점, 신규)
    if (job.tags.isNotEmpty && enabledLabels.isNotEmpty) {
      final tagHits = job.tags
          .where(
            (t) => enabledLabels.any(
              (label) => t.contains(label) || label.contains(t),
            ),
          )
          .length;
      score += (tagHits * 3).clamp(0, 5);
    }

    // ⑦ 광고 레벨 가중치 (프리미엄 +5, 추천 +3)
    if (job.jobLevel == 1) {
      score += 5;
    } else if (job.jobLevel == 2) {
      score += 3;
    }

    return score.clamp(0, 100);
  }

  // ────────────────────────────────────────────────────────────────
  // 커리어 요약 문자열 생성
  // ────────────────────────────────────────────────────────────────

  /// 검색 바 2행에 표시할 커리어 요약 문자열
  ///
  /// 예: "치위생사 · 경력 3년", "치위생사 · 신입", "경력 2년 6개월"
  static String buildCareerSummary({
    required Map<String, dynamic>? profile,
    required int totalCareerMonths,
  }) {
    if (profile == null) return '';

    final identity =
        (profile['identity'] as Map?)?.cast<String, dynamic>() ?? {};
    if (identity.isEmpty) return '';

    // 직종 (전문 분야 태그의 첫 번째)
    final tags =
        List<String>.from(identity['specialtyTags'] as List? ?? []);
    final position = tags.isNotEmpty ? tags.first : '';

    // 경력 기간 표기
    final String experience;
    if (totalCareerMonths <= 0) {
      final status = identity['status'] as String? ?? '';
      experience = (status == 'unemployed') ? '구직 중' : '신입';
    } else if (totalCareerMonths < 12) {
      experience = '경력 $totalCareerMonths개월';
    } else {
      final years = totalCareerMonths ~/ 12;
      final months = totalCareerMonths % 12;
      experience = months == 0 ? '경력 $years년' : '경력 $years년 $months개월';
    }

    return position.isEmpty ? experience : '$position · $experience';
  }

  // ────────────────────────────────────────────────────────────────
  // 총 경력 개월수 (커리어 탭 상단 카드와 동일 규칙)
  // ────────────────────────────────────────────────────────────────

  /// [CareerTab] 상단 카드와 동일: override면 그 값, 아니면 치과 히스토리 합 [networkSumMonths].
  static int totalCareerMonthsForCard({
    required Map<String, dynamic>? profile,
    required int networkSumMonths,
  }) {
    if (profile == null) return networkSumMonths;
    final identity =
        (profile['identity'] as Map?)?.cast<String, dynamic>() ?? {};
    if (identity['useTotalCareerMonthsOverride'] == true) {
      return (identity['totalCareerMonthsOverride'] as int?) ?? 0;
    }
    return networkSumMonths;
  }

  // ────────────────────────────────────────────────────────────────
  // Private 헬퍼
  // ────────────────────────────────────────────────────────────────

  static int _parseRequiredMonths(String career) {
    // "1년 이상" → 12, "2년 이상" → 24, "6개월 이상" → 6
    final yearMatch = RegExp(r'(\d+)년').firstMatch(career);
    if (yearMatch != null) return int.parse(yearMatch.group(1)!) * 12;
    final monthMatch = RegExp(r'(\d+)개월').firstMatch(career);
    if (monthMatch != null) return int.parse(monthMatch.group(1)!);
    return 12; // 기본값: 1년
  }

  static String _skillLabel(String id) {
    const labelMap = {
      'scaling': '스케일링',
      'prostho': '보철',
      'ortho': '교정',
      'consult': '상담',
      'insurance': '보험청구',
      'implant': '임플란트',
      'pediatric': '소아',
      'sterile': '멸균',
      'reception': '데스크',
      'xray': 'X-ray',
    };
    return labelMap[id] ?? '';
  }
}
