/// 공고 데이터 기반 태그 자동 생성
///
/// 앱/웹 공통 클라이언트 로직. 저장 전에 호출해서 [tags] 배열을 채운다.
/// 수동 태그와 병합 가능하도록 Set 기반으로 처리.
class TagGenerator {
  TagGenerator._();

  /// 자동 생성 태그 목록 반환 (중복 제거, 순서 보장)
  static List<String> generate({
    List<String> benefits = const [],
    List<String> workDays = const [],
    bool weekendWork = false,
    bool nightShift = false,
    String career = '',
    List<String> applyMethod = const [],
    String? subwayStationName,
    int? walkingMinutes,
    List<String> manualTags = const [],
  }) {
    final tags = <String>{};

    // benefits → 태그 전파
    for (final b in benefits) {
      if (_benefitToTag.containsKey(b)) {
        tags.add(_benefitToTag[b]!);
      }
    }

    // 주5일 판정: 평일 5일 + 주말 없음
    if (_isWeekdayFull(workDays) && !weekendWork) {
      tags.add('주5일');
    }

    // 주4일 판정
    if (workDays.length == 4 && !weekendWork) {
      tags.add('주4일');
    }

    // 야간 없음
    if (!nightShift) {
      tags.add('야간없음');
    }

    // 역세권 (도보 10분 이내)
    if (subwayStationName != null &&
        subwayStationName.isNotEmpty &&
        walkingMinutes != null &&
        walkingMinutes <= 10) {
      tags.add('역세권');
    }

    // 신입가능
    final c = career.trim().toLowerCase();
    if (c.contains('신입') || c.contains('무관')) {
      tags.add('신입가능');
    }

    // 즉시지원
    if (applyMethod.contains('online')) {
      tags.add('즉시지원');
    }

    // 수동 태그 병합 (자동 태그 뒤에 추가)
    tags.addAll(manualTags);

    return tags.toList();
  }

  /// benefits 중 태그로 전파할 항목 매핑
  static const _benefitToTag = {
    '4대보험': '4대보험',
    '기숙사': '기숙사',
    '퇴직금': '퇴직금',
    '인센티브': '인센티브',
    '식비지원': '식비지원',
    '교육지원': '교육지원',
    '주차지원': '주차지원',
  };

  static bool _isWeekdayFull(List<String> days) {
    const weekdays = {'mon', 'tue', 'wed', 'thu', 'fri'};
    final daySet = days.toSet();
    return weekdays.every(daySet.contains);
  }
}
