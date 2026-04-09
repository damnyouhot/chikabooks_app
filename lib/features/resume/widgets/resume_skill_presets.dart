/// 이력서 임상/소프트 스킬 프리셋 — [SectionSkills]·미리보기에서 동일하게 사용
class ResumeSkillPresets {
  ResumeSkillPresets._();

  static const clinical = <String>[
    '스케일링',
    '치주 관리',
    '불소도포',
    '방사선 촬영',
    '인상 채득',
    '임시치아 제작',
    '교정 와이어 교체',
    '임플란트 보조',
    '근관치료 보조',
    '소아 진료 보조',
    '레진/실란트',
    '치아미백',
    '구강스캐너',
    '구내,구외 포토',
  ];

  static const soft = <String>[
    '환자 상담',
    '보험청구',
    '차트 관리',
    '감염 관리',
    '재고 관리',
    '팀 리더십',
    '신규 직원 교육',
    '고객 CS',
  ];

  /// 프리셋 id는 보통 프리셋 문자열과 동일, 커스텀은 `custom_` 접두사
  static bool isClinicalSkillId(String id, String name) {
    if (id.startsWith('custom_')) return false;
    return clinical.contains(id) || clinical.contains(name);
  }

  static bool isSoftSkillId(String id, String name) {
    if (id.startsWith('custom_')) return false;
    return soft.contains(id) || soft.contains(name);
  }
}
