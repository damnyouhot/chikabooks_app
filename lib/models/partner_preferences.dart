/// 파트너 선호도 설정 모델
/// Firestore users/{uid}.partnerPreferences 에 저장
class PartnerPreferences {
  final PreferenceItem priority1;
  final PreferenceItem priority2;
  final PreferenceItem priority3;

  const PartnerPreferences({
    required this.priority1,
    required this.priority2,
    required this.priority3,
  });

  /// 기본값: 편한 공감형 프리셋
  factory PartnerPreferences.defaultPreset() {
    return PartnerPreferences(
      priority1: PreferenceItem(type: PreferenceType.career, value: 'similar'),
      priority2: PreferenceItem(type: PreferenceType.tags, value: 'similar'),
      priority3: PreferenceItem(type: PreferenceType.region, value: 'any'),
    );
  }

  /// 프리셋 1: 편한 공감형
  factory PartnerPreferences.comfortPreset() {
    return PartnerPreferences(
      priority1: PreferenceItem(type: PreferenceType.career, value: 'similar'),
      priority2: PreferenceItem(type: PreferenceType.tags, value: 'similar'),
      priority3: PreferenceItem(type: PreferenceType.region, value: 'any'),
    );
  }

  /// 프리셋 2: 현실 조언형
  factory PartnerPreferences.advicePreset() {
    return PartnerPreferences(
      priority1: PreferenceItem(type: PreferenceType.career, value: 'senior'),
      priority2: PreferenceItem(type: PreferenceType.tags, value: 'similar'),
      priority3: PreferenceItem(type: PreferenceType.region, value: 'any'),
    );
  }

  /// 프리셋 3: 동네 동행형
  factory PartnerPreferences.localPreset() {
    return PartnerPreferences(
      priority1: PreferenceItem(type: PreferenceType.region, value: 'nearby'),
      priority2: PreferenceItem(type: PreferenceType.career, value: 'any'),
      priority3: PreferenceItem(type: PreferenceType.tags, value: 'any'),
    );
  }

  factory PartnerPreferences.fromMap(Map<String, dynamic> m) {
    return PartnerPreferences(
      priority1: PreferenceItem.fromMap(m['priority1'] ?? {}),
      priority2: PreferenceItem.fromMap(m['priority2'] ?? {}),
      priority3: PreferenceItem.fromMap(m['priority3'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'priority1': priority1.toMap(),
      'priority2': priority2.toMap(),
      'priority3': priority3.toMap(),
    };
  }

  /// 프리셋 이름 반환
  String get presetName {
    if (priority1.type == PreferenceType.career &&
        priority1.value == 'similar' &&
        priority2.type == PreferenceType.tags &&
        priority2.value == 'similar') {
      return '편한 공감형';
    } else if (priority1.type == PreferenceType.career &&
        priority1.value == 'senior' &&
        priority2.type == PreferenceType.tags &&
        priority2.value == 'similar') {
      return '현실 조언형';
    } else if (priority1.type == PreferenceType.region &&
        priority1.value == 'nearby') {
      return '동네 동행형';
    }
    return '맞춤 설정';
  }
}

/// 개별 선호도 항목
class PreferenceItem {
  final PreferenceType type;
  final String value;

  const PreferenceItem({
    required this.type,
    required this.value,
  });

  factory PreferenceItem.fromMap(Map<String, dynamic> m) {
    return PreferenceItem(
      type: PreferenceType.values.firstWhere(
        (e) => e.name == m['type'],
        orElse: () => PreferenceType.region,
      ),
      value: m['value'] ?? 'any',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'value': value,
    };
  }

  /// 선호도 설명 텍스트
  String get displayText {
    switch (type) {
      case PreferenceType.region:
        switch (value) {
          case 'nearby':
            return '지역: 가깝게';
          case 'far':
            return '지역: 멀게';
          default:
            return '지역: 상관없음';
        }
      case PreferenceType.career:
        switch (value) {
          case 'similar':
            return '연차: 가깝게';
          case 'senior':
            return '연차: 높은 연차 우선';
          default:
            return '연차: 상관없음';
        }
      case PreferenceType.tags:
        switch (value) {
          case 'similar':
            return '태그: 비슷하게';
          default:
            return '태그: 상관없음';
        }
    }
  }
}

/// 선호도 타입
enum PreferenceType {
  region, // 지역
  career, // 연차
  tags, // 태그(관심사/고민)
}

/// 지역 선호도 옵션
class RegionPreferenceOptions {
  static const String nearby = 'nearby'; // 가깝게
  static const String far = 'far'; // 멀게
  static const String any = 'any'; // 상관없음

  static const List<String> all = [nearby, far, any];
  
  static String getLabel(String value) {
    switch (value) {
      case nearby:
        return '가깝게';
      case far:
        return '멀게';
      default:
        return '상관없음';
    }
  }
}

/// 연차 선호도 옵션
class CareerPreferenceOptions {
  static const String similar = 'similar'; // 가깝게
  static const String senior = 'senior'; // 높은 연차 우선
  static const String any = 'any'; // 상관없음

  static const List<String> all = [similar, senior, any];
  
  static String getLabel(String value) {
    switch (value) {
      case similar:
        return '가깝게';
      case senior:
        return '높은 연차 우선';
      default:
        return '상관없음';
    }
  }
}

/// 태그 선호도 옵션
class TagsPreferenceOptions {
  static const String similar = 'similar'; // 비슷하게
  static const String any = 'any'; // 상관없음

  static const List<String> all = [similar, any];
  
  static String getLabel(String value) {
    switch (value) {
      case similar:
        return '비슷하게';
      default:
        return '상관없음';
    }
  }
}

