import '../models/job.dart';
import '../models/transportation_info.dart';

/// `assets/clinic picture sample/` 샘플 이미지 (파일명 정렬). L1/L2 목업 글당 1장.
const kClinicPictureSampleAssets = <String>[
  'assets/clinic picture sample/Gemini_Generated_Image_20w5tk20w5tk20w5.png',
  'assets/clinic picture sample/Gemini_Generated_Image_3153lj3153lj3153.png',
  'assets/clinic picture sample/Gemini_Generated_Image_3xnqzv3xnqzv3xnq.png',
  'assets/clinic picture sample/Gemini_Generated_Image_5j05xf5j05xf5j05.png',
  'assets/clinic picture sample/Gemini_Generated_Image_7xgf4b7xgf4b7xgf.png',
  'assets/clinic picture sample/Gemini_Generated_Image_9vzan69vzan69vza.png',
  'assets/clinic picture sample/Gemini_Generated_Image_nnr4tmnnr4tmnnr4.png',
  'assets/clinic picture sample/Gemini_Generated_Image_qftaltqftaltqfta.png',
  'assets/clinic picture sample/Gemini_Generated_Image_tzngjvtzngjvtzng.png',
  'assets/clinic picture sample/Gemini_Generated_Image_z7qwtwz7qwtwz7qw.png',
];

/// 레벨1/2/3 공고 Mock 데이터
///
/// 웹 구인 폼(`JobPostData`)과 동일 항목을 갖추도록 구성:
/// 치과명·제목·직무(type)·고용형태·근무시간·급여(salaryRange + salaryText)·복리·상세(details)·주소·연락처
/// 급여 [min,max]는 만원 단위.

