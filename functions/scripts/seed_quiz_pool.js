/**
 * quiz_pool Firestore 시드 스크립트
 *
 * 실행 방법:
 *   cd functions
 *   node scripts/seed_quiz_pool.js
 *
 * 필요: serviceAccountKey.json 을 functions/ 폴더에 위치시킬 것
 */

const admin = require('firebase-admin');
const path  = require('path');

// ── Firebase 초기화 ──────────────────────────────────────────
const serviceAccount = require(path.join(__dirname, '..', '..', 'tools', 'serviceAccountKey.json'));
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

// ══════════════════════════════════════════════════════════════
// 문제 데이터
// ══════════════════════════════════════════════════════════════

const IMPLANT_BOOK   = '임플란트_초보탈출';
const PROSTHETIC_BOOK = '보철과';

/** 임플란트 초보탈출 — 30문제 */
const implantQuizzes = [
  {
    question:     '임플란트 픽스쳐(Fixture)의 재료로 티타늄(Titanium)이 선택되는 약리학적 및 생물학적 핵심 근거는?',
    options:      ['높은 연성과 전성', '인체 친화성 및 골유착력', '구강 내 완전 부식성', '세균 증식 억제 기능'],
    correctIndex: 1,
    explanation:  '티타늄은 인체에 해가 없고 친화력이 높으며 뼈와 잘 붙는(골유착) 성질을 가지고 있습니다.',
    sourcePage:   '6',
  },
  {
    question:     '상악과 하악의 골질(Bone Quality) 차이에 따른 골 유착 소요 기간의 생리학적 분석으로 옳은 것은?',
    options:      ['상악(치밀골)-3개월 소요', '하악(해면골)-6개월 소요', '상악(해면골)-최대 6개월 소요', '하악(치밀골)-최소 5개월 소요'],
    correctIndex: 2,
    explanation:  '상악은 푸석한 해면골 구조로 최대 6개월이 걸리며, 하악은 단단한 치밀골 구조로 2~3개월 정도 소요됩니다.',
    sourcePage:   '7',
  },
  {
    question:     'ISQ(Implant Stability Quotient) 측정기기를 활용한 골 유착 판정 시, 안정적인 상태를 나타내는 표준 수치는?',
    options:      ['45 이상', '55 이상', '65 이상', '85 이상'],
    correctIndex: 2,
    explanation:  '일반적으로 ISQ 수치가 65 이상으로 측정되면 안정적인 골 유착이 이루어졌다고 판단합니다.',
    sourcePage:   '9',
  },
  {
    question:     '네비게이션 임플란트 시스템에서 수술 전 전용 가이드(Guide)를 제작하는 직접적인 목적은?',
    options:      ['골이식재 비용 절감', '최소 절개 및 정밀 위치 드릴링', '임플란트 픽스쳐 직경 확대', '마취액 투여량 감소'],
    correctIndex: 1,
    explanation:  'CT와 X-ray 데이터를 통해 최적의 위치를 찾고 가이드를 이용해 정확한 위치에 드릴링하여 최소 절개 수술을 가능하게 합니다.',
    sourcePage:   '6',
  },
  {
    question:     '임플란트 나사 결합 방식 중 External type이 Internal type에 비해 최근 사용량이 감소하는 주된 이유는?',
    options:      ['싱킹(Sinking) 현상의 심화', '나사 파절 위험 전무', '염증 발생 가능성 및 심미성 부족', '보철적 편의성 과다'],
    correctIndex: 2,
    explanation:  '익스터널 타입은 연결부가 밖에 위치하여 염증 발생 가능성이 있어 점차 사용이 줄어드는 추세입니다.',
    sourcePage:   '12',
  },
  {
    question:     '맞춤형 지대주(Custom Abutment)가 기성 지대주에 비해 갖는 기계적·임상적 우수성은?',
    options:      ['제작 비용의 획기적 절감', '씹는 힘 분산 및 파절 방지', '식립 각도 조절 불가능', '잇몸 퇴축 유도'],
    correctIndex: 1,
    explanation:  '맞춤형 지대주는 넓은 면으로 보철과 접하여 저작압을 고르게 분산시키고 보철물 파절을 최소화합니다.',
    sourcePage:   '15',
  },
  {
    question:     '임플란트 드릴링 순서 중 Lance drill(Guide drill)의 핵심적인 기능은?',
    options:      ['최종 식립구 확장', '식립 위치 표시 및 마킹', '측면 골 삭제', '엔진 토크값 측정'],
    correctIndex: 1,
    explanation:  '가장 먼저 사용하며 끝이 뾰족하여 원하는 위치의 뼈를 정확히 뚫어 식립 위치를 표시합니다.',
    sourcePage:   '18',
  },
  {
    question:     '발치 즉시 식립 수술 시, 몸통부의 절삭 날을 이용해 측면 삭제를 시행하는 드릴의 명칭은?',
    options:      ['Twist drill', 'Taper drill', 'Sidecut drill (Lindemann)', 'Start drill'],
    correctIndex: 2,
    explanation:  '사이드컷 드릴(린데만 드릴)은 측면 삭제가 가능하여 발치 즉시 식립 시 유용하게 사용됩니다.',
    sourcePage:   '18',
  },
  {
    question:     '임플란트 수술 중 인접 치아의 간섭으로 인해 드릴링이 어려울 때 사용하는 보조 기구는?',
    options:      ['Torque wrench', 'Drill extension', 'Depth gauge', 'Parallel pin'],
    correctIndex: 1,
    explanation:  '드릴 연장 기구(Extension)를 연결하여 길이를 늘려줌으로써 주변 간섭을 피해 드릴링할 수 있습니다.',
    sourcePage:   '18',
  },
  {
    question:     '외과용 블레이드(Blade) 중 좁고 깊은 구치부나 잇몸 성형 시 정밀 절개를 위해 사용하는 번호는?',
    options:      ['#11번', '#12번', '#15번', '#20번'],
    correctIndex: 1,
    explanation:  '12번 블레이드는 갈고리 모양으로 좁고 깊숙한 곳(최후방 구치부 등)의 절개에 유용합니다.',
    sourcePage:   '26',
  },
  {
    question:     '봉합사 중 Nylon(나일론)을 사용할 때 블랙 실크에 비해 더 길게 컷팅해야 하는 역학적 이유는?',
    options:      ['세균 증식 억제 목적', '매듭의 미끄러움 및 안정성 부족', '환자의 이물감 제거', '실밥 제거(S/O) 편의성'],
    correctIndex: 1,
    explanation:  '나일론은 매끄럽고 탄성이 있어 매듭이 풀리기 쉽기 때문에 실크보다 조금 더 길게 자르는 것이 안전합니다.',
    sourcePage:   '56',
  },
  {
    question:     '상악동 거상술 중 수압 거상법을 시행할 때 사용하는 시린지(Syringe)의 규격과 용도는?',
    options:      ['1cc / 생리식염수 주입', '10cc / 공기 주입', '50cc / 혈액 채취', '3cc / 마취액 주입'],
    correctIndex: 0,
    explanation:  '1cc 시린지에 멸균 생리식염수를 담아 주수 라인에 연결하여 점막을 수압으로 들어 올립니다.',
    sourcePage:   '30',
  },
  {
    question:     '골 이식재 중 면역 거부 반응이 없고 골형성·골유도·골전도 능력을 모두 갖춘 이상적인 재료는?',
    options:      ['동종골(Allograft)', '이종골(Xenograft)', '자가골(Autograft)', '합성골(Synthetic)'],
    correctIndex: 2,
    explanation:  '자가골은 본인의 조직이므로 거부 반응이 없으며 세 가지 골 재생 능력을 모두 갖춘 가장 뛰어난 재료입니다.',
    sourcePage:   '31',
  },
  {
    question:     '자가혈 이식(PRF) 술식에서 원심 분리기 작동 후 추출되는 피브린층의 위치와 포함 성분은?',
    options:      ['제일 위층 / 적혈구', '중간층 / 성장인자 및 혈소판', '제일 아래층 / 무세포 혈장', '전체층 / 콜라겐'],
    correctIndex: 1,
    explanation:  '원심 분리 후 중간층에 성장인자와 혈소판이 농축된 피브린층(PRF)이 형성되어 회복을 돕습니다.',
    sourcePage:   '37',
  },
  {
    question:     '비흡수성 차폐막인 Titanium mesh를 사용했을 때 임상적으로 반드시 수행해야 하는 후속 단계는?',
    options:      ['1주일 후 자연 흡수 확인', '1~3개월 후 제거를 위한 2차 수술', '평생 구강 내 유지', '레이저를 통한 녹이기'],
    correctIndex: 1,
    explanation:  '비흡수성 재료이므로 조직 재생 후 평균 1~3개월 뒤에 이를 제거하는 별도의 과정이 필요합니다.',
    sourcePage:   '39',
  },
  {
    question:     '골 이식재의 입자 형태 중 큰 결손 부위에 적합하며 형태 유지가 가장 우수한 타입은?',
    options:      ['Powder type', 'Syringe type', 'Block type', 'Gel type'],
    correctIndex: 2,
    explanation:  '블록형 골이식재는 큰 결손 부위에 적합하며 오염 위험이 낮고 형태 유지가 잘 되는 장점이 있습니다.',
    sourcePage:   '35',
  },
  {
    question:     'Tenting screw가 차폐막 술식에서 담당하는 기계적인 역할로 옳은 것은?',
    options:      ['잇몸의 혈류 차단', '이식된 골과 주변 공간의 유지(지지)', '임플란트 픽스쳐의 회전 방지', '인공치아의 색상 고정'],
    correctIndex: 1,
    explanation:  '텐트 폴대와 같이 이식한 뼈 주변의 공간이 무너지지 않도록 지지해주는 역할을 합니다.',
    sourcePage:   '39',
  },
  {
    question:     '상악동 거상술 시 잔존 치조골의 두께가 3mm 미만인 극한 상황에서 권장되는 접근법은?',
    options:      ['치조정 접근법 (SCA)', '측방 접근법 (SLA)', '단순 매복 발치법', '치은 절제술'],
    correctIndex: 1,
    explanation:  '남은 뼈가 매우 적은 경우 측면을 창문처럼 열어 점막을 직접 보면서 들어 올리는 SLA 방식이 안전합니다.',
    sourcePage:   '76',
  },
  {
    question:     '오스테오톰(Osteotome) 팁 중 골질이 무른 경우 뼈를 측방으로 압축시키기 위해 사용하는 형태는?',
    options:      ['Convex (볼록한 형태)', 'Concave (오목한 형태)', 'Flat (평평한 형태)', 'Hook (갈고리 형태)'],
    correctIndex: 0,
    explanation:  '볼록한 형태(Convex)는 뼈를 측방으로 밀어내며 압축시키고 구멍을 넓히는 용도로 쓰입니다.',
    sourcePage:   '40',
  },
  {
    question:     '상악동 거상 수술 도중 점막 천공 유무를 확인하기 위해 시린지로 흡인 시 나타나야 하는 증상은?',
    options:      ['공기 방울이 올라옴', '혈액이 올라옴', '생리식염수가 그대로 남음', '타액이 역류함'],
    correctIndex: 1,
    explanation:  '주수 라인을 통해 흡인했을 때 혈액이 올라오면 점막 천공이 없다는 증거로 간주합니다.',
    sourcePage:   '83',
  },
  {
    question:     '치조골 분할술(Ridge split)의 주된 적응증에 해당하는 환자의 상태는?',
    options:      ['골 폭은 좁으나 높이는 충분한 경우', '골 높이가 매우 낮은 경우', '상악동염을 앓고 있는 경우', '전신 질환으로 골다공증이 있는 경우'],
    correctIndex: 0,
    explanation:  '릿지 스플릿은 수평적 폭이 좁아진 치조골을 갈라서 확장한 뒤 임플란트를 심는 술식입니다.',
    sourcePage:   '93',
  },
  {
    question:     '상악동 거상술 시 어시스트가 수술 부위 쪽으로 강력한 석션(Suction)을 피해야 하는 이유는?',
    options:      ['환자의 구역질 유발 방지', '상악동막 파열 및 이식재 흡입 방지', '마취 효과의 확산 방지', '체어 엔진의 과부하 예방'],
    correctIndex: 1,
    explanation:  '수술 부위에 직접 석션을 대면 얇은 상악동막이 찢어지거나 넣은 뼈가 빨려 들어갈 위험이 큽니다.',
    sourcePage:   '79',
  },
  {
    question:     '임플란트 2차 수술 시 Fixture 상부에 골이 덮여 있어 보이지 않을 때 사용하는 기구는?',
    options:      ['Bone carrier', 'Molt Surgical curette', 'Tissue forcep', 'Kelly'],
    correctIndex: 1,
    explanation:  '뼈에 묻혀있는 경우에는 몰트 큐렛을 사용하여 주변 골을 긁어 제거한 뒤 커버 스크류를 노출시킵니다.',
    sourcePage:   '61',
  },
  {
    question:     '임플란트 수술 직후 환자에게 제공하는 젖은 거즈가 마른 거즈보다 우수한 이유는?',
    options:      ['지혈 속도가 2배 빠름', '거즈 제거 시 혈병 유착 및 재출혈 방지', '입안의 미생물 완전 박멸', '마취 풀림 통증 완화'],
    correctIndex: 1,
    explanation:  '마른 거즈는 피를 흡수하며 달라붙어 제거 시 혈병을 떼어내 재출혈을 일으킬 수 있으므로 젖은 상태가 안전합니다.',
    sourcePage:   '56',
  },
  {
    question:     '수술 전 베타딘 볼을 이용한 구외 소독 시 환자에게 반드시 강조해야 할 주의사항은?',
    options:      ['입을 크게 벌리게 함', '소독 후 얼굴을 만지거나 닦지 않게 함', '소독약을 즉시 삼키게 함', '코로만 숨을 쉬게 함'],
    correctIndex: 1,
    explanation:  '수술실의 멸균 상태 유지를 위해 소독된 안면 부위를 손으로 만지지 않도록 철저히 교육해야 합니다.',
    sourcePage:   '52',
  },
  {
    question:     '임플란트 1차 수술 후 처방된 약(항생제 등)의 복용 지침으로 가장 옳은 교육은?',
    options:      ['아플 때만 선택적 복용', '증상이 없어도 내성 예방 위해 전량 복용', '술과 함께 복용하여 흡수율 증대', '위장 장애 시 즉시 복용 중단 후 방치'],
    correctIndex: 1,
    explanation:  '항생제는 혈중 농도 유지와 내성 방지를 위해 통증 여부와 상관없이 처방된 일수를 모두 채워 복용해야 합니다.',
    sourcePage:   '47',
  },
  {
    question:     '힐링 어버트먼트(Healing Abutment) 높이 선정 시 가장 이상적인 노출 정도는?',
    options:      ['잇몸 밑으로 3mm 함몰', '잇몸 위로 1~2mm 노출', '대합치와 강하게 교합되는 높이', '무조건 7mm 이상의 높이'],
    correctIndex: 1,
    explanation:  '보철 제작을 위한 통로를 형성해야 하므로 잇몸 위로 살짝 올라오는 사이즈가 적절합니다.',
    sourcePage:   '32',
  },
  {
    question:     '임플란트 수술 중 세척(Irrigation)을 위해 사용하는 니들(Needle)의 안전한 처치법은?',
    options:      ['끝을 날카롭게 유지', '끝 2~3mm를 제거하고 40~50도 굴곡', '뜨거운 물에 담가 소독', '직선 상태로 길게 유지'],
    correctIndex: 1,
    explanation:  '끝이 뾰족하면 조직 손상을 줄 수 있으므로 끝을 제거하고 사용하기 편한 각도로 꺾어서 준비합니다.',
    sourcePage:   '51',
  },
  {
    question:     '임플란트 수술 후 냉찜질의 골든 타임과 권장 주기는?',
    options:      ['수술 1주일 후부터 1시간씩', '수술 직후부터 다음 날까지 5분 간격', '통증이 생길 때만 1회 실시', '온찜질과 매시간 교대로 실시'],
    correctIndex: 1,
    explanation:  '붓기는 3일째부터 나타나므로 예방을 위해 수술 직후부터 다음 날 저녁까지 간헐적으로 실시합니다.',
    sourcePage:   '59',
  },
  {
    question:     '2차 수술 시 사용하는 Bone Profiler 드릴의 주된 목적은?',
    options:      ['인공 뼈를 채취하는 용도', '힐링 체결을 방해하는 주변 뼈 정리', '잇몸을 동그랗게 잘라내는 용도', '임플란트 픽스쳐를 직접 식립하는 용도'],
    correctIndex: 1,
    explanation:  '본 프로파일러는 픽스쳐 상단에 뼈가 자라 들어와 부속품 체결이 어려울 때 이를 다듬어주는 역할을 합니다.',
    sourcePage:   '21',
  },
];

