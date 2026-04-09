import '../models/intro_template.dart';
import '../../../models/resume_intro_enums.dart';

/// 자기소개 템플릿 11~20
final List<IntroTemplate> kIntroTemplatesB = [
  IntroTemplate(
    id: 'intro_11',
    title: '환자 상담·CS (1)',
    coreStrength:
        '환자의 상태와 치료 과정을 쉽게 설명하는 것을 중요하게 생각하며, 환자가 이해하고 납득할 수 있는 상담을 진행해왔습니다. '
        '이를 통해 치료에 대한 거부감을 줄이고, 자연스럽게 치료 동의를 이끌어내는 데 기여해왔습니다.',
    impact: '신뢰 기반의 상담이 병원의 장기적인 환자 관계를 만든다고 생각합니다.',
    softSkillIds: ['환자 상담', '고객 CS'],
    jobGoals: [JobGoal.counseling],
    effectTags: ['trust', 'anxiety'],
    category: '상담·CS',
    weight: 3,
  ),
  IntroTemplate(
    id: 'intro_12',
    title: '환자 상담·CS (2)',
    coreStrength:
        '환자의 불안을 빠르게 파악하고 안정시키는 커뮤니케이션을 통해 진료 환경을 개선해왔습니다. '
        '긴장도가 높은 환자일수록 세심한 대응이 필요하다고 생각하며, 이를 통해 치료 협조도를 높이고 진료 효율을 개선해왔습니다.',
    impact: '환자 경험의 질을 높이는 것이 곧 병원의 경쟁력이라고 생각합니다.',
    softSkillIds: ['환자 상담', '고객 CS'],
    jobGoals: [JobGoal.counseling],
    effectTags: ['anxiety', 'trust', 'efficiency'],
    category: '상담·CS',
    weight: 3,
  ),
  IntroTemplate(
    id: 'intro_13',
    title: '운영·팀워크 (1)',
    coreStrength:
        '팀과의 협업을 통해 진료 효율을 극대화하는 것을 중요하게 생각합니다. '
        '각자의 역할을 이해하고 필요한 부분을 보완하며, 진료 흐름이 끊기지 않도록 조율하는 데 집중해왔습니다.',
    impact: '이러한 협업을 통해 전체 진료 속도와 안정성을 높이는 데 기여해왔습니다.',
    softSkillIds: ['팀 리더십'],
    effectTags: ['teamwork', 'flow'],
    category: '운영·팀워크',
    weight: 2,
  ),
  IntroTemplate(
    id: 'intro_14',
    title: '운영·팀워크 (2)',
    coreStrength:
        '재고 관리 및 운영 보조를 통해 병원 시스템이 원활하게 유지될 수 있도록 지원해왔습니다. '
        '필요한 자재를 사전에 파악하고 준비함으로써 진료 중단 상황을 방지하고, 운영 효율성을 높이는 데 기여해왔습니다.',
    impact: '작은 관리가 전체 운영에 큰 영향을 준다고 생각합니다.',
    softSkillIds: ['재고 관리'],
    effectTags: ['efficiency', 'flow'],
    category: '운영·팀워크',
    weight: 2,
  ),
  IntroTemplate(
    id: 'intro_15',
    title: '성장형 (1)',
    coreStrength:
        '지속적인 학습과 자기계발을 통해 임상 역량을 꾸준히 향상시키고 있습니다. '
        '새로운 술식이나 장비에 빠르게 적응하며, 변화하는 진료 환경에서도 안정적으로 업무를 수행할 수 있도록 노력해왔습니다.',
    impact: '이러한 태도가 장기적으로 병원의 경쟁력을 높인다고 생각합니다.',
    seniority: ExperienceLevel.junior,
    effectTags: ['learning', 'flow'],
    category: '성장형',
    weight: 2,
  ),
  IntroTemplate(
    id: 'intro_16',
    title: '성장형 (2)',
    coreStrength:
        '단순한 진료 보조를 넘어 진료의 흐름을 이해하고 능동적으로 대응하는 것을 목표로 하고 있습니다. '
        '상황에 맞게 판단하고 행동함으로써 의료진의 부담을 줄이고, 보다 효율적인 진료 환경을 만드는 데 기여하고자 합니다.',
    seniority: ExperienceLevel.mid,
    effectTags: ['efficiency', 'flow', 'learning'],
    category: '성장형',
    weight: 2,
  ),
  IntroTemplate(
    id: 'intro_17',
    title: '시니어·리더 (1)',
    coreStrength:
        '다양한 임상 경험을 바탕으로 후배 교육과 팀 운영에 기여해왔습니다. '
        '업무 표준을 정리하고 공유함으로써 팀 전체의 업무 수준을 균일하게 유지하고, 신규 인력의 적응 속도를 높이는 데 기여해왔습니다.',
    impact: '조직의 안정성이 곧 진료 품질로 이어진다고 생각합니다.',
    seniority: ExperienceLevel.senior,
    softSkillIds: ['신규 직원 교육', '팀 리더십'],
    jobGoals: [JobGoal.manager],
    effectTags: ['teamwork', 'learning'],
    category: '시니어·리더',
    weight: 4,
  ),
  IntroTemplate(
    id: 'intro_18',
    title: '시니어·리더 (2)',
    coreStrength:
        '진료 품질 향상과 환자 만족도 개선을 동시에 고려하며, 조직 내에서 중심 역할을 수행해왔습니다. '
        '문제 상황 발생 시 빠르게 대응하고 해결 방안을 제시함으로써 팀의 안정적인 운영을 유지하는 데 기여해왔습니다.',
    seniority: ExperienceLevel.senior,
    jobGoals: [JobGoal.manager],
    effectTags: ['flow', 'teamwork'],
    category: '시니어·리더',
    weight: 4,
  ),
  IntroTemplate(
    id: 'intro_19',
    title: '하이브리드',
    coreStrength:
        '예방 진료부터 교정 및 수술 보조까지 다양한 임상 경험을 바탕으로 상황에 맞는 유연한 대응이 가능합니다. '
        '환자의 상태와 진료 상황에 따라 최적의 보조를 제공하며, 진료 효율과 환자 만족도를 동시에 높이는 데 기여해왔습니다.',
    impact: '다양한 경험을 기반으로 병원의 전반적인 진료 완성도를 높이고자 합니다.',
    effectTags: ['flow', 'efficiency', 'trust'],
    category: '하이브리드',
    weight: 5,
  ),
  IntroTemplate(
    id: 'intro_20',
    title: '균형형 (메인 추천)',
    coreStrength:
        '정확한 진료 보조와 환자 커뮤니케이션을 기반으로 안정적인 진료 흐름을 만드는 것을 중요하게 생각합니다. '
        '상황에 맞게 선제적으로 대응하며, 의료진과의 협업을 통해 진료 효율을 높이는 데 기여해왔습니다.',
    impact: '이러한 경험을 바탕으로 환자 만족도와 병원의 운영 효율을 동시에 높이는 데 기여하고자 합니다.',
    effectTags: ['flow', 'trust', 'efficiency'],
    category: '하이브리드',
    weight: 8,
    isDefaultHybrid: true,
  ),
];