final List<Job> mockLevel1Jobs = [
  Job(
    id: 'mock_l1_4',
    title: '데스크 코디네이터 채용',
    clinicName: '신촌연합치과',
    address: '서울 서대문구 창천동 456-7',
    district: '창천동 · 서대문구',
    lat: 37.556,
    lng: 126.937,
    type: '데스크',
    career: '1년 이상',
    salaryRange: [250, 300],
    salaryText: '월 250~300만원 (경력 반영)',
    employmentType: '정규직',
    workHours: '10:00~19:00 (월~금), 토 격주',
    contact: '02-2004-1004',
    postedAt: DateTime.now().subtract(const Duration(days: 3)),
    details:
        '전화·온라인 예약 접수, 내원 환자 응대, 수납 및 보험 청구 관련 업무를 담당합니다. '
        '진료 안내와 대기 순서 관리, 간단한 서류 발급 등 프런트 전반을 맡게 됩니다. '
        '치과 데스크 또는 의료기관 유사 업무 경험이 있으면 우대합니다. '
        '정확하고 친절한 커뮤니케이션이 가능한 분을 환영합니다.',
    benefits: ['4대보험', '퇴직금', '명절상여', '주5일', '식비지원'],
    images: [kClinicPictureSampleAssets[3]],
    jobLevel: 1,
    matchScore: 52,
    isNearStation: true,
    closingDate: DateTime.now().add(const Duration(days: 10)),
    canApplyNow: true,
    // 기본 정보 추가
    education: '대졸 이상 (무관)',
    hireRoles: ['데스크', '코디네이터'],
    // 병원 정보
    hospitalType: 'clinic',
    chairCount: 3,
    staffCount: 5,
    specialties: ['임플란트', '보철', '일반진료'],
    hasOralScanner: true,
    hasCT: true,
    has3DPrinter: false,
    // 근무 조건
    workDays: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'],
    weekendWork: true,
    nightShift: false,
    // 지원 관련
    applyMethod: ['online', 'phone', 'email'],
    isAlwaysHiring: false,
    requiredDocuments: ['이력서', '자기소개서'],
    // 담당 업무
    mainDutiesList: ['예약·취소 접수 처리', '내원 환자 응대', '수납 및 보험 청구', '진료실 안내', '서류 발급'],
    // 교통편
    transportation: const TransportationInfo(
      subwayLines: ['2호선'],
      subwayStationName: '신촌역',
      walkingDistanceMeters: 320,
      walkingMinutes: 5,
      exitNumber: '2번 출구',
      parking: false,
    ),
    subwayLines: ['2호선'],
    hasParking: false,
    tags: ['4대보험', '퇴직금', '명절상여', '주5일', '야간없음', '역세권', '즉시지원'],
  ),
  Job(
    id: 'mock_l1_5',
    title: '치과위생사 신입/경력 모집',
    clinicName: '잠실베스트치과',
    address: '서울 송파구 잠실동 567-8',
    district: '잠실동 · 송파구',
    lat: 37.513,
    lng: 127.100,
    type: '치위생사',
    career: '신입/경력',
    salaryRange: [270, 330],
    salaryText: '월 270~330만원 (신입·경력 협의)',
    employmentType: '정규직',
    workHours: '평일 09:00~18:00, 잠실역 도보 8분',
    contact: '02-2005-1005',
    postedAt: DateTime.now().subtract(const Duration(days: 4)),
    details:
        '예방·보존 진료 위주 클리닉으로 스케일링, 플루오라이드 도포, 진료 보조를 주 업무로 합니다. '
        '신입은 수습 기간 중 OJT로 진료 흐름을 익히게 됩니다. '
        '경력자는 담당 체어 운영과 재료·재고 관리까지 맡을 수 있습니다. '
        '잠실역 도보권으로 대중교통 이용이 편리합니다.',
    benefits: ['4대보험', '연차', '식비지원'],
    images: [kClinicPictureSampleAssets[4]],
    jobLevel: 1,
    matchScore: 79,
    isNearStation: true,
    closingDate: null,
    canApplyNow: true,
    hospitalType: 'network',
    chairCount: 6,
    staffCount: 10,
    workDays: ['mon', 'tue', 'wed', 'thu', 'fri'],
    weekendWork: false,
    nightShift: false,
    applyMethod: ['online', 'phone'],
    isAlwaysHiring: true,
    transportation: const TransportationInfo(
      subwayLines: ['2호선', '8호선'],
      subwayStationName: '잠실역',
      walkingDistanceMeters: 640,
      walkingMinutes: 8,
      exitNumber: '6번 출구',
      parking: true,
    ),
    subwayLines: ['2호선', '8호선'],
    hasParking: true,
    tags: ['4대보험', '연차', '식비지원', '주5일', '야간없음', '역세권', '즉시지원'],
  ),
  Job(
    id: 'mock_l1_6',
    title: '간호조무사 모집 (신입 환영)',
    clinicName: '건대좋은치과',
    address: '서울 광진구 화양동 678-9',
    district: '화양동 · 광진구',
    lat: 37.541,
    lng: 127.070,
    type: '간호조무사',
    career: '신입 가능',
    salaryRange: [240, 280],
    salaryText: '월 240~280만원 (수습 후 조정)',
    employmentType: '정규직',
    workHours: '09:00~18:00 (주 5일)',
    contact: '02-2006-1006',
    postedAt: DateTime.now().subtract(const Duration(days: 5)),
    details:
        '접수·안내, 진료실 보조, 기구 준비 및 소독, 방사선 촬영 보조 업무를 합니다. '
        '신입도 면허 취득 후 성실히 배우실 의지가 있으시면 지원 가능합니다. '
        '주 5일 근무이며 기본 교육과 함께 단계별 업무를 배정합니다. '
        '꾸준히 성장하고 싶은 조무사 지망생을 응원합니다.',
    benefits: ['4대보험', '교육지원', '주5일'],
    images: [kClinicPictureSampleAssets[5]],
    jobLevel: 1,
    matchScore: 45,
    isNearStation: true,
    closingDate: DateTime.now().add(const Duration(days: 30)),
    canApplyNow: false,
    hospitalType: 'clinic',
    chairCount: 3,
    staffCount: 5,
    workDays: ['mon', 'tue', 'wed', 'thu', 'fri'],
    weekendWork: false,
    nightShift: false,
    applyMethod: ['online', 'phone'],
    isAlwaysHiring: false,
    transportation: const TransportationInfo(
      subwayLines: ['2호선'],
      subwayStationName: '건대입구역',
      walkingDistanceMeters: 400,
      walkingMinutes: 6,
      exitNumber: '5번 출구',
      parking: false,
    ),
    subwayLines: ['2호선'],
    hasParking: false,
    tags: ['4대보험', '교육지원', '주5일', '야간없음', '역세권', '신입가능', '즉시지원'],
  ),
  Job(
    id: 'mock_l1_7',
    title: '치위생사/원장보조 채용',
    clinicName: '영등포밝은치과',
    address: '서울 영등포구 당산동 789-0',
    district: '당산동 · 영등포구',
    lat: 37.533,
    lng: 126.901,
    type: '치위생사',
    career: '경력 2년 이상',
    salaryRange: [320, 400],
    salaryText: '월 320~400만원 + 성과급 (경력별)',
    employmentType: '정규직',
    workHours: '08:30~17:30 또는 09:00~18:00 (면접 협의)',
    contact: '02-2007-1007',
    postedAt: DateTime.now().subtract(const Duration(days: 6)),
    details:
        '진료 보조와 스케일링 등 위생 업무 외에 원장 일정·내원 조율, 간행물·서류 정리 등 보조 업무가 포함될 수 있습니다. '
        '다양한 진료과목이 운영되어 업무 폭이 넓은 편입니다. '
        '성과에 따른 인센티브 제도를 운영 중입니다. '
        '책임감 있게 소통 가능한 경력 치위생사를 모십니다.',
    benefits: ['4대보험', '퇴직금', '성과급'],
    images: [kClinicPictureSampleAssets[6]],
    jobLevel: 1,
    matchScore: 91,
    isNearStation: false,
    closingDate: DateTime.now().add(const Duration(days: 5)),
    canApplyNow: true,
    hospitalType: 'hospital',
    chairCount: 10,
    staffCount: 18,
    workDays: ['mon', 'tue', 'wed', 'thu', 'fri'],
    weekendWork: false,
    nightShift: false,
    applyMethod: ['online', 'email', 'phone'],
    isAlwaysHiring: false,
    transportation: const TransportationInfo(
      subwayLines: ['2호선', '9호선'],
      subwayStationName: '당산역',
      walkingDistanceMeters: 1100,
      walkingMinutes: 14,
      exitNumber: '1번 출구',
      parking: true,
    ),
    subwayLines: ['2호선', '9호선'],
    hasParking: true,
    tags: ['4대보험', '퇴직금', '성과급', '주5일', '야간없음', '즉시지원'],
  ),
  Job(
    id: 'mock_l1_8',
    title: '치과위생사 정규직',
    clinicName: '이수바른치과',
    address: '서울 동작구 사당동 890-1',
    district: '사당동 · 동작구',
    lat: 37.476,
    lng: 126.982,
    type: '치위생사',
    career: '1~3년',
    salaryRange: [290, 360],
    salaryText: '월 290~360만원 (야간 1회 시 수당)',
    employmentType: '정규직',
    workHours: '주 5일, 야간 진료 주 1회(면접 시 확정)',
    contact: '02-2008-1008',
    postedAt: DateTime.now().subtract(const Duration(days: 7)),
    details:
        '체어별 진료 보조, 감염 관리, 환자 교육(칫솔질·치간 관리 등)을 담당합니다. '
        '1~3년 차 경력자에게 맞춘 업무 난도로 배정하며, 연차 사용이 자유로운 분위기입니다. '
        '주 5일, 점심시간 보장. 야간 진료는 주 1회 수준입니다(면접 시 확정). '
        '사당 인근 거주자도 출퇴근하기 좋은 위치입니다.',
    benefits: ['4대보험', '연차', '주5일'],
    images: [kClinicPictureSampleAssets[7]],
    jobLevel: 1,
    matchScore: 68,
    isNearStation: true,
    closingDate: null,
    canApplyNow: true,
    hospitalType: 'clinic',
    chairCount: 5,
    staffCount: 7,
    workDays: ['mon', 'tue', 'wed', 'thu', 'fri'],
    weekendWork: false,
    nightShift: true,
    applyMethod: ['online', 'phone'],
    isAlwaysHiring: false,
    transportation: const TransportationInfo(
      subwayLines: ['2호선', '4호선'],
      subwayStationName: '사당역',
      walkingDistanceMeters: 420,
      walkingMinutes: 6,
      exitNumber: '4번 출구',
      parking: false,
    ),
    subwayLines: ['2호선', '4호선'],
    hasParking: false,
    tags: ['4대보험', '연차', '주5일', '역세권', '즉시지원'],
  ),
  // ── 지역 프리미엄 (경기·대전·전남) ─────────────────────────────
  Job(
    id: 'mock_l1_9',
    title: '치위생사 정규직 모집 (수원)',
    clinicName: '수원팔달스마일치과',
    address: '경기 수원시 팔달구 인계동 100-1',
    district: '인계동 · 수원시',
    lat: 37.263,
    lng: 127.028,
    type: '치위생사',
    career: '신입/경력',
    salaryRange: [270, 340],
    salaryText: '월 270~340만원 (면접 협의)',
    employmentType: '정규직',
    workHours: '평일 09:00~18:00',
    contact: '031-2001-2001',
    postedAt: DateTime.now().subtract(const Duration(days: 1)),
    details:
        '수원 팔달구 인계동 인근 치과에서 치위생사를 모집합니다. '
        '스케일링·진료 보조·감염 관리를 담당합니다.',
    benefits: ['4대보험', '주5일', '교육지원'],
    images: [
      kClinicPictureSampleAssets[8],
      kClinicPictureSampleAssets[9],
    ],
    jobLevel: 1,
    matchScore: 82,
    isNearStation: true,
    closingDate: DateTime.now().add(const Duration(days: 12)),
    canApplyNow: true,
    hospitalType: 'clinic',
    chairCount: 5,
    staffCount: 8,
    workDays: ['mon', 'tue', 'wed', 'thu', 'fri'],
    weekendWork: false,
    nightShift: false,
    applyMethod: ['online', 'phone'],
    isAlwaysHiring: false,
    transportation: const TransportationInfo(
      subwayLines: ['수인분당선'],
      subwayStationName: '인계역',
      walkingDistanceMeters: 400,
      walkingMinutes: 5,
      exitNumber: '2번 출구',
      parking: true,
    ),
    subwayLines: ['수인분당선'],
    hasParking: true,
    tags: ['4대보험', '주5일', '역세권', '즉시지원'],
  ),
  Job(
    id: 'mock_l1_10',
    title: '치과위생사 채용 (대전 유성)',
    clinicName: '대전유성연합치과',
    address: '대전 유성구 봉명동 300-3',
    district: '봉명동 · 유성구',
    lat: 36.362,
    lng: 127.344,
    type: '치위생사',
    career: '1년 이상',
    salaryRange: [280, 350],
    salaryText: '월 280~350만원',
    employmentType: '정규직',
    workHours: '09:00~18:30 (주 5일)',
    contact: '042-2002-2002',
    postedAt: DateTime.now().subtract(const Duration(days: 2)),
    details:
        '대전 유성구 봉명동에서 치과위생사를 채용합니다. '
        '임플란트·보철 진료 보조 경험자 우대.',
    benefits: ['4대보험', '퇴직금', '연차'],
    images: [kClinicPictureSampleAssets[0]],
    jobLevel: 1,
    matchScore: 79,
    isNearStation: true,
    closingDate: DateTime.now().add(const Duration(days: 18)),
    canApplyNow: true,
    hospitalType: 'network',
    chairCount: 7,
    staffCount: 11,
    workDays: ['mon', 'tue', 'wed', 'thu', 'fri'],
    weekendWork: false,
    nightShift: false,
    applyMethod: ['online', 'email'],
    isAlwaysHiring: false,
    transportation: const TransportationInfo(
      subwayLines: ['1호선'],
      subwayStationName: '봉명역',
      walkingDistanceMeters: 520,
      walkingMinutes: 7,
      exitNumber: '1번 출구',
      parking: false,
    ),
    subwayLines: ['1호선'],
    hasParking: false,
    tags: ['4대보험', '퇴직금', '역세권', '즉시지원'],
  ),
  Job(
    id: 'mock_l1_11',
    title: '간호조무사·위생사 (목포)',
    clinicName: '목포바다치과의원',
    address: '전남 목포시 상동 700-7',
    district: '상동 · 목포시',
    lat: 34.811,
    lng: 126.392,
    type: '치위생사',
    career: '경력 무관',
    salaryRange: [250, 310],
    salaryText: '월 250~310만원',
    employmentType: '정규직',
    workHours: '09:30~18:30',
    contact: '061-2003-2003',
    postedAt: DateTime.now().subtract(const Duration(days: 3)),
    details:
        '전남 목포에서 치위생사·조무사를 모집합니다. '
        '지원 직종에 따라 면접 시 배치합니다.',
    benefits: ['4대보험', '주5일'],
    images: [
      kClinicPictureSampleAssets[2],
      kClinicPictureSampleAssets[3],
    ],
    jobLevel: 1,
    matchScore: 71,
    isNearStation: false,
    closingDate: null,
    canApplyNow: false,
    hospitalType: 'clinic',
    chairCount: 4,
    staffCount: 6,
    workDays: ['mon', 'tue', 'wed', 'thu', 'fri'],
    weekendWork: false,
    nightShift: false,
    applyMethod: ['phone', 'email'],
    isAlwaysHiring: true,
    transportation: const TransportationInfo(
      subwayLines: [],
      subwayStationName: null,
      walkingDistanceMeters: 1200,
      walkingMinutes: 15,
      exitNumber: null,
      parking: true,
    ),
    subwayLines: const [],
    hasParking: true,
    tags: ['4대보험', '주5일', '야간없음'],
  ),
];

