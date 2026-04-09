import '../../../models/resume.dart';
import '../../../models/resume_intro_enums.dart';
import '../models/intro_template.dart';
import '../data/intro_template_catalog.dart';
import '../widgets/resume_skill_presets.dart';

/// 자기소개 템플릿 추천 — 스킬·숙련도·연차·목표·묶음·L4 효용 태그 반영
class IntroTemplateRecommendationService {
  IntroTemplateRecommendationService._();

  /// 묶음 id → (임상 프리셋명 | 소프트 프리셋명) 목록 — 부분 충족 시 점수 중간
  static const Map<String, List<String>> _bundles = {
    'restoration_flow': ['레진/실란트', '차트 관리'],
    'prevention_pair': ['스케일링', '불소도포'],
    'ortho_counsel': ['교정 와이어 교체', '환자 상담'],
    'surgery_safety': ['임플란트 보조', '감염 관리'],
  };

  static const int _scoreSingle = 15;
  static const int _scoreSoft = 10;
  static const int _scoreLevel4 = 8;
  static const int _scoreLevel5 = 12;
  static const int _scoreBundleFull = 25;
  static const int _scoreBundlePartial = 10;
  static const int _scoreSeniorityMatch = 12;
  static const int _scoreJobGoal = 15;
  static const int _scoreHybrid = 5;
  static const int _penaltySeniority = 8;
  static const int _penaltySeniorTemplateForJunior = 15;
  static const int _penaltySurgeryNoSkill = 20;

  /// 상위 점수 순 정렬 후 슬롯·다양성으로 8개 선정
  static List<RankedIntroTemplate> recommend(Resume resume) {
    final ranked =
        introTemplateCatalog
            .map(
              (t) => RankedIntroTemplate(
                template: t,
                score: _score(resume, t),
                reasonLine: _reasonLine(resume, t),
              ),
            )
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    return _pickDiverse(ranked);
  }

  static ExperienceLevel _effectiveExperienceLevel(Resume resume) {
    final p = resume.profile;
    if (p != null && p.experienceLevel != ExperienceLevel.any) {
      return p.experienceLevel;
    }
    return _inferFromExperiences(resume.experiences);
  }

  static ExperienceLevel _inferFromExperiences(List<ResumeExperience> ex) {
    if (ex.isEmpty) return ExperienceLevel.any;
    return ex.length >= 3 ? ExperienceLevel.mid : ExperienceLevel.junior;
  }

  static int _score(Resume resume, IntroTemplate t) {
    var s = t.weight;
    final skills = resume.skills;
    final profile = resume.profile;
    var maxLevelBonus = 0;

    for (final hint in t.singleSkillIds) {
      final m = _matchClinical(skills, hint);
      if (m != null) {
        s += _scoreSingle;
        final b = _levelBonus(m.level);
        if (b > maxLevelBonus) maxLevelBonus = b;
      }
    }
    s += maxLevelBonus;
    for (final hint in t.softSkillIds) {
      if (_matchSoft(skills, hint) != null) {
        s += _scoreSoft;
      }
    }

    if (t.bundleId != null) {
      final req = _bundles[t.bundleId!];
      if (req != null) {
        final got = req.where((h) => _matchAny(skills, h) != null).length;
        if (got >= req.length) {
          s += _scoreBundleFull;
        } else if (got > 0) {
          s += _scoreBundlePartial;
        }
      }
    }

    final userLv = _effectiveExperienceLevel(resume);
    if (t.seniority != ExperienceLevel.any) {
      if (userLv != ExperienceLevel.any && userLv == t.seniority) {
        s += _scoreSeniorityMatch;
      } else if (userLv == ExperienceLevel.junior &&
          t.seniority == ExperienceLevel.senior) {
        s -= _penaltySeniorTemplateForJunior;
      } else if (userLv != ExperienceLevel.any &&
          t.seniority != ExperienceLevel.any &&
          userLv != t.seniority) {
        s -= _penaltySeniority;
      }
    }

    if (profile != null &&
        t.jobGoals.isNotEmpty &&
        t.jobGoals.contains(profile.jobGoal)) {
      s += _scoreJobGoal;
    }

    if (t.isDefaultHybrid) {
      s += _scoreHybrid;
    }

    if (profile?.jobGoal == JobGoal.surgery &&
        (t.jobGoals.contains(JobGoal.surgery) || t.category == '수술·임플란트')) {
      final hasSurgery = skills.any(
        (sk) =>
            sk.name.contains('임플란트') ||
            sk.id.contains('임플란트') ||
            sk.name.contains('수술'),
      );
      if (!hasSurgery) {
        s -= _penaltySurgeryNoSkill;
      }
    }

    return s;
  }