/** 알고보면 재미있는 보철과 — 30문제 */
const prostheticQuizzes = [
  {
    question:     '간접 충전(Indirect Restoration)이 직접 충전에 비해 갖는 구조적 장점으로 옳은 것은?',
    options:      ['협소한 수복 범위에 유리', '고온·고압 처리를 통한 내구성 향상', '임시 수복 단계 생략 가능', '구강 내 직접 조각을 통한 정밀도'],
    correctIndex: 1,
    explanation:  '간접 충전은 모델 상에서 제작되므로 고온·고압 처리가 가능하여 내구성이 높고 다이(die)를 통해 정밀도를 높일 수 있습니다.',
    sourcePage:   '2',
  },
  {
    question:     '금(Gold) 인레이/온레이의 물성 중 긴밀한 교합인 환자에게 특히 유리한 이유는?',
    options:      ['높은 열전도율', '대합치와 유사한 마모도 및 전성', '비심미적인 노란 색상', '구강 내 타액에 의한 부식성'],
    correctIndex: 1,
    explanation:  '금은 강도가 자연치와 가깝고 연성과 전성이 있어 사용하면서 교합이 약간씩 조정되는 특성이 있어 긴밀한 교합에 유리합니다.',
    sourcePage:   '2',
  },
  {
    question:     '레진 시멘트(Resin cement) 사용 시 인접면의 잉여 시멘트를 효율적으로 제거하기 위한 골든 타임은?',
    options:      ['혼합 직후 흐름성이 클 때', '1~2초 광중합 후 반경화 상태일 때', '60초 완전 광중합 후 단단할 때', '세팅 24시간 경과 후'],
    correctIndex: 1,
    explanation:  '레진 시멘트는 완전히 굳으면 제거가 매우 어려우므로, 1~2초간 짧게 광중합한 후 잉여분을 제거하고 추가 중합을 해야 합니다.',
    sourcePage:   '9',
  },
  {
    question:     '세라믹 인레이/온레이 시술 시 금기증에 해당하는 임상적 상황은?',
    options:      ['심미적 요구도가 높은 경우', '임상 치관이 짧거나 깊은 수직피개', '소구치 부위의 우식', '변색이 없는 인접면 우식'],
    correctIndex: 1,
    explanation:  '세라믹은 강도 확보를 위한 최소 두께가 필요하므로 치관이 짧거나 수직피개(overbite)가 심하면 파절 위험으로 사용이 어렵습니다.',
    sourcePage:   '9',
  },
  {
    question:     '지르코니아(Zirconia) 보철물의 특징 중 최근 전치부에 사용 가능해진 기술적 배경은?',
    options:      ['강도의 급격한 저하', '투명도의 획기적인 개선', '표면 거칠기의 증가', '금속 캡의 추가'],
    correctIndex: 1,
    explanation:  '과거 지르코니아는 투명도가 낮아 구치부에만 쓰였으나, 최근 투명도가 개선되어 변색이 심한 전치부에도 사용됩니다.',
    sourcePage:   '10',
  },
  {
    question:     '크라운 프렙(Cr prep.) 시 사용하는 다이아몬드 버 중 절삭력이 가장 강력한 색 띠는?',
    options:      ['빨간색', '파란색', '검정색', '노란색'],
    correctIndex: 2,
    explanation:  '다이아몬드 버는 입자 크기에 따라 색 띠로 구분하며 검정 > 초록 > 파랑 > 빨강 > 노랑 > 흰색 순으로 절삭력이 강합니다.',
    sourcePage:   '12',
  },
  {
    question:     '고무(Rubber) 인상재의 물리적 특성 중 인상 채득 전 완벽한 지혈이 필수인 이유는?',
    options:      ['친수성으로 피를 흡수함', '소수성으로 피가 인상재를 밀어냄', '혈액과 반응하여 경화가 빨라짐', '인상재의 색상을 변색시킴'],
    correctIndex: 1,
    explanation:  '고무 인상재는 소수성이므로 출혈 부위가 있으면 피가 인상재를 밀어내어 마진이 정확히 나오지 않습니다.',
    sourcePage:   '14',
  },
  {
    question:     '지대치의 치경부 변연(Margin) 위치 중 치은 연하로 형성되는 방식의 명칭은?',
    options:      ['Supra margin', 'Equigingival margin', 'Sub margin', 'Just margin'],
    correctIndex: 2,
    explanation:  '치은 높이보다 아래로 마진을 잡는 것을 Sub margin이라고 하며, 주로 심미적인 목적을 위해 시행합니다.',
    sourcePage:   '14',
  },
  {
    question:     '전악(Full tray) 인상 채득이 편측(Bite tray) 인상보다 정밀한 임상적 근거는?',
    options:      ['인상재 소요량의 감소', '대합치와 교합 관계의 명확한 인기', '환자의 입 벌림 강제 유지', '트레이 시적 시간의 단축'],
    correctIndex: 1,
    explanation:  '기성 트레이(전악)는 지대치, 대합치, 바이트를 각각 채득하므로 교합이 불안정하거나 다수 보철 제작 시 훨씬 정밀합니다.',
    sourcePage:   '15',
  },
  {
    question:     '투명도가 높은 전치부 심미 보철 합착 시 다양한 색상의 레진 시멘트를 사용하는 이유는?',
    options:      ['시멘트의 강도를 높이기 위해', '지대치 및 시멘트 색의 비침 현상 조절', '광중합 시간을 10분 이상 늘리기 위해', '불소 방출량을 극대화하기 위해'],
    correctIndex: 1,
    explanation:  '투명한 보철물은 내부 지대치나 노란 시멘트 색이 비쳐 보일 수 있으므로 보철물 색조에 맞는 다양한 시멘트 색상을 선택해 조절합니다.',
    sourcePage:   '17',
  },
  {
    question:     '라미네이트(PLV)의 금기증 중 하나인 절단 교합(Edge to edge) 환자에게 시술을 권장하지 않는 역학적 이유는?',
    options:      ['치아 변색이 너무 심해서', '보철물 탈락 및 파절 위험이 높아서', '잇몸 염증을 유발하기 때문에', '마취가 잘 안 되기 때문에'],
    correctIndex: 1,
    explanation:  '절단 교합이나 긴밀 교합인 경우 얇은 라미네이트 판이 교합력을 견디지 못하고 쉽게 깨지거나 떨어질 수 있습니다.',
    sourcePage:   '18',
  },
  {
    question:     '브릿지(Bridge)의 가공치 디자인 중 Hollow pontic을 제작하는 주된 목적은?',
    options:      ['심미성 극대화', '무게 감소를 통한 지대치 부담 경감', '자정 작용 유도', '제작 비용의 대폭 상향'],
    correctIndex: 1,
    explanation:  '가공치의 금 용적이 커지면 무게가 무거워져 지대치에 무리가 가므로, 내면을 비워 무게를 줄이는 디자인입니다.',
    sourcePage:   '31',
  },
  {
    question:     '부분틀니(RPD) 제작 계획 중 외과적 처치(발치 등)를 가장 조기에 시행해야 하는 생물학적 이유는?',
    options:      ['기공소 작업 시간 확보', '지대치의 예후 평가 및 조직 회복 기간 필요', '환자의 심리적 적응 유도', '보험 청구 순서 준수'],
    correctIndex: 1,
    explanation:  '발치나 치주 수술 후 잇몸이 아물고 지대치의 상태를 확진해야 정확한 틀니 설계가 가능하기 때문입니다.',
    sourcePage:   '43',
  },
  {
    question:     '최종 틀니 정밀 인상(Functional impression) 전 최소 4시간 이상 기존 틀니를 빼두어야 하는 이유는?',
    options:      ['틀니 소독 시간 확보', '눌려있던 잇몸 조직의 회복 및 안정화', '타액 분비량의 인위적 조절', '환자의 금식 유도'],
    correctIndex: 1,
    explanation:  '틀니에 눌려 변형된 잇몸 상태로 본을 뜨면 새 틀니가 들뜰 수 있어 조직이 제자리를 찾을 휴식기가 필요합니다.',
    sourcePage:   '51',
  },
  {
    question:     '개인 트레이(Individual tray) 제작 시 변연 형성(Border molding)을 위해 짧게 제작되는 표준 길이는?',
    options:      ['0.5mm', '2mm', '5mm 이상', '기성 트레이와 동일'],
    correctIndex: 1,
    explanation:  '개인 트레이는 근육의 움직임을 인기할 공간(컴파운드 왁스 등) 확보를 위해 2mm 짧게 제작합니다.',
    sourcePage:   '52',
  },
  {
    question:     '완전틀니의 보더 몰딩(Border molding) 시 Compound wax를 선택해야 하는 상황은?',
    options:      ['트레이 높이가 충분할 때', '트레이 높이가 부족하여 변연 연장이 필요할 때', '인상재가 너무 묽을 때', '환자가 구역질을 심하게 할 때'],
    correctIndex: 1,
    explanation:  '컴파운드 왁스는 흐름성이 적어 트레이가 짧은 경우 변연을 연장하며 인상 채득하기에 적합합니다.',
    sourcePage:   '53',
  },
  {
    question:     '무치악 환자의 보철 제작 기준이 되는 CRO(과두안정위)의 정의로 옳은 것은?',
    options:      ['치아가 가장 많이 맞물리는 위치', '과두가 긴장 없이 최상방에 위치한 상태', '하악이 가장 앞으로 나온 위치', '혀가 입천장에 닿아있는 상태'],
    correctIndex: 1,
    explanation:  '과두안정위(CRO)는 과두가 관절와 내에서 가장 안정적인 위치에 있는 상태로 재현성이 높습니다.',
    sourcePage:   '58',
  },
  {
    question:     '레진상 완전틀니 제작 전 Record base를 제작하여 기공소에 의뢰하는 주된 목적은?',
    options:      ['틀니의 금속 뼈대 형성', '교합 고경(VD) 기록 및 기초 기반 마련', '인공치 색상 선택 보조', '치석 제거 범위 확인'],
    correctIndex: 1,
    explanation:  '레코드 베이스(기초상)는 추후 의치상이 될 부위로, 왁스림을 얹어 교합 고경을 기록하는 데 사용됩니다.',
    sourcePage:   '58',
  },
  {
    question:     '부분틀니(RPD) 구성 요소 중 모든 부분이 직·간접적으로 연결되는 기초 구조물 역할은?',
    options:      ['레스트(Rest)', '부연결장치(Minor connector)', '주연결장치(Major connector)', '직접 유지장치'],
    correctIndex: 2,
    explanation:  '주연결장치(Lingual bar 등)는 부분틀니의 각 구성 요소를 하나로 묶어주는 중추적인 역할을 합니다.',
    sourcePage:   '41',
  },
  {
    question:     '틀니 수리를 위해 환자가 착용한 상태에서 인상을 채득하고 틀니가 함께 빠지게 하는 술식은?',
    options:      ['픽업 인상 (Pick up impression)', '알지네이트 예비 인상', '기능 인상 (Functional imp)', '바이트 채득 (Bite registration)'],
    correctIndex: 0,
    explanation:  '틀니 수리 시에는 틀니를 입에 낀 채로 알지네이트 본을 떠서 틀니가 인상체에 박혀 나오게 하는 픽업 인상이 필요합니다.',
    sourcePage:   '66',
  },
  {
    question:     '2025년 2월 1일부터 개정되는 보험 임플란트 상부 구조물 급여 대상 재료는?',
    options:      ['PFM 및 Gold crown', 'PFM 및 Zirconia crown', 'Metal 및 Resin crown', '오직 PFM 단독'],
    correctIndex: 1,
    explanation:  '고시 개정에 따라 기존 PFM 외에 지르코니아 크라운도 보험 임플란트 상부 구조물로 급여 청구가 가능해집니다.',
    sourcePage:   '68',
  },
  {
    question:     '임플란트 2차 수술 시 픽스쳐 상단의 골을 제거하기 위해 사용하는 기구의 명칭은?',
    options:      ['Bone file', 'Bone profiler', 'Surgical curette', 'Round bur'],
    correctIndex: 1,
    explanation:  '본 프로파일러는 힐링 어버트먼트 체결 시 방해가 되는 주변 뼈를 정리하는 전용 드릴입니다.',
    sourcePage:   '70',
  },
  {
    question:     '임플란트 나사 결합 방식 중 External type과 비교한 Internal type의 약점은?',
    options:      ['식립 각도에 따른 보철적 편의성 부족', '나사 파절 위험 전무', '어버트먼트 침하(Sinking) 현상 없음', '잇몸 치유 속도 저하'],
    correctIndex: 0,
    explanation:  'Internal 방식은 어버트먼트가 내부로 들어가므로 식립 각도가 어긋나면 보철물 연결이 까다로울 수 있습니다.',
    sourcePage:   '102',
  },
  {
    question:     '임플란트 인상 채득법 중 Pick up impression(Open tray)이 갖는 장점은?',
    options:      ['입을 적게 벌려도 됨', '인상체 변형 및 오차가 매우 적음', '전용 코핑이 필요 없음', '기공 과정이 단순함'],
    correctIndex: 1,
    explanation:  '코핑이 인상재 안에 고정된 채로 구강 밖으로 나오기 때문에 위치 오차가 거의 없는 정밀한 방법입니다.',
    sourcePage:   '102',
  },
  {
    question:     '임플란트 유지 방식 중 SCRP type의 구조적 특징으로 옳은 것은?',
    options:      ['나사 홀이 없어 심미적임', 'Fixture, Abutment, Crown이 모두 분리됨', '접착제만으로 유지됨', '재제작이 불가능함'],
    correctIndex: 1,
    explanation:  'SCRP 방식은 나사와 접착 방식을 혼용하며 모든 구성 요소가 분리되어 유지보수가 용이합니다.',
    sourcePage:   '83',
  },
  {
    question:     '임플란트 보철 최종 장착 시 토크 렌치로 조인 후 5~10분을 기다렸다가 다시 조이는 이유는?',
    options:      ['환자의 턱 근육 휴식', '나사 풀림(Screw loosening) 현상 방지', '접착제의 완전 경화 대기', '잇몸의 지혈 확인'],
    correctIndex: 1,
    explanation:  '1차로 조인 후 일정 시간 뒤 다시 조여주는(Retorque) 과정이 나사 풀림 방지에 효과적이라는 연구 결과에 근거합니다.',
    sourcePage:   '83',
  },
  {
    question:     '임플란트 오버덴쳐(OverDenture)가 일반 완전틀니에 비해 갖는 생리학적 장점은?',
    options:      ['자연치와 100% 동일한 저작력', '탁월한 유지력 및 안면부 심미 개선', '보험 적용을 통한 비용 면제', '잇몸뼈 흡수 전면 차단'],
    correctIndex: 1,
    explanation:  '임플란트가 지지해주므로 틀니가 잘 빠지지 않고 의치상에 의해 입술 주변 안모 회복 효과가 뛰어납니다.',
    sourcePage:   '84',
  },
  {
    question:     '이른바 똑딱이 틀니로 불리며 하악에 2~4개 식립하여 사용하는 장치의 명칭은?',
    options:      ['Hader bar', 'Locator attachment', 'Ball clasp', 'Magnetic type'],
    correctIndex: 1,
    explanation:  '로케이터(Locator)는 단추처럼 끼우는 방식으로 가장 대중적으로 쓰이는 오버덴쳐 장치입니다.',
    sourcePage:   '88',
  },
  {
    question:     '오버덴쳐 어태치먼트 중 Bar attachment를 제작하기 전 인공치 임의 배열을 거치는 이유는?',
    options:      ['인공치의 강도 테스트', '상부 구조물과 인공치가 들어갈 공간 확인', '환자의 식사 습관 파악', '치석 부착 방지'],
    correctIndex: 1,
    explanation:  '바(Bar)는 부피가 크므로 틀니 내부에 들어갈 충분한 수직 공간(VD)이 있는지 미리 확인해야 합니다.',
    sourcePage:   '97',
  },
  {
    question:     '로케이터(Locator) 연결 시 Block out spacer(하얀 링)가 수행하는 기능은?',
    options:      ['시멘트의 역류 방지', '어버트먼트와 하우징 사이 간극 형성', '잇몸의 출혈 억제', '임플란트 픽스쳐 보호'],
    correctIndex: 1,
    explanation:  '화이트 링은 하우징과 어버트먼트 사이에 일정한 틈을 만들어 틀니가 너무 빡빡하지 않게 해줍니다.',
    sourcePage:   '98',
  },
];