final List<Job> mockLevel2Jobs = [
  Job(
    id: 'mock_l2_1',
    title: '치과위생사 신입 모집',
    clinicName: '마포웃는치과',
    address: '서울 마포구 합정동 111-1',
    district: '합정동 · 마포구',
    lat: 37.549,
    lng: 126.913,
    type: '치위생사',
    career: '신입',
    salaryRange: [250, 290],
    salaryText: '월 250~290만원 (수습 OJT)',
    employmentType: '정규직',
    workHours: '09:00~18:00 (주 5일)',
    contact: '02-2010-1010',
    postedAt: DateTime.now().subtract(const Duration(days: 3)),
    details:
        '신규 면허 취득자를 위한 체계적 OJT를 제공합니다. '
        '스케일링 보조부터 시작해 점진적으로 진료 보조 범위를 넓혀 갑니다. '
        '선배 위생사님과 1:1 멘토링으로 적응을 돕습니다. '
        '밝고 배우려는 자세만 있다면 환영합니다.',
    benefits: ['4대보험', '주5일'],
    images: [kClinicPictureSampleAssets[0]],
    jobLevel: 2,
    matchScore: 71,
    isNearStation: true,
    closingDate: DateTime.now().add(const Duration(days: 20)),
    canApplyNow: false,
    hospitalType: 'clinic',
    workDays: ['mon', 'tue', 'wed', 'thu', 'fri'],
    weekendWork: false,
    nightShift: false,
    applyMethod: ['online'],
    transportation: const TransportationInfo(
      subwayLines: ['2호선', '6호선'],
      subwayStationName: '합정역',
      walkingDistanceMeters: 350,
      walkingMinutes: 5,
      exitNumber: '3번 출구',
      parking: false,
    ),
    subwayLines: ['2호선', '6호선'],
    hasParking: false,
    chairCount: 4,
    staffCount: 6,
    tags: ['4대보험', '주5일', '야간없음', '역세권', '신입가능', '즉시지원'],
  ),
  Job(
    id: 'mock_l2_2',
    title: '간호조무사 경력직',
    clinicName: '성수연세치과',
    address: '서울 성동구 성수동 222-2',
    district: '성수동 · 성동구',
    lat: 37.545,
    lng: 127.056,
    type: '간호조무사',
    career: '1년 이상',
    salaryRange: [260, 300],
    salaryText: '월 260~300만원',
    employmentType: '정규직',
    workHours: '09:30~18:30',
    contact: '02-2011-1011',
    postedAt: DateTime.now().subtract(const Duration(days: 2)),
    details:
        '수납·예약 관리, 진료실 기구 준비, 방사선 촬영, 멸균실 관리 등 조무사 표준 업무를 수행합니다. '
        '1년 이상 실무 경험자를 우대하며, 성수역 인근 직장인 환자 비중이 높습니다. '
        '점심 식대 일부 지원. 퇴직금·4대보험 적용. '
        '꼼꼼한 성격과 시간 약속을 지키시는 분과 일하고 싶습니다.',
    benefits: ['4대보험', '퇴직금', '식비'],
    images: [kClinicPictureSampleAssets[1]],
    jobLevel: 2,
    matchScore: 65,
    isNearStation: true,
    closingDate: null,
    canApplyNow: true,
    hospitalType: 'hospital',
    chairCount: 12,
    staffCount: 20,
    workDays: ['mon', 'tue', 'wed', 'thu', 'fri'],
    weekendWork: false,
    nightShift: true,
    applyMethod: ['online', 'phone', 'email'],
    isAlwaysHiring: true,
    transportation: const TransportationInfo(
      subwayLines: ['2호선'],
      subwayStationName: '성수역',
      walkingDistanceMeters: 200,
      walkingMinutes: 3,
      exitNumber: '3번 출구',
      parking: true,
    ),
    subwayLines: ['2호선'],
    hasParking: true,
    tags: ['4대보험', '퇴직금', '주5일', '역세권', '즉시지원', '야간없음'],
  ),
  Job(
    id: 'mock_l2_3',
    title: '치과 데스크 직원 채용',
    clinicName: '목동행복치과',
    address: '서울 양천구 목동 333-3',
    district: '목동 · 양천구',
    lat: 37.527,
    lng: 126.866,
    type: '데스크',
    career: '경력 무관',
    salaryRange: [240, 280],
    salaryText: '월 240~280만원',
    employmentType: '정규직',
    workHours: '10:00~19:00',
    contact: '02-2012-1012',
    postedAt: DateTime.now().subtract(const Duration(days: 4)),
    details:
        '데스크 전담으로 예약·취소 처리, 초진 상담 안내, 수납 및 카드·현금 정산을 맡습니다. '
        '경력 무관이나 서비스업·콜센터 경험은 플러스 요인입니다. '
        '컴퓨터 기본 활용(엑셀·예약 프로그램)을 익힐 의지가 있으면 됩니다. '
        '주민·가족 단위 환자가 많아 친절한 응대가 중요합니다.',
    benefits: ['4대보험', '연차'],
    images: [kClinicPictureSampleAssets[2]],
    jobLevel: 2,
    matchScore: 58,
    isNearStation: false,
    closingDate: DateTime.now().add(const Duration(days: 15)),
    canApplyNow: false,
    hospitalType: 'clinic',
    chairCount: 3,
    staffCount: 5,
    workDays: ['mon', 'tue', 'wed', 'thu', 'fri'],
    weekendWork: false,
    nightShift: false,
    applyMethod: ['online', 'phone'],
    isAlwaysHiring: false,
    transportation: const TransportationInfo(
      subwayLines: ['5호선'],
      subwayStationName: '목동역',
      walkingDistanceMeters: 950,
      walkingMinutes: 12,
      exitNumber: '7번 출구',
      parking: false,
    ),
    subwayLines: ['5호선'],
    hasParking: false,
    tags: ['4대보험', '연차', '주5일', '야간없음', '즉시지원'],
  ),
  Job(
    id: 'mock_l2_4',
    title: '치위생사 정규직 (오전반)',
    clinicName: '은평새싹치과',
    address: '서울 은평구 불광동 444-4',
    district: '불광동 · 은평구',
    lat: 37.618,
    lng: 126.929,
    type: '치위생사',
    career: '1~5년',
    salaryRange: [270, 330],
    salaryText: '월 270~330만원 (오전 집중 근무)',
    employmentType: '정규직',
    workHours: '08:00~15:00 전후 (면접 시 확정)',
    contact: '02-2013-1013',
    postedAt: DateTime.now().subtract(const Duration(days: 5)),
    details:
        '오전 시간대 집중 진료(약 8시~15시 전후)로 스케줄이 고정되어 있어 저녁 여유를 원하시는 분께 적합합니다. '
        '스케일링·진료 보조·감염 관리를 담당합니다. '
        '식비 지원과 연차는 규정에 따라 사용 가능합니다. '
        '육아 병행 등 오전 근무를 희망하는 위생사님도 지원해 주세요.',
    benefits: ['4대보험', '식비지원', '연차'],
    images: [kClinicPictureSampleAssets[3]],
    jobLevel: 2,
    matchScore: 76,
    isNearStation: true,
    closingDate: null,
    canApplyNow: true,
    hospitalType: 'clinic',
    chairCount: 4,
    staffCount: 6,
    workDays: ['mon', 'tue', 'wed', 'thu', 'fri'],
    weekendWork: false,
    nightShift: false,
    applyMethod: ['online', 'email'],
    isAlwaysHiring: true,
    transportation: const TransportationInfo(
      subwayLines: ['3호선', '6호선'],
      subwayStationName: '불광역',
      walkingDistanceMeters: 380,
      walkingMinutes: 5,
      exitNumber: '5번 출구',
      parking: true,
    ),
    subwayLines: ['3호선', '6호선'],
    hasParking: true,
    tags: ['4대보험', '식비지원', '연차', '주5일', '야간없음', '역세권', '즉시지원'],
  ),
  Job(
    id: 'mock_l2_5',
    title: '치과위생사 채용 (상주 보철)',
    clinicName: '강동드림치과',
    address: '서울 강동구 천호동 555-5',
    district: '천호동 · 강동구',
    lat: 37.538,
    lng: 127.123,
    type: '치위생사',
    career: '3년 이상',
    salaryRange: [310, 390],
    salaryText: '월 310~390만원 + 성과급',
    employmentType: '정규직',
    workHours: '09:00~18:30',
    contact: '02-2014-1014',
    postedAt: DateTime.now().subtract(const Duration(days: 6)),
    details:
        '크라운·브릿지 등 보철 진료 비중이 높아 인상 채득 보조, 임시치아 관리, 보철물 시착 보조 등 세심한 업무가 포함됩니다. '
        '상주 기공소와 협업이 잦아 커뮤니케이션 능력이 중요합니다. '
        '3년 이상 경력자 우대, 성과급 별도. '
        '보철 진료에 자신 있는 분의 지원을 기다립니다.',
    benefits: ['4대보험', '퇴직금', '성과급'],
    images: [kClinicPictureSampleAssets[4]],
    jobLevel: 2,
    matchScore: 82,
    isNearStation: false,
    closingDate: DateTime.now().add(const Duration(days: 8)),
    canApplyNow: true,
    hospitalType: 'network',
    chairCount: 8,
    staffCount: 14,
    workDays: ['mon', 'tue', 'wed', 'thu', 'fri'],
    weekendWork: false,
    nightShift: false,
    applyMethod: ['online', 'phone', 'email'],
    isAlwaysHiring: false,
    transportation: const TransportationInfo(
      subwayLines: ['5호선', '8호선'],
      subwayStationName: '천호역',
      walkingDistanceMeters: 1050,
      walkingMinutes: 13,
      exitNumber: '2번 출구',
      parking: true,
    ),
    subwayLines: ['5호선', '8호선'],
    hasParking: true,
    tags: ['4대보험', '퇴직금', '성과급', '주5일', '야간없음', '즉시지원'],
  ),
  Job(
    id: 'mock_l2_6',
    title: '간호조무사 신입 우대',
    clinicName: '중랑행복치과',
    address: '서울 중랑구 면목동 666-6',
    district: '면목동 · 중랑구',
    lat: 37.589,
    lng: 127.086,
    type: '간호조무사',
    career: '신입',
    salaryRange: [230, 270],
    salaryText: '월 230~270만원 (교육 지원)',
    employmentType: '정규직',
    workHours: '09:00~18:00',
    contact: '02-2015-1015',
    postedAt: DateTime.now().subtract(const Duration(days: 7)),
    details:
        '신입 조무사를 위한 단계별 교육 일정을 마련해 두었습니다. '
        '접수·안내부터 방사선·소독 업무까지 순차적으로 배우게 됩니다. '
        '질문을 편하게 할 수 있는 분위기를 지향합니다. '
        '면허만 있으면 지원 가능하며, 인근 거주자 우대합니다.',
    benefits: ['4대보험', '교육지원'],
    images: [kClinicPictureSampleAssets[5]],
    jobLevel: 2,
    matchScore: 49,
    isNearStation: true,
    closingDate: null,
    canApplyNow: false,
    hospitalType: 'clinic',
    chairCount: 3,
    staffCount: 4,
    workDays: ['mon', 'tue', 'wed', 'thu', 'fri'],
    weekendWork: false,
    nightShift: false,
    applyMethod: ['online', 'phone'],
    isAlwaysHiring: false,
    transportation: const TransportationInfo(
      subwayLines: ['7호선'],
      subwayStationName: '면목역',
      walkingDistanceMeters: 480,
      walkingMinutes: 6,
      exitNumber: '1번 출구',
      parking: false,
    ),
    subwayLines: ['7호선'],
    hasParking: false,
    tags: ['4대보험', '교육지원', '주5일', '야간없음', '역세권', '신입가능', '즉시지원'],
  ),
  Job(
    id: 'mock_l2_7',
    title: '치위생사 경력 우대',
    clinicName: '강서미래치과',
    address: '서울 강서구 화곡동 777-7',
    district: '화곡동 · 강서구',
    lat: 37.548,
    lng: 126.848,
    type: '치위생사',
    career: '2년 이상',
    salaryRange: [290, 350],
    salaryText: '월 290~350만원',
    employmentType: '정규직',
    workHours: '주 5일, 야간 주 1~2회 협의',
    contact: '02-2016-1016',
    postedAt: DateTime.now().subtract(const Duration(days: 8)),
    details:
        '2년 이상 실무 경력자를 우대하며, 자가 치석제거·아동 진료 보조 등 다양한 케이스를 경험할 수 있습니다. '
        '주 5일, 퇴직금·4대보험. '
        '야간 진료 시 스케줄은 주 1~2회 내외로 조정 가능합니다. '
        '꾸준한 자기계발을 지원하는 클리닉입니다.',
    benefits: ['4대보험', '퇴직금', '주5일'],
    images: [kClinicPictureSampleAssets[6]],
    jobLevel: 2,
    matchScore: 70,
    isNearStation: true,
    closingDate: DateTime.now().add(const Duration(days: 12)),
    canApplyNow: true,
    hospitalType: 'clinic',
    chairCount: 5,
    staffCount: 8,
    workDays: ['mon', 'tue', 'wed', 'thu', 'fri'],
    weekendWork: false,
    nightShift: true,
    applyMethod: ['online', 'phone', 'email'],
    isAlwaysHiring: false,
    transportation: const TransportationInfo(
      subwayLines: ['5호선'],
      subwayStationName: '화곡역',
      walkingDistanceMeters: 520,
      walkingMinutes: 7,
      exitNumber: '2번 출구',
      parking: false,
    ),
    subwayLines: ['5호선'],
    hasParking: false,
    tags: ['4대보험', '퇴직금', '주5일', '역세권', '즉시지원'],
  ),
  Job(
    id: 'mock_l2_8',
    title: '치과 원장 보조 채용',
    clinicName: '도봉푸른치과',
    address: '서울 도봉구 창동 888-8',
    district: '창동 · 도봉구',
    lat: 37.653,
    lng: 127.046,
    type: '기타',
    career: '경력 무관',
    salaryRange: [250, 300],
    salaryText: '월 250~300만원 (행정·보조)',
    employmentType: '계약직',
    workHours: '09:00~18:00 (수습 후 정규 전환 검토)',
    contact: '02-2017-1017',
    postedAt: DateTime.now().subtract(const Duration(days: 9)),
    details:
        '원장 일정 관리, 내·외부 연락, 간단한 문서 작성, 진료실 비품 발주 등 행정·보조 업무를 맡습니다. '
        '치과 용어에 익숙해지면 진료 보조 일부를 함께 배울 수 있습니다. '
        '직종은 \'기타\'로 표기되나 실제는 코디네이터에 가깝습니다. '
        '꼼꼼하고 신뢰감 있는 분을 찾습니다.',
    benefits: ['4대보험', '연차', '식비'],
    images: [kClinicPictureSampleAssets[7]],
    jobLevel: 2,
    matchScore: 55,
    isNearStation: false,
    closingDate: null,
    canApplyNow: false,
    hospitalType: 'clinic',
    chairCount: 2,
    staffCount: 4,
    workDays: ['mon', 'tue', 'wed', 'thu', 'fri'],
    weekendWork: false,
    nightShift: false,
    applyMethod: ['phone', 'email'],
    isAlwaysHiring: false,
    transportation: const TransportationInfo(
      subwayLines: ['1호선', '4호선'],
      subwayStationName: '창동역',
      walkingDistanceMeters: 880,
      walkingMinutes: 11,
      exitNumber: '3번 출구',
      parking: true,
    ),
    subwayLines: ['1호선', '4호선'],
    hasParking: true,
    tags: ['4대보험', '연차', '식비', '주5일', '야간없음', '즉시지원'],
  ),
  Job(
    id: 'mock_l2_9',
    title: '치위생사 파트타임/정규직',
    clinicName: '구로희망치과',
    address: '서울 구로구 구로동 999-9',
    district: '구로동 · 구로구',
    lat: 37.500,
    lng: 126.887,
    type: '치위생사',
    career: '신입/경력',
    salaryRange: [260, 320],
    salaryText: '월 260~320만원 (파트·정규 협의)',
    employmentType: '파트타임',
    workHours: '주 3~5일 협의 (면접 시 확정)',
    contact: '02-2018-1018',
    postedAt: DateTime.now().subtract(const Duration(days: 10)),
    details:
        '파트(주 3~4일) 또는 정규직 모두 지원 가능하며, 면접 시 근무일·시간을 조율합니다. '
        '스케일링·진료 보조·소독 업무가 주를 이룹니다. '
        '구로디지털단지역 도보 10분 내. '
        '명절 상여 지급, 4대보험은 고용 형태에 따라 적용(면접 안내).',
    benefits: ['4대보험', '주5일', '명절상여'],
    images: [kClinicPictureSampleAssets[8]],
    jobLevel: 2,
    matchScore: 63,
    isNearStation: true,
    closingDate: DateTime.now().add(const Duration(days: 25)),
    canApplyNow: true,
    hospitalType: 'network',
    chairCount: 6,
    staffCount: 9,
    workDays: ['mon', 'tue', 'wed', 'thu', 'fri'],
    weekendWork: false,
    nightShift: false,
    applyMethod: ['online', 'phone'],
    isAlwaysHiring: false,
    transportation: const TransportationInfo(
      subwayLines: ['2호선'],
      subwayStationName: '구로디지털단지역',
      walkingDistanceMeters: 720,
      walkingMinutes: 9,
      exitNumber: '4번 출구',
      parking: true,
    ),
    subwayLines: ['2호선'],
    hasParking: true,
    tags: ['4대보험', '주5일', '명절상여', '역세권', '즉시지원'],
  ),
  Job(
    id: 'mock_l2_10',
    title: '간호조무사/위생사 동시 모집',
    clinicName: '관악새날치과',
    address: '서울 관악구 봉천동 101-1',
    district: '봉천동 · 관악구',
    lat: 37.478,
    lng: 126.952,
    type: '치위생사',
    career: '1년 이상',
    salaryRange: [270, 330],
    salaryText: '월 270~330만원 (직종별 배치)',
    employmentType: '정규직',
    workHours: '09:00~18:30',
    contact: '02-2019-1019',
    postedAt: DateTime.now().subtract(const Duration(days: 11)),
    details:
        '지원 자격에 따라 조무사 또는 위생사 포지션으로 채용합니다. '
        '조무사는 데스크·방사선·진료 보조, 위생사는 스케일링·진료 보조에 집중합니다. '
        '1년 이상 해당 면허 실무 경험이 있으면 우대합니다. '
        '팀 단위 근무로 서로 커버하며 업무 강도를 조절합니다.',
    benefits: ['4대보험', '퇴직금'],
    images: [kClinicPictureSampleAssets[9]],
    jobLevel: 2,
    matchScore: 67,
    isNearStation: false,
    closingDate: null,
    canApplyNow: true,
    hospitalType: 'clinic',
    chairCount: 5,
    staffCount: 8,
    workDays: ['mon', 'tue', 'wed', 'thu', 'fri'],
    weekendWork: false,
    nightShift: false,
    applyMethod: ['online', 'phone', 'email'],
    isAlwaysHiring: false,
    transportation: const TransportationInfo(
      subwayLines: ['2호선'],
      subwayStationName: '서울대입구역',
      walkingDistanceMeters: 980,
      walkingMinutes: 12,
      exitNumber: '1번 출구',
      parking: false,
    ),
    subwayLines: ['2호선'],
    hasParking: false,
    tags: ['4대보험', '퇴직금', '주5일', '야간없음', '즉시지원'],
  ),
];