  static ResumeSkill? _matchClinical(List<ResumeSkill> skills, String hint) {
    for (final sk in skills) {
      if (!ResumeSkillPresets.isClinicalSkillId(sk.id, sk.name)) continue;
      if (sk.id == hint || sk.name == hint) return sk;
    }
    return null;
  }

  static ResumeSkill? _matchSoft(List<ResumeSkill> skills, String hint) {
    for (final sk in skills) {
      if (!ResumeSkillPresets.isSoftSkillId(sk.id, sk.name)) continue;
      if (sk.id == hint || sk.name == hint) return sk;
    }
    return null;
  }

  static ResumeSkill? _matchAny(List<ResumeSkill> skills, String hint) {
    return _matchClinical(skills, hint) ?? _matchSoft(skills, hint);
  }

  static int _levelBonus(int level) {
    if (level >= 5) return _scoreLevel5;
    if (level >= 4) return _scoreLevel4;
    return 0;
  }

  static String _reasonLine(Resume resume, IntroTemplate t) {
    final parts = <String>[];
    final skills = resume.skills;

    for (final hint in t.singleSkillIds) {
      if (_matchClinical(skills, hint) != null) {
        parts.add(hint);
        break;
      }
    }
    for (final hint in t.softSkillIds) {
      if (_matchSoft(skills, hint) != null) {
        parts.add(hint);
        break;
      }
    }

    final p = resume.profile;
    if (p != null &&
        t.jobGoals.isNotEmpty &&
        t.jobGoals.contains(p.jobGoal) &&
        p.jobGoal != JobGoal.general) {
      parts.add(_jobGoalLabel(p.jobGoal));
    }

    if (parts.isEmpty) {
      if (t.isDefaultHybrid) {
        return '다양한 진료 보조 경험에 맞춘 균형형 추천';
      }
      return '${t.category} 톤으로 탐색해 보세요';
    }
    return '${parts.take(3).join('·')} 반영';
  }

  static String _jobGoalLabel(JobGoal g) {
    switch (g) {
      case JobGoal.orthodontics:
        return '교정 지향';
      case JobGoal.surgery:
        return '수술·임플란트 지향';
      case JobGoal.counseling:
        return '상담·CS 지향';
      case JobGoal.manager:
        return '리드·운영 지향';
      case JobGoal.reemployment:
        return '재취업 지향';
      case JobGoal.general:
        return '';
    }
  }

  /// 점수 순 + 중복 제거, 하이브리드(20번) 우선 포함
  static List<RankedIntroTemplate> _pickDiverse(
    List<RankedIntroTemplate> sorted,
  ) {
    if (sorted.isEmpty) return [];
    final out = <RankedIntroTemplate>[];
    final seen = <String>{};

    void add(RankedIntroTemplate r) {
      if (out.length >= 8) return;
      if (!seen.add(r.template.id)) return;
      out.add(r);
    }

    for (final r in sorted) {
      add(r);
      if (out.length >= 8) break;
    }

    final hasHybrid = out.any((r) => r.template.isDefaultHybrid);
    if (!hasHybrid) {
      RankedIntroTemplate? hybrid;
      for (final r in sorted) {
        if (r.template.isDefaultHybrid) {
          hybrid = r;
          break;
        }
      }
      if (hybrid != null) {
        if (out.length >= 8) out.removeLast();
        out.add(hybrid);
      }
    }

    return out.take(8).toList();
  }
}

class RankedIntroTemplate {
  const RankedIntroTemplate({
    required this.template,
    required this.score,
    required this.reasonLine,
  });

  final IntroTemplate template;
  final int score;
  final String reasonLine;
}