// ══════════════════════════════════════════════════════════════
// 시드 함수
// ══════════════════════════════════════════════════════════════

async function seedQuizPool() {
  console.log('🚀 quiz_pool 시드 시작...\n');

  const poolRef = db.collection('quiz_pool');
  const now     = admin.firestore.Timestamp.now();

  // ── 1. 기존 데이터 삭제 ──
  console.log('🗑️  기존 quiz_pool 문서 삭제 중...');
  const existing = await poolRef.get();
  const deleteBatch = db.batch();
  existing.docs.forEach((doc) => deleteBatch.delete(doc.ref));
  await deleteBatch.commit();
  console.log(`   삭제 완료: ${existing.size}개\n`);

  // ── 2. 임플란트 문제 저장 ──
  console.log('📝 임플란트 초보탈출 문제 저장 중...');
  let order = 1;
  for (const q of implantQuizzes) {
    await poolRef.add({
      order,
      question:        q.question,
      options:         q.options,
      correctIndex:    q.correctIndex,
      explanation:     q.explanation,
      category:        '임플란트',
      difficulty:      'intermediate',
      sourceBook:      IMPLANT_BOOK,
      sourceFileName:  '저연차_치과위생사를_위한_임플란트_초보탈출.pdf',
      sourcePage:      q.sourcePage,
      isActive:        true,
      lastCycleServed: 0,
      createdAt:       now,
      updatedAt:       now,
    });
    process.stdout.write(`   [${order}/${implantQuizzes.length}] ${q.question.substring(0, 30)}...\r`);
    order++;
  }
  console.log(`\n   ✅ 임플란트 문제 ${implantQuizzes.length}개 저장 완료\n`);

  // ── 3. 보철과 문제 저장 ──
  console.log('📝 보철과 문제 저장 중...');
  for (const q of prostheticQuizzes) {
    await poolRef.add({
      order,
      question:        q.question,
      options:         q.options,
      correctIndex:    q.correctIndex,
      explanation:     q.explanation,
      category:        '보철',
      difficulty:      'intermediate',
      sourceBook:      PROSTHETIC_BOOK,
      sourceFileName:  '알고보면_재미있는_보철과.pdf',
      sourcePage:      q.sourcePage,
      isActive:        true,
      lastCycleServed: 0,
      createdAt:       now,
      updatedAt:       now,
    });
    process.stdout.write(`   [${order - implantQuizzes.length}/${prostheticQuizzes.length}] ${q.question.substring(0, 30)}...\r`);
    order++;
  }
  console.log(`\n   ✅ 보철과 문제 ${prostheticQuizzes.length}개 저장 완료\n`);

  // ── 4. quiz_meta/state 초기화 ──
  console.log('📊 quiz_meta/state 초기화...');
  await db.doc('quiz_meta/state').set({
    currentOrder:      1,
    cycleCount:        1,
    totalActiveCount:  implantQuizzes.length + prostheticQuizzes.length,
    lastScheduledDate: '',
    dailyCount:        2,
    usedQuizIds:       [],
    bookRotation:      [IMPLANT_BOOK, PROSTHETIC_BOOK],
  });
  console.log('   ✅ quiz_meta/state 초기화 완료\n');

  const total = implantQuizzes.length + prostheticQuizzes.length;
  console.log('═══════════════════════════════════════════');
  console.log(`✅ 시드 완료! 총 ${total}문제 저장됨`);
  console.log(`   임플란트: ${implantQuizzes.length}문제 (order 1~${implantQuizzes.length})`);
  console.log(`   보철과:   ${prostheticQuizzes.length}문제 (order ${implantQuizzes.length + 1}~${total})`);
  console.log(`   하루 배포: 2문제 (각 책에서 1개씩 랜덤)`);
  console.log(`   예상 사이클: ${Math.floor(Math.min(implantQuizzes.length, prostheticQuizzes.length))}일`);
  console.log('═══════════════════════════════════════════');

  process.exit(0);
}

seedQuizPool().catch((err) => {
  console.error('❌ 시드 실패:', err);
  process.exit(1);
});