String _mockLevel3Details({
  required String clinicName,
  required String jobType,
  required String title,
  required int variant,
}) {
  final intro =
      '$clinicName에서 $title 포지션을 모집합니다. 직종은 $jobType 직무 중심으로 배정됩니다. ';
  const blocks = <String>[
    '스케일링·진료 보조, 기구 소독 및 감염 관리, 환자 안내까지 클리닉 전반에 참여합니다. '
        '내원 환자 연령층이 다양해 소통 능력이 중요합니다.',
    '예약·수납·전화 응대 등 데스크 업무와 진료 보조가 함께 포함될 수 있습니다. '
        '업무 비중은 면접 시 협의합니다.',
    '야간 또는 주말 진료가 일부 있을 수 있으며, 근무 스케줄은 월별로 공지합니다. '
        '대체 휴무 및 수당은 내부 규정에 따릅니다.',
    '4대보험 적용, 퇴직금 적립. 자격·경력에 따라 초봉은 공고 범위 내에서 조정됩니다. '
        '자세한 복리후생은 방문 면접 시 안내드립니다.',
  ];
  return intro + blocks[variant % blocks.length];
}

/// 인덱스 30–37: 경기·대전·전남 일반 공고 (지역별 2건씩, 총 8건)
Job _buildRegionalMockLevel3Job(int i) {
  final idx = i - 30;
  final regional = <(String, String, String, double, double)>[
    ('성남분당치과', '경기 성남시 분당구 정자동 200-2', '정자동 · 성남시', 37.359, 127.105),
    ('고양일산치과', '경기 고양시 일산동구 주엽동 500-5', '주엽동 · 고양시', 37.658, 126.832),
    ('대전서구스마일치과', '대전 서구 둔산동 400-4', '둔산동 · 서구', 36.351, 127.384),
    ('대전중구밝은치과', '대전 중구 대종로 120', '은행동 · 중구', 36.327, 127.427),
    ('안양만안치과', '경기 안양시 만안구 안양동 600-6', '안양동 · 안양시', 37.394, 126.927),
    ('수원영통치과', '경기 수원시 영통구 영통동 90-1', '영통동 · 수원시', 37.266, 127.079),
    ('순천연두치과', '전남 순천시 조례동 800-8', '조례동 · 순천시', 34.950, 127.489),
    ('여수해변치과', '전남 여수시 학동 55-2', '학동 · 여수시', 34.760, 127.662),
  ];
  final clinic = regional[idx];
  final titles = [
    '치위생사 정규직 채용',
    '치과 코디네이터 모집',
    '간호조무사 경력직',
    '데스크 직원 채용',
    '치위생사 (야간 없음)',
    '신입 치위생사 환영',
    '치과위생사 파트/정규',
    '경력 무관 데스크',
  ];
  final title = titles[idx];
  final type = ['치위생사', '데스크', '간호조무사', '데스크', '치위생사', '치위생사', '치위생사', '데스크'][idx];
  final minSal = 252 + idx * 6;
  final maxSal = minSal + 32;
  final stationPairs = <(List<String>, String)>[
    (['수인분당선'], '정자역'),
    (['3호선'], '주엽역'),
    (['1호선'], '둔산역'),
    (['1호선'], '중앙로역'),
    (['1호선'], '안양역'),
    (['수인분당선'], '영통역'),
    (['전라선'], '순천역'),
    (['전라선'], '여수엑스포역'),
  ];
  final st = stationPairs[idx];
  return Job(
    id: 'mock_l3_$i',
    title: title,
    clinicName: clinic.$1,
    address: clinic.$2,
    district: clinic.$3,
    lat: clinic.$4,
    lng: clinic.$5,
    type: type,
    career: '1년 이상',
    salaryRange: [minSal, maxSal],
    salaryText: '월 $minSal~$maxSal만원 (면접 협의)',
    employmentType: '정규직',
    workHours: '평일 09:00~18:00',
    contact: '031-3${idx}00-${2100 + idx * 11}',
    postedAt: DateTime.now().subtract(Duration(days: idx + 2)),
    details: _mockLevel3Details(
      clinicName: clinic.$1,
      jobType: type,
      title: title,
      variant: i,
    ),
    benefits: const ['4대보험', '퇴직금', '연차'],
    images: [kClinicPictureSampleAssets[idx % kClinicPictureSampleAssets.length]],
    jobLevel: 3,
    matchScore: 0,
    isNearStation: idx % 2 == 0,
    closingDate: DateTime.now().add(Duration(days: 10 + idx * 2)),
    canApplyNow: idx % 3 == 0,
    hospitalType: 'clinic',
    chairCount: 4 + idx % 4,
    staffCount: 6 + idx % 5,
    workDays: const ['mon', 'tue', 'wed', 'thu', 'fri'],
    weekendWork: false,
    nightShift: false,
    applyMethod: const ['online', 'phone'],
    isAlwaysHiring: false,
    transportation: TransportationInfo(
      subwayLines: st.$1,
      subwayStationName: st.$2,
      walkingDistanceMeters: 400 + idx * 35,
      walkingMinutes: 5 + idx % 4,
      exitNumber: '${idx + 1}번 출구',
      parking: idx % 2 == 0,
    ),
    subwayLines: st.$1,
    hasParking: idx % 2 == 0,
    tags: ['4대보험', '퇴직금', '주5일', if (idx % 2 == 0) '역세권'],
  );
}

