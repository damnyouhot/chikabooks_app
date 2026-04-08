import '../../../models/job.dart';
import 'job_post_tracked_fields.dart';

/// [parseJobImagesToForm] 응답을 폼·미리보기에 맞게 정리한다.
///
/// 처리 내용:
/// - mainDuties 배열 → mainDutiesRaw / mainDutiesList 분리
/// - workDays 한글 → 영문 코드 변환 (workDaysToCodes)
/// - benefits 오분류 항목 제거 (역명, 시설 키워드)
/// - description 줄 중 복지성 한 줄 → benefits로 이동
/// - subwayStationName이 빈 경우 description에서 추출
/// - recruitmentStart / closingDate 문자열 → DateTime 파싱
/// - fieldStatus 보완: 값이 없는 주요 필드는 'missing'으로 강제 설정
class JobAiExtractNormalizer {
  JobAiExtractNormalizer._();

  static const _korDayToKey = {
    '월': 'mon', '화': 'tue', '수': 'wed',
    '목': 'thu', '금': 'fri', '토': 'sat', '일': 'sun',
    '월요일': 'mon', '화요일': 'tue', '수요일': 'wed',
    '목요일': 'thu', '금요일': 'fri', '토요일': 'sat', '일요일': 'sun',
  };
  static const _validDayCodes = {'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'};

  /// Cloud Function 원본 맵을 보정한 복사본 반환.
  static Map<String, dynamic> normalize(Map<String, dynamic> raw) {
    final m = Map<String, dynamic>.from(raw);

    _processMainDuties(m);
    _processSpecialties(m);
    _processDigitalEquipment(m);
    _cleanBenefitsList(m);
    _splitDescriptionLinesIntoBenefits(m);
    _fillSubwayFromDescriptionIfEmpty(m);
    _parseRecruitmentDates(m);
    _fillFieldStatus(m);

    return m;
  }

  // ── workDays 변환 ─────────────────────────────────────────────

  static List<String> workDaysToCodes(List<dynamic>? raw) {
    if (raw == null || raw.isEmpty) return [];
    final keys = <String>[];
    for (final e in raw) {
      final t = e.toString().trim();
      if (t.isEmpty) continue;
      if (_validDayCodes.contains(t)) {
        if (!keys.contains(t)) keys.add(t);
        continue;
      }
      final k = _korDayToKey[t];
      if (k != null && !keys.contains(k)) keys.add(k);
    }
    return keys;
  }

  // ── hospitalType 정규화 ───────────────────────────────────────

  static String? hospitalTypeToKey(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return null;
    if (Job.hospitalTypeLabels.containsKey(t)) return t;
    for (final e in Job.hospitalTypeLabels.entries) {
      if (e.value == t) return e.key;
    }
    if (t.contains('네트워크')) return 'network';
    if (t.contains('종합') || t.contains('대학')) return 'general';
    if (t.contains('병원')) return 'hospital';
    return 'clinic';
  }

  // ── mainDuties 처리 ───────────────────────────────────────────

