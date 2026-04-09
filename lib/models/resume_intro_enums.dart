/// 이력서 자기소개 추천·톤에 사용 — Firestore에는 문자열로 저장
enum ExperienceLevel {
  /// 사용자 미선택·경력 추정 불가 시
  any,
  junior,
  mid,
  senior;

  static ExperienceLevel fromStorage(String? s) {
    switch (s) {
      case 'junior':
        return ExperienceLevel.junior;
      case 'mid':
        return ExperienceLevel.mid;
      case 'senior':
        return ExperienceLevel.senior;
      default:
        return ExperienceLevel.any;
    }
  }

  String toStorage() => name;
}

/// 구직 목표 축 — 템플릿·감점 매칭에 사용
enum JobGoal {
  general,
  orthodontics,
  surgery,
  counseling,
  manager,
  reemployment;

  static JobGoal fromStorage(String? s) {
    switch (s) {
      case 'orthodontics':
        return JobGoal.orthodontics;
      case 'surgery':
        return JobGoal.surgery;
      case 'counseling':
        return JobGoal.counseling;
      case 'manager':
        return JobGoal.manager;
      case 'reemployment':
        return JobGoal.reemployment;
      default:
        return JobGoal.general;
    }
  }

  String toStorage() => name;
}
