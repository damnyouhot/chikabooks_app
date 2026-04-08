/// 공고 폼·AI 추출·드래프트 병합에서 공통으로 쓰는 필드 정규화.
class JobPostFieldSync {
  JobPostFieldSync._();

  /// [JobPostForm] 학력 드롭다운과 동일.
  static const educationDropdownOptions = [
    '무관',
    '고등학교 졸업 이상',
    '전문대 졸업 이상',
  ];

  /// 급여 지급 형태 (`salaryPayType`).
  static const salaryPayTypeOptions = ['협의', '시', '월', '연'];

  /// [JobPostForm] 경력 드롭다운과 동일한 허용 값.
  static const careerDropdownOptions = [
    '신입',
    '경력 무관',
    '1년 이상',
    '2년 이상',
    '3년 이상',
    '5년 이상',
  ];

  static const employmentTypeOptions = [
    '정규직',
    '계약직',
    '파트타임',
    '인턴',
  ];

  /// 자유 텍스트 → 드롭다운 항목 (없으면 null).
  static String? matchCareerToDropdown(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return null;
    if (careerDropdownOptions.contains(t)) return t;
    if (t.contains('무관')) return '경력 무관';
    if (t.contains('신입')) return '신입';
    final m = RegExp(r'(\d+)\s*년').firstMatch(t);
    if (m != null) {
      final y = int.tryParse(m.group(1)!) ?? 0;
      if (y >= 5) return '5년 이상';
      if (y >= 3) return '3년 이상';
      if (y >= 2) return '2년 이상';
      if (y >= 1) return '1년 이상';
    }
    return null;
  }

  /// [primary]가 허용 목록이면 사용, 아니면 [fallback] 시도, 둘 다 아니면 빈 문자열.
  static String pickCareerForStorage(String? primaryRaw, String? fallbackRaw) {
    final a = matchCareerToDropdown(primaryRaw);
    if (a != null && a.isNotEmpty) return a;
    final b = matchCareerToDropdown(fallbackRaw);
    return b ?? '';
  }

  static String pickEmploymentType(String? primaryRaw, String? fallbackRaw) {
    final p = primaryRaw?.trim() ?? '';
    if (p.isNotEmpty && employmentTypeOptions.contains(p)) return p;
    final f = fallbackRaw?.trim() ?? '';
    if (f.isNotEmpty && employmentTypeOptions.contains(f)) return f;
    return '';
  }

  /// 자유 텍스트 → 학력 드롭다운 (없으면 null).
  static String? matchEducationToDropdown(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return null;
    if (educationDropdownOptions.contains(t)) return t;
    if (t.contains('전문대') || t.contains('전문학사')) {
      return '전문대 졸업 이상';
    }
    if (t.contains('고등')) return '고등학교 졸업 이상';
    if (t.contains('무관')) return '무관';
    return null;
  }

  /// [primary]·[fallback] 중 허용값으로 매핑 가능한 첫 값, 없으면 ''.
  static String pickEducationForStorage(String? primaryRaw, String? fallbackRaw) {
    final a = matchEducationToDropdown(primaryRaw);
    if (a != null && a.isNotEmpty) return a;
    final b = matchEducationToDropdown(fallbackRaw);
    return b ?? '';
  }

  /// `fieldStatus`에서 값이 채워진 필드는 `confirmed`로 보정 (뱃지·원문 불일치 완화).
  /// [confirmWhenTrue]의 키가 `JobPostTrackedFields.aiStatusOrderedKeys`와 맞출 것.
  static Map<String, String>? patchFieldStatusForFilledValues(
    Map<String, String>? fieldStatus,
    Map<String, bool> confirmWhenTrue,
  ) {
    if (fieldStatus == null || fieldStatus.isEmpty) return fieldStatus;
    final m = Map<String, String>.from(fieldStatus);
    for (final e in confirmWhenTrue.entries) {
      if (e.value) m[e.key] = 'confirmed';
    }
    return m;
  }

