import '../models/intro_template.dart';
import '../../../models/resume_intro_enums.dart';

/// 자기소개 템플릿 1~10
final List<IntroTemplate> kIntroTemplatesA = [
  IntroTemplate(
    id: 'intro_01',
    title: '예방·기본진료 중심 (1)',
    coreStrength:
        '스케일링과 예방 중심 진료를 기반으로 환자의 구강 건강을 장기적으로 관리해왔습니다. '
        '단순한 처치에 그치지 않고 환자의 생활 습관과 상태를 함께 고려하여 재발을 줄이는 데 집중해왔으며, '
        '이를 통해 내원 주기 유지와 환자 신뢰 형성에 기여해왔습니다.',
    impact: '정확한 술식과 안정적인 진료 보조를 통해 진료 흐름을 끊기지 않게 유지하는 것을 중요하게 생각합니다.',
    singleSkillIds: ['스케일링', '불소도포'],
    effectTags: ['revisit', 'trust', 'flow'],
    category: '예방·기본진료',
    weight: 2,
  ),
  IntroTemplate(
    id: 'intro_02',
    title: '예방·기본진료 중심 (2)',
    coreStrength:
        '기본 진료 보조와 예방 처치를 중심으로 환자와의 신뢰 형성을 중요하게 생각합니다. '
        '환자가 느끼는 불편과 긴장을 빠르게 파악하고 대응함으로써 진료에 대한 거부감을 낮추고, '
        '자연스럽게 치료 참여도를 높이는 데 집중해왔습니다.',
    impact: '이러한 접근을 통해 재방문율과 상담 전환율을 높이는 데 기여해왔습니다.',
    singleSkillIds: ['스케일링', '불소도포'],
    softSkillIds: ['환자 상담'],
    effectTags: ['revisit', 'anxiety', 'trust'],
    category: '예방·기본진료',
    weight: 2,
  ),
  IntroTemplate(
    id: 'intro_03',
    title: '보존·진료 흐름 (1)',
    coreStrength:
        '레진 및 실란트 등 보존 진료 보조 경험을 바탕으로 진료 흐름을 안정적으로 유지하는 데 강점이 있습니다. '
        '사전 준비와 정확한 차트 기록을 통해 의료진의 판단 속도를 높이고, 진료 시간을 효율적으로 단축하는 데 기여해왔습니다.',
    impact: '결과적으로 환자 대기 시간을 줄이고 전체 진료 회전율을 개선하는 데 역할을 해왔습니다.',
    singleSkillIds: ['레진/실란트'],
    bundleId: 'restoration_flow',
    effectTags: ['efficiency', 'flow'],
    category: '보존·진료 흐름',
    weight: 2,
  ),
  IntroTemplate(
    id: 'intro_04',
    title: '보존·진료 흐름 (2)',
    coreStrength:
        '진료 준비부터 마무리까지 전 과정의 흐름을 이해하고 있으며, 각 단계에서 필요한 요소를 선제적으로 준비하는 습관을 가지고 있습니다. '
        '이를 통해 진료 중 불필요한 지연을 줄이고, 팀 전체의 업무 효율을 높이는 데 기여해왔습니다.',
    impact: '안정적인 진료 환경을 만드는 것이 환자 경험 향상으로 이어진다고 생각합니다.',
    bundleId: 'restoration_flow',
    effectTags: ['efficiency', 'flow', 'teamwork'],
    category: '보존·진료 흐름',
    weight: 2,
  ),
  IntroTemplate(
    id: 'intro_05',
    title: '교정 (1)',
    coreStrength:
        '교정 진료 보조 경험을 바탕으로 와이어 교체, 인상 채득, 구강 내 촬영 등 전반적인 과정에 익숙합니다. '
        '환자에게 치료 진행 상황을 이해하기 쉽게 설명함으로써 치료 순응도를 높이고, 장기 치료 과정에서 발생할 수 있는 이탈을 줄이는 데 기여해왔습니다.',
    impact: '이러한 커뮤니케이션을 통해 병원의 지속적인 환자 관리에 도움이 되고자 합니다.',
    singleSkillIds: ['교정 와이어 교체', '구내,구외 포토'],
    jobGoals: [JobGoal.orthodontics],
    effectTags: ['trust', 'revisit'],
    category: '교정',
    weight: 3,
  ),
  IntroTemplate(
    id: 'intro_06',
    title: '교정 (2)',
    coreStrength:
        '교정 환자의 장기 치료 특성을 이해하고 있으며, 환자의 심리적 변화까지 고려한 대응을 중요하게 생각합니다. '
        '정기적인 안내와 소통을 통해 치료에 대한 신뢰를 유지하고, 예약 이탈 및 치료 중단을 최소화하는 데 집중해왔습니다.',
    impact: '이를 통해 안정적인 환자 유지와 매출 지속성에 기여해왔습니다.',
    singleSkillIds: ['교정 와이어 교체'],
    softSkillIds: ['환자 상담'],
    jobGoals: [JobGoal.orthodontics, JobGoal.counseling],
    effectTags: ['trust', 'revisit', 'anxiety'],
    category: '교정',
    weight: 3,
  ),
  IntroTemplate(
    id: 'intro_07',
    title: '수술·임플란트·감염관리 (1)',
    coreStrength:
        '임플란트 및 수술 보조 경험을 바탕으로 철저한 기구 준비와 감염 관리에 집중해왔습니다. '
        '수술 과정에서 발생할 수 있는 변수를 최소화하기 위해 사전 준비와 체크리스트 기반 관리를 습관화하였으며, '
        '이를 통해 의료진이 안정적으로 술식에 집중할 수 있는 환경을 만들어왔습니다.',
    impact: '안전한 진료 환경이 병원의 신뢰로 이어진다고 생각합니다.',
    singleSkillIds: ['임플란트 보조'],
    softSkillIds: ['감염 관리'],
    jobGoals: [JobGoal.surgery],
    effectTags: ['safety', 'flow'],
    category: '수술·임플란트',
    weight: 3,
  ),
  IntroTemplate(
    id: 'intro_08',
    title: '수술·임플란트·감염관리 (2)',
    coreStrength:
        '수술 전 준비부터 멸균 관리까지 전 과정의 중요성을 인지하고 있으며, 체계적인 감염 관리 시스템을 유지하는 데 집중해왔습니다. '
        '작은 관리 소홀도 큰 문제로 이어질 수 있다는 인식 아래, 반복 점검과 기준 준수를 통해 안정적인 진료 환경을 유지해왔습니다.',
    impact: '이를 통해 환자 안전뿐 아니라 병원의 리스크 관리에도 기여해왔습니다.',
    singleSkillIds: ['임플란트 보조'],
    softSkillIds: ['감염 관리'],
    jobGoals: [JobGoal.surgery],
    effectTags: ['safety', 'infection'],
    category: '수술·임플란트',
    weight: 3,
  ),
  IntroTemplate(
    id: 'intro_09',
    title: '방사선·기록 (1)',
    coreStrength:
        '방사선 촬영과 차트 기록에서 높은 정확도를 유지하며, 진료 데이터를 체계적으로 관리해왔습니다. '
        '정확한 데이터 축적은 의료진의 진단과 치료 방향 결정에 중요한 역할을 하며, 이를 통해 불필요한 재촬영이나 오류를 줄이는 데 기여해왔습니다.',
    impact: '데이터 기반 진료 환경을 만드는 데 기여하는 것을 중요하게 생각합니다.',
    singleSkillIds: ['방사선 촬영'],
    softSkillIds: ['차트 관리'],
    effectTags: ['efficiency', 'safety'],
    category: '방사선·기록',
    weight: 2,
  ),
  IntroTemplate(
    id: 'intro_10',
    title: '방사선·기록 (2)',
    coreStrength:
        '진료 과정에서 발생하는 모든 데이터를 빠르고 정확하게 기록하며, 의료진이 필요한 정보를 즉시 활용할 수 있도록 지원해왔습니다. '
        '이를 통해 진료의 연속성과 정확성을 높이고, 환자 대응 속도를 개선하는 데 기여해왔습니다.',
    impact: '기록의 정확성이 곧 진료의 품질이라고 생각합니다.',
    singleSkillIds: ['방사선 촬영'],
    softSkillIds: ['차트 관리'],
    effectTags: ['efficiency', 'flow'],
    category: '방사선·기록',
    weight: 2,
  ),
];