  static void _processMainDuties(Map<String, dynamic> m) {
    final rawList = m['mainDuties'];
    final duties = <String>[];

    if (rawList is List) {
      for (final e in rawList) {
        final t = e.toString().trim();
        if (t.isNotEmpty) duties.add(t);
      }
    } else if (rawList is String && rawList.trim().isNotEmpty) {
      // 줄글로 온 경우 분리
      duties.addAll(
        rawList.split(RegExp(r'[\n\r•\-\*]+'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty),
      );
    }

    if (duties.isNotEmpty) {
      m['mainDutiesList'] = duties;
      m['mainDutiesRaw'] = duties.join('\n');
    } else {
      m['mainDutiesList'] = <String>[];
      m['mainDutiesRaw'] = null;
    }
  }

  // ── specialties 정규화 ────────────────────────────────────────

  static const _validSpecialties = [
    '일반진료', '교정', '임플란트', '소아치과', '치주', '보존', '기타',
  ];

  static void _processSpecialties(Map<String, dynamic> m) {
    final raw = m['specialties'];
    final result = <String>[];

    if (raw is List) {
      for (final e in raw) {
        final t = e.toString().trim();
        if (t.isEmpty) continue;
        if (_validSpecialties.contains(t)) {
          if (!result.contains(t)) result.add(t);
          continue;
        }
        if (t.contains('교정') || t.contains('치열')) {
          if (!result.contains('교정')) result.add('교정');
        } else if (t.contains('임플란트') || t.contains('임플')) {
          if (!result.contains('임플란트')) result.add('임플란트');
        } else if (t.contains('소아') || t.contains('어린이')) {
          if (!result.contains('소아치과')) result.add('소아치과');
        } else if (t.contains('치주') || t.contains('잇몸')) {
          if (!result.contains('치주')) result.add('치주');
        } else if (t.contains('보존') || t.contains('신경')) {
          if (!result.contains('보존')) result.add('보존');
        } else if (t.contains('일반') || t.contains('보철') || t.contains('충치')) {
          if (!result.contains('일반진료')) result.add('일반진료');
        } else {
          if (!result.contains('기타')) result.add('기타');
        }
      }
    }

    m['specialties'] = result;
  }

  // ── 디지털 장비 정규화 ────────────────────────────────────────

  static bool? _pickBool(dynamic v) {
    if (v is bool) return v;
    if (v == null) return null;
    final s = v.toString().toLowerCase();
    if (s == 'true' || s.contains('있') || s.contains('보유')) return true;
    if (s == 'false' || s.contains('없')) return false;
    return null;
  }

  static void _processDigitalEquipment(Map<String, dynamic> m) {
    m['hasOralScanner'] = _pickBool(m['hasOralScanner']);
    m['hasCT'] = _pickBool(m['hasCT']);
    m['has3DPrinter'] = _pickBool(m['has3DPrinter']);

    if (m['digitalEquipmentRaw'] == null || (m['digitalEquipmentRaw'] as String? ?? '').isEmpty) {
      final desc = (m['description'] as String?) ?? '';
      final equipMatch = RegExp(
        r'(iTero|Trios|구강\s*스캐너|3D\s*프린터|CT|CBCT|디지털|[Ii][Oo][Ss])',
        caseSensitive: false,
      ).firstMatch(desc);
      if (equipMatch != null) {
        m['digitalEquipmentRaw'] = equipMatch.group(0);
      }
    }
  }

  // ── benefits 정리 ─────────────────────────────────────────────

  static void _cleanBenefitsList(Map<String, dynamic> m) {
    final list = List<String>.from(
      (m['benefits'] as List?)?.map((e) => e.toString().trim()).where((s) => s.isNotEmpty) ?? [],
    );
    list.removeWhere((b) => _isMisclassifiedBenefit(b));
    m['benefits'] = _dedupeStrings(list);
  }

  static bool _isMisclassifiedBenefit(String b) {
    if (b.length > 140) return false;
    if (RegExp(r'역\s*\d|\d+\s*번\s*출구|도보\s*\d+\s*(분|초)|초\s*거리').hasMatch(b)) {
      return true;
    }
    return _facilityKeywords.any((k) => b.contains(k));
  }

  // ── description 줄 → benefits 분리 ───────────────────────────

  static void _splitDescriptionLinesIntoBenefits(Map<String, dynamic> m) {
    var desc = (m['description'] as String?)?.trim() ?? '';
    if (desc.isEmpty) return;

    final benefits = List<String>.from(
      (m['benefits'] as List?)?.map((e) => e.toString().trim()).where((s) => s.isNotEmpty) ?? [],
    );

    final lines = desc.split(RegExp(r'[\n\r]+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (lines.length <= 1) return;

    final kept = <String>[];
    for (final line in lines) {
      if (_isLikelyStandaloneBenefitLine(line)) {
        final short = _shortenLabel(line);
        if (short.isNotEmpty && !_listHasSimilar(benefits, short)) {
          benefits.add(short);
        }
      } else {
        kept.add(line);
      }
    }

    if (kept.isEmpty) return;
    m['benefits'] = _dedupeStrings(benefits);
    m['description'] = kept.join('\n\n');
  }

  // ── subwayStationName 보완 ────────────────────────────────────

  static void _fillSubwayFromDescriptionIfEmpty(Map<String, dynamic> m) {
    final existing = (m['subwayStationName'] as String?)?.trim() ?? '';
    if (existing.isNotEmpty) return;
    final desc = (m['description'] as String?) ?? '';
    final match = RegExp(r'([가-힣]{2,10}역)').firstMatch(desc);
    if (match != null) {
      m['subwayStationName'] = match.group(1);
    }
  }

  // ── 날짜 파싱 (recruitmentStart / closingDate) ────────────────

  static void _parseRecruitmentDates(Map<String, dynamic> m) {
    for (final key in ['recruitmentStart', 'closingDate']) {
      final raw = m[key];
      if (raw is String && raw.isNotEmpty) {
        // YYYY-MM-DD 또는 YYYY.MM.DD 형태 파싱
        final normalized = raw.replaceAll(RegExp(r'[./년월일\s]'), '-').replaceAll(RegExp(r'-+'), '-').trim();
        try {
          DateTime.parse(normalized); // 유효성 검사
          m[key] = normalized;
        } catch (_) {
          m[key] = null;
        }
      }
    }
  }

  // ── fieldStatus 보완 ──────────────────────────────────────────

  static void _fillFieldStatus(Map<String, dynamic> m) {
    final status = Map<String, String>.from(
      (m['fieldStatus'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {},
    );

    for (final field in JobPostTrackedFields.aiStatusOrderedKeys) {
      if (status.containsKey(field)) continue;

      if (JobPostTrackedFields.valuePresentInExtract(m, field)) {
        status[field] = 'confirmed';
      } else {
        status[field] = 'missing';
      }
    }

    m['fieldStatus'] = status;
  }

  // ── helpers ───────────────────────────────────────────────────

  static bool _isLikelyStandaloneBenefitLine(String t) {
    if (t.length > 90) return false;
    if (RegExp(r'역\s*\d|\d+\s*번\s*출구|도보\s*\d').hasMatch(t)) return false;
    if (_facilityKeywords.any((k) => t.contains(k))) return false;
    if (_benefitKeywords.any((k) => t.contains(k))) return true;
    return RegExp(r'(수당|상여|인센티브|휴가|보험|퇴직|연차|식대|식비|주차|교육|야근|보너스)').hasMatch(t);
  }

  static final _benefitKeywords = [
    '4대보험', '퇴직금', '연차', '식대', '식비', '주차', '야근', '수당', '성과급',
    '명절', '상여', '교육', '휴가', '인센티브', '복지', '카페', '식사', '호텔',
  ];

  static final _facilityKeywords = [
    '에어석션', '석션', '스툴', '체어', '장비', '유니트', 'CT',
  ];

  static String _shortenLabel(String t) {
    var s = t.replaceFirst(RegExp(r'^[•\-\*]\s*'), '').trim();
    if (s.length > 80) s = '${s.substring(0, 77)}…';
    return s;
  }

  static bool _listHasSimilar(List<String> list, String candidate) {
    for (final b in list) {
      if (b == candidate || b.contains(candidate) || candidate.contains(b)) return true;
    }
    return false;
  }

  static List<String> _dedupeStrings(List<String> input) {
    final out = <String>[];
    for (final s in input) {
      final t = s.trim();
      if (t.isEmpty) continue;
      if (!out.contains(t)) out.add(t);
    }
    return out;
  }
}
