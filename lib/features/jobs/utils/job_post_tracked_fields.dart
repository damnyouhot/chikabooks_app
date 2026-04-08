/// AI `fieldStatus`·배너·폼 뱃지에서 동일한 키·순서를 쓰기 위한 단일 목록.
///
/// [aiStatusOrderedKeys] 순서는 `JobPostForm` 시각적 순서와 맞춘다.
class JobPostTrackedFields {
  JobPostTrackedFields._();

  /// 폼 스크롤 순서 (배너·이슈 필드 나열 기준).
  static const List<String> aiStatusOrderedKeys = [
    'title',
    'clinicName',
    'career',
    'role',
    'mainDuties',
    'education',
    'employmentType',
    'salary',
    'workHours',
    'workDays',
    'benefits',
    'description',
    'address',
    'contact',
    'subwayStationName',
    'applyMethod',
    'hospitalType',
    'chairCount',
    'staffCount',
    'specialties',
    'hasOralScanner',
    'hasCT',
    'has3DPrinter',
    'digitalEquipmentRaw',
    'requiredDocuments',
    'closingDate',
  ];

  /// `parseJobImagesToForm` 응답 맵에서 해당 키가 “값 있음”인지 (fieldStatus 보완용).
  static bool valuePresentInExtract(Map<String, dynamic> m, String field) {
    switch (field) {
      case 'mainDuties':
        final list = m['mainDutiesList'];
        if (list is List && list.isNotEmpty) return true;
        final md = m['mainDuties'];
        if (md is List && md.isNotEmpty) return true;
        if (md is String && md.trim().isNotEmpty) return true;
        return false;
      case 'salary':
        final s = m['salary'];
        if (s is String && s.trim().isNotEmpty) return true;
        final pt = m['salaryPayType'];
        if (pt is String && pt.trim().isNotEmpty) return true;
        return false;
      case 'applyMethod':
        final am = m['applyMethod'];
        return am is List && am.isNotEmpty;
      case 'chairCount':
      case 'staffCount':
        return m[field] != null;
      case 'hasOralScanner':
      case 'hasCT':
      case 'has3DPrinter':
        return m[field] != null;
      case 'closingDate':
        final cd = m['closingDate'];
        if (cd == null) return false;
        if (cd is String && cd.trim().isEmpty) return false;
        return true;
      case 'specialties':
        final sp = m['specialties'];
        return sp is List && sp.isNotEmpty;
      case 'benefits':
        final b = m['benefits'];
        return b is List && b.isNotEmpty;
      case 'requiredDocuments':
        final rd = m['requiredDocuments'];
        return rd is List && rd.isNotEmpty;
      case 'workDays':
        final wd = m['workDays'];
        if (wd is List && wd.isNotEmpty) return true;
        return false;
      default:
        final val = m[field];
        if (val == null) return false;
        if (val is String) return val.trim().isNotEmpty;
        if (val is List) return val.isNotEmpty;
        return true;
    }
  }
}