/// 단일 레벨3 목업 (ID `mock_l3_{i}` 와 동일 규칙)
Job _buildMockLevel3JobAt(int i) {
  if (i >= 30 && i < 38) {
    return _buildRegionalMockLevel3Job(i);
  }
  final clinics = [
    ('중구연세치과', '서울 중구 을지로', '을지로 · 중구', 37.566, 126.998),
    ('종로밝은치과', '서울 종로구 종로', '종로 · 종로구', 37.572, 126.979),
    ('연세화이트치과', '서울 용산구 이태원동', '이태원동 · 용산구', 37.534, 126.994),
    ('성북푸른치과', '서울 성북구 길음동', '길음동 · 성북구', 37.601, 127.024),
    ('동대문치과의원', '서울 동대문구 전농동', '전농동 · 동대문구', 37.583, 127.044),
    ('강북좋은치과', '서울 강북구 수유동', '수유동 · 강북구', 37.637, 127.026),
    ('금천스마일치과', '서울 금천구 시흥동', '시흥동 · 금천구', 37.457, 126.895),
    ('동작밝은치과', '서울 동작구 노량진동', '노량진동 · 동작구', 37.513, 126.942),
  ];
  final titles = [
    '치위생사 정규직 채용',
    '간호조무사 모집',
    '데스크 직원 채용',
    '치과위생사 경력직',
    '신입 치위생사 환영',
    '치과 코디네이터 채용',
    '야간 진료 치위생사',
    '임시직/정규직 동시 모집',
  ];
  final types = ['치위생사', '간호조무사', '데스크', '기타'];
  final careers = ['신입', '1년 이상', '2년 이상', '3년 이상', '경력 무관'];

  final clinic = clinics[i % clinics.length];
  final title = titles[i % titles.length];
  final type = types[i % types.length];
  final minSal = 248 + (i % 8) * 8;
  final maxSal = minSal + 28 + (i % 5) * 6;
  const employmentTypes = ['정규직', '계약직', '파트타임', '인턴'];
  final employmentType = employmentTypes[i % employmentTypes.length];
  const hoursOpts = [
    '평일 09:00~18:00',
    '09:30~18:30 (토 격주)',
    '주 5일, 점심 13:00~14:00',
    '오전 집중 근무 협의',
    '파트 주 3~4일 협의',
  ];
  final benefitSets = [
    ['4대보험', '퇴직금', '연차'],
    ['4대보험', '식비지원', '명절상여'],
    ['4대보험', '퇴직금', '주차지원'],
    ['4대보험', '연차', '교육지원'],
  ];

  const hospitalTypes = ['clinic', 'network', 'hospital', 'general'];
  final hospitalType = hospitalTypes[i % hospitalTypes.length];
  final chairCount = 3 + (i % 6);
  final staffCount = 5 + (i % 10);
  final workDaysFull = ['mon', 'tue', 'wed', 'thu', 'fri'];
  final workDaysWithSat = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  final workDays = i % 7 == 0 ? workDaysWithSat : workDaysFull;
  final weekendWork = i % 7 == 0;
  final nightShift = i % 6 == 0;
  final applyMethods = [
    ['online', 'phone'],
    ['online', 'email'],
    ['phone', 'email'],
    ['online', 'phone', 'email'],
  ];
  final applyMethod = applyMethods[i % applyMethods.length];
  final isAlwaysHiring = i % 5 == 2;
  final near = i % 3 == 0;
  final walkMin = near ? 4 + (i % 4) : 11 + (i % 5);
  final walkM = walkMin * 70;
  final lines = [
    ['2호선'],
    ['3호선', '4호선'],
    ['5호선'],
    ['1호선', '6호선'],
  ][i % 4];
  final stationNames = [
    '을지로3가역',
    '종각역',
    '이태원역',
    '길음역',
    '신설동역',
    '수유역',
    '가산디지털단지역',
    '노량진역',
  ];
  final stationName = stationNames[i % stationNames.length];
  final exitNo = '${(i % 8) + 1}번 출구';
  final parking = i % 2 == 0;
  final tags = [
    ...benefitSets[i % benefitSets.length].take(2),
    if (near) '역세권',
    if (!nightShift) '야간없음',
    '주5일',
    if (applyMethod.contains('online')) '즉시지원',
  ];

  return Job(
    id: 'mock_l3_$i',
    title: title,
    clinicName: clinic.$1,
    address: clinic.$2,
    district: clinic.$3,
    lat: clinic.$4,
    lng: clinic.$5,
    type: type,
    career: careers[i % careers.length],
    salaryRange: [minSal, maxSal],
    salaryText: '월 $minSal~$maxSal만원 (면접 협의)',
    employmentType: employmentType,
    workHours: hoursOpts[i % hoursOpts.length],
    contact:
        '02-3${(i % 10)}${(i % 9)}-${2100 + (i % 899)}',
    postedAt: DateTime.now().subtract(Duration(days: i + 1)),
    details: _mockLevel3Details(
      clinicName: clinic.$1,
      jobType: type,
      title: title,
      variant: i,
    ),
    benefits: benefitSets[i % benefitSets.length],
    images: [kClinicPictureSampleAssets[i % kClinicPictureSampleAssets.length]],
    jobLevel: 3,
    matchScore: 0,
    isNearStation: near,
    closingDate:
        isAlwaysHiring ? null : (i % 4 == 0 ? DateTime.now().add(Duration(days: 7 + i % 14)) : null),
    canApplyNow: i % 5 == 0,
    hospitalType: hospitalType,
    chairCount: chairCount,
    staffCount: staffCount,
    workDays: workDays,
    weekendWork: weekendWork,
    nightShift: nightShift,
    applyMethod: applyMethod,
    isAlwaysHiring: isAlwaysHiring,
    transportation: TransportationInfo(
      subwayLines: lines,
      subwayStationName: stationName,
      walkingDistanceMeters: walkM,
      walkingMinutes: walkMin,
      exitNumber: exitNo,
      parking: parking,
    ),
    subwayLines: lines,
    hasParking: parking,
    tags: tags,
  );
}

/// 레벨3 Mock 데이터 생성기 (게시판형)
List<Job> generateMockLevel3Jobs({int count = 30}) {
  return List.generate(count, _buildMockLevel3JobAt);
}

/// Firestore에 없는 목업 공고 ID → 로컬 [Job] 조회 (상세 화면 폴백용)
Job? findMockJobById(String id) {
  for (final j in mockLevel1Jobs) {
    if (j.id == id) return j;
  }
  for (final j in mockLevel2Jobs) {
    if (j.id == id) return j;
  }
  if (id.startsWith('mock_l3_')) {
    final suffix = id.substring('mock_l3_'.length);
    final idx = int.tryParse(suffix);
    if (idx != null && idx >= 0) {
      return _buildMockLevel3JobAt(idx);
    }
  }
  return null;
}
