import '../../../models/resume_intro_enums.dart';

/// 자기소개 템플릿 — 문단 분리 + 태그로 추천·조립
class IntroTemplate {
  const IntroTemplate({
    required this.id,
    required this.title,
    this.opening = '',
    required this.coreStrength,
    this.impact = '',
    this.closing = '',
    this.singleSkillIds = const [],
    this.softSkillIds = const [],
    this.bundleId,
    this.effectTags = const [],
    this.seniority = ExperienceLevel.any,
    this.jobGoals = const [],
    required this.category,
    this.weight = 0,
    this.isDefaultHybrid = false,
  });

  final String id;
  final String title;

  /// 도입 (없으면 생략)
  final String opening;
  final String coreStrength;
  final String impact;

  /// 마무리 (없으면 생략)
  final String closing;

  /// [ResumeSkillPresets] id 또는 이름과 매칭
  final List<String> singleSkillIds;
  final List<String> softSkillIds;
  final String? bundleId;

  /// L4 효용 축 — 다양성·탐색 추천에 사용
  final List<String> effectTags;

  /// 이 템플릿이 가장 잘 맞는 연차 톤 ([ExperienceLevel.any]면 가중 없음)
  final ExperienceLevel seniority;

  /// 비어 있으면 목표 무관
  final List<JobGoal> jobGoals;

  final String category;
  final int weight;
  final bool isDefaultHybrid;

  /// 미리보기·붙여넣기용 본문
  String get fullBody {
    final parts =
        <String>[
          opening.trim(),
          coreStrength.trim(),
          impact.trim(),
          closing.trim(),
        ].where((s) => s.isNotEmpty).toList();
    return parts.join('\n\n');
  }

  /// 카드 미리보기 2줄 분량
  String previewSnippet({int maxChars = 96}) {
    final t = fullBody.replaceAll('\n\n', ' ').trim();
    if (t.length <= maxChars) return t;
    return '${t.substring(0, maxChars)}…';
  }
}