  /// AI/서버 맵에서 채용직 후보 추출. `hireRoles` 배열 우선, 없으면 `role` 한 줄을 콤마 분리.
  static List<String> hireRolesFromExtract(Map<String, dynamic> res) {
    final out = <String>[];
    final hr = res['hireRoles'];
    if (hr is List && hr.isNotEmpty) {
      for (final e in hr) {
        final t = e.toString().trim();
        if (t.isEmpty) continue;
        out.add(_mapHireRoleToken(t));
      }
    } else {
      final role = (res['role'] as String? ?? '').trim();
      if (role.isNotEmpty) {
        for (final part in role.split(RegExp(r'\s*,\s*'))) {
          final t = part.trim();
          if (t.isEmpty) continue;
          out.add(_mapHireRoleToken(t));
        }
      }
    }
    return _dedupePreserveOrder(out);
  }

  static String _mapHireRoleToken(String t) {
    if (t == '원장') return '기타';
    return t;
  }

  static List<String> _dedupePreserveOrder(List<String> input) {
    final seen = <String>{};
    final out = <String>[];
    for (final e in input) {
      final s = e.trim();
      if (s.isEmpty || seen.contains(s)) continue;
      seen.add(s);
      out.add(s);
    }
    return out;
  }

  /// 미리보기/프리뷰용: [hireRoles] 우선, 비어 있으면 [role] 한 줄.
  static String hireRolesDisplayLine({
    required List<String> hireRoles,
    required String role,
  }) {
    if (hireRoles.isNotEmpty) return hireRoles.join(', ');
    return role.trim();
  }

  // ── 복리후생 정규화 ──────────────────────────────────────

  static const commonBenefits = [
    '4대보험', '퇴직금', '연차', '식비지원', '주차지원', '명절상여',
  ];

  static const _benefitAliases = <String, String>{
    '식대': '식비지원', '식비': '식비지원', '식대지원': '식비지원',
    '주차': '주차지원', '주차비': '주차지원',
    '명절': '명절상여', '상여': '명절상여', '명절상여금': '명절상여',
    '연차휴가': '연차', '유급휴가': '연차',
  };

  /// AI 추출·드래프트 복원 등에서 공통 항목과 매칭 + 부분매칭 + 에일리어스.
  static List<String> normalizeBenefits(List<String> raw) {
    final result = <String>[];
    for (final b in raw) {
      final t = b.trim();
      if (t.isEmpty) continue;
      if (commonBenefits.contains(t)) {
        if (!result.contains(t)) result.add(t);
        continue;
      }
      // 에일리어스 매핑
      final alias = _benefitAliases[t];
      if (alias != null) {
        if (!result.contains(alias)) result.add(alias);
        continue;
      }
      // 공통 항목 부분 매칭
      bool matched = false;
      for (final c in commonBenefits) {
        if (t.contains(c) || c.contains(t)) {
          if (!result.contains(c)) result.add(c);
          matched = true;
          break;
        }
      }
      // 에일리어스 키 부분 매칭
      if (!matched) {
        for (final e in _benefitAliases.entries) {
          if (t.contains(e.key)) {
            if (!result.contains(e.value)) result.add(e.value);
            matched = true;
            break;
          }
        }
      }
      if (!matched && !result.contains(t)) result.add(t);
    }
    return result;
  }

  // ── 제출서류 정규화 ──────────────────────────────────────

  static const commonDocuments = [
    '이력서', '자기소개서', '경력증명서', '자격증 사본', '졸업증명서', '포트폴리오',
  ];

  static const _docAliases = <String, String>{
    '이력서류': '이력서', '경력기술서': '경력증명서',
    '면허증': '자격증 사본', '자격증': '자격증 사본',
    '졸업장': '졸업증명서',
  };

  /// AI 추출 제출서류 정규화 (복리후생과 동일 패턴).
  static List<String> normalizeDocuments(List<String> raw) {
    final result = <String>[];
    for (final b in raw) {
      final t = b.trim();
      if (t.isEmpty) continue;
      if (commonDocuments.contains(t)) {
        if (!result.contains(t)) result.add(t);
        continue;
      }
      final alias = _docAliases[t];
      if (alias != null) {
        if (!result.contains(alias)) result.add(alias);
        continue;
      }
      bool matched = false;
      for (final c in commonDocuments) {
        if (t.contains(c) || c.contains(t)) {
          if (!result.contains(c)) result.add(c);
          matched = true;
          break;
        }
      }
      if (!matched) {
        for (final e in _docAliases.entries) {
          if (t.contains(e.key)) {
            if (!result.contains(e.value)) result.add(e.value);
            matched = true;
            break;
          }
        }
      }
      if (!matched && !result.contains(t)) result.add(t);
    }
    return result;
  }
}
