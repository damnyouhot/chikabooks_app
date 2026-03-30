/**
 * Firestore jobs 8개 문서를 웹(createJobPosting)과 동일한 필드 구조로 보강합니다.
 * - createdAt / postedAt 없던 문서에 타임스탬프 부여 (앱 목록 쿼리 노출)
 * - type, details, salaryText, salaryRange 등 앱 표시용 필드 정규화
 *
 * 실행: node tools/migrate_jobs_eight.cjs
 */
const fs = require("fs");
const path = require("path");
const functionsDir = path.join(__dirname, "../functions");
const admin = require(path.join(functionsDir, "node_modules/firebase-admin"));

(function initFirebase() {
  if (admin.apps.length) return;
  const saPath = path.join(functionsDir, "serviceAccountKey.json");
  if (fs.existsSync(saPath)) {
    admin.initializeApp({
      credential: admin.credential.cert(JSON.parse(fs.readFileSync(saPath, "utf8"))),
    });
    return;
  }
  const cfgPath = path.join(require("os").homedir(), ".config/configstore/firebase-tools.json");
  if (!fs.existsSync(cfgPath)) {
    console.error("Firebase 인증 없음.");
    process.exit(1);
  }
  const cfg = JSON.parse(fs.readFileSync(cfgPath, "utf8"));
  const adcPath = "/tmp/_migrate_jobs_adc.json";
  fs.writeFileSync(
    adcPath,
    JSON.stringify({
      type: "authorized_user",
      client_id:
        cfg.tokens.client_id ||
        "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com",
      client_secret: cfg.tokens.client_secret || "j9iVZfS8kkCEFUPaAeJV0sAi",
      refresh_token: cfg.tokens.refresh_token,
    })
  );
  process.env.GOOGLE_APPLICATION_CREDENTIALS = adcPath;
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: "chikabooks3rd",
  });
})();

const Ts = admin.firestore.Timestamp;

function sr(min, max) {
  return { salaryMin: min, salaryMax: max, salaryRange: [min, max] };
}

/** 웹 저장과 동일한 키로 페이로드 구성 */
function buildPayload(base) {
  const {
    clinicName,
    title,
    role,
    employmentType,
    workHours,
    salaryLine,
    min,
    max,
    description,
    address,
    contact,
    benefits,
    district,
    lat,
    lng,
    status,
    createdAt,
    postedAt,
  } = base;

  const salaryStr = salaryLine;
  const s = sr(min, max);

  return {
    clinicName,
    title,
    role,
    type: role,
    employmentType,
    workHours,
    salary: salaryStr,
    salaryText: salaryStr,
    ...s,
    benefits,
    description,
    details: description,
    address,
    contact,
    images: [],
    status: status || "active",
    district: district || "",
    location: {
      address,
      lat: lat ?? 0,
      lng: lng ?? 0,
    },
    createdAt,
    postedAt,
    jobLevel: 3,
    canApplyNow: true,
    isNearStation: false,
  };
}

const JOBS = [
  {
    id: "57D4gqyyzMo8FAxdybdj",
    clinicName: "강남스마일치과의원",
    title: "신입 치과위생사 정규직 모집",
    role: "치과위생사",
    employmentType: "정규직",
    workHours: "평일 09:00~18:00 (금요일 17:00 퇴근), 토요일 격주 반일",
    salaryLine: "월 270~310만원 (경력·자격에 따라 협의)",
    min: 270,
    max: 310,
    description:
      "예방진료(스케일링·PMTC)·진료 보조·기구 소독 및 멸균·감염관리 업무를 담당합니다. " +
      "환자 응대·차트 기록·재료 준비 등 진료실 전반을 함께 맡게 됩니다. " +
      "디지털 차트 사용 경험이 있으면 우대하며, 팀워크와 성실함을 중시합니다. " +
      "내·외부 교육비를 지원하며, 장기 근속 시 급여 조정을 검토합니다.",
    address: "서울 강남구 테헤란로 123, 4층",
    district: "역삼동 · 강남구",
    contact: "02-1234-5678 (원무과)",
    benefits: ["4대보험", "퇴직금", "연차", "교육지원", "명절상여"],
    lat: 37.5012,
    lng: 127.0396,
    createdAt: Ts.fromDate(new Date("2026-01-08T02:00:00.000Z")),
    postedAt: Ts.fromDate(new Date("2026-01-08T02:00:00.000Z")),
  },
  {
    id: "7OfS07kqipvYZJxWcCnG",
    clinicName: "종로덴탈케어치과",
    title: "간호조무사 및 데스크 (신입·경력)",
    role: "간호조무사",
    employmentType: "정규직",
    workHours: "09:30~18:30 (점심 13:00~14:00), 주 5일",
    salaryLine: "월 250~290만원 (경력 반영)",
    min: 250,
    max: 290,
    description:
      "접수·수납·보험 청구, 방사선 촬영 보조, 진료 준비 및 원내 행정 업무를 담당합니다. " +
      "전화·카카오 예약 관리와 내원 환자 안내를 원활히 해 주실 분을 찾습니다. " +
      "간호조무사 면허 소지자 우대, 데스크 경력자도 지원 가능합니다. " +
      "밝은 응대와 정확한 업무 처리가 가능한 분이면 좋습니다.",
    address: "서울 종로구 종로 45",
    district: "종로 · 종로구",
    contact: "02-2345-6789",
    benefits: ["4대보험", "퇴직금", "연차", "식비지원"],
    lat: 37.572,
    lng: 126.979,
    createdAt: Ts.fromDate(new Date("2026-01-12T03:30:00.000Z")),
    postedAt: Ts.fromDate(new Date("2026-01-12T03:30:00.000Z")),
  },
  {
    id: "AQwJNPLU6AuvT9KwKAyf",
    clinicName: "서울에스연합치과",
    title: "위생사 잘하시는분 찾습니다.",
    role: "치과위생사",
    employmentType: "정규직",
    workHours: "09:00~18:00 (주 5일)",
    salaryLine: "협의 (면접 후 결정)",
    min: 0,
    max: 0,
    description:
      "스케일링·예방진료·진료 보조를 중심으로 원내 위생 업무를 총괄해 주실 치과위생사를 모집합니다. " +
      "환자별 맞춤 예방 안내와 차트 기록, 기구 세척·소독까지 꼼꼼히 진행해 주실 분을 기다립니다. " +
      "성실한 태도와 팀과의 협업을 중시하며, 교육 참여를 적극 지원합니다. " +
      "근무 환경·급여·복리는 면접 시 상세히 안내드립니다.",
    address: "서울 강남구 낙섬동로 134",
    district: "도곡동 · 강남구",
    contact: "070-8200-1030",
    benefits: ["4대보험", "퇴직금", "연차", "식비지원", "주차지원", "명절상여"],
    lat: 37.485,
    lng: 127.048,
    createdAt: Ts.fromDate(new Date("2026-02-25T18:06:28.361Z")),
    postedAt: Ts.fromDate(new Date("2026-02-25T18:06:28.361Z")),
  },
  {
    id: "Cxd9kpr6AAtiMrnOnWJZ",
    clinicName: "마포밝은치과의원",
    title: "데스크 코디네이터 (정규직)",
    role: "데스크",
    employmentType: "정규직",
    workHours: "10:00~19:00 (월~금), 토요일 격주 휴무",
    salaryLine: "월 240~280만원",
    min: 240,
    max: 280,
    description:
      "전화·온라인 예약 접수, 내원 환자 응대, 수납 및 간단한 보험 안내를 담당합니다. " +
      "대기 순서 관리와 진료 안내, 서류 발급 등 프런트 업무 전반을 맡게 됩니다. " +
      "의료·치과 데스크 경력자 우대, 친절한 커뮤니케이션과 책임감이 있으신 분을 환영합니다. " +
      "야간·주말 진료 없음, 주 5일 근무를 원칙으로 합니다.",
    address: "서울 마포구 월드컵북로 396",
    district: "상암동 · 마포구",
    contact: "02-3456-7890",
    benefits: ["4대보험", "연차", "명절상여"],
    lat: 37.554,
    lng: 126.922,
    createdAt: Ts.fromDate(new Date("2026-01-18T01:00:00.000Z")),
    postedAt: Ts.fromDate(new Date("2026-01-18T01:00:00.000Z")),
  },
  {
    id: "Ep4ez8DroEIHVn4dmIml",
    clinicName: "송파연세치과",
    title: "치과위생사 경력직 채용 (임플란트·교정 진료)",
    role: "치과위생사",
    employmentType: "정규직",
    workHours: "09:00~18:30 (토요일 09:00~14:00 격주)",
    salaryLine: "월 300~350만원 (경력 2년 이상)",
    min: 300,
    max: 350,
    description:
      "임플란트·교정·보철 등 다양한 진료 보조와 위생 관리 업무를 수행합니다. " +
      "원장 진료 스케줄에 맞춘 체어 세팅, 환자 안내, 사후 관리 안내까지 포함됩니다. " +
      "구강 스캐너·디지털 워크플로 경험이 있으면 우대합니다. " +
      "안정적인 정규직으로 장기 근속을 희망하는 경력 위생사를 모십니다.",
    address: "서울 송파구 올림픽로 300",
    district: "잠실 · 송파구",
    contact: "02-4567-8901",
    benefits: ["4대보험", "퇴직금", "연차", "교육지원", "주차지원"],
    lat: 37.512,
    lng: 127.073,
    createdAt: Ts.fromDate(new Date("2026-01-22T06:00:00.000Z")),
    postedAt: Ts.fromDate(new Date("2026-01-22T06:00:00.000Z")),
  },
  {
    id: "Md6YBZwS2T0zl9WlkaM2",
    clinicName: "영등포하늘치과",
    title: "치과위생사 파트타임 모집",
    role: "치과위생사",
    employmentType: "파트타임",
    workHours: "주 3일 (월·수·금 10:00~16:00) 협의 가능",
    salaryLine: "시급 또는 일급 협의 (면접 시 결정)",
    min: 0,
    max: 0,
    description:
      "주중 스케일링·예방진료 위주로 파트 근무 가능한 치과위생사를 모집합니다. " +
      "시간 조정이 가능한 분, 주말·야간 근무가 어려운 분을 환영합니다. " +
      "근무 일수·시간은 면접 시 협의하며, 급여는 시급 또는 일급으로 안내드립니다. " +
      "소규모 원으로 분위기가 좋고, 소통이 원활한 환경입니다.",
    address: "서울 영등포구 영등포로 120",
    district: "영등포동 · 영등포구",
    contact: "02-5678-9012",
    benefits: ["4대보험", "연차"],
    lat: 37.517,
    lng: 126.907,
    createdAt: Ts.fromDate(new Date("2026-01-28T04:00:00.000Z")),
    postedAt: Ts.fromDate(new Date("2026-01-28T04:00:00.000Z")),
  },
  {
    id: "Ms8cvarYzuToCdKKRZQi",
    clinicName: "중구연세플란트치과",
    title: "치과위생사·코디네이터 (신입 환영)",
    role: "치과위생사",
    employmentType: "계약직",
    workHours: "09:30~18:00 (수습 3개월 후 정규 전환 검토)",
    salaryLine: "월 260~300만원 (수습 기간 동일 범위 협의)",
    min: 260,
    max: 300,
    description:
      "내원 환자 응대와 예방진료 보조, 간단한 코디네이션 업무를 함께 수행합니다. " +
      "신입도 지원 가능하며, 수습 기간 중 멘토링과 교육을 제공합니다. " +
      "수습 후 근무 태도·역량에 따라 정규직 전환을 검토합니다. " +
      "시청·을지로 인근이라 대중교통 이용이 편리합니다.",
    address: "서울 중구 을지로 66",
    district: "을지로 · 중구",
    contact: "02-6789-0123",
    benefits: ["4대보험", "퇴직금", "연차", "식비지원"],
    lat: 37.566,
    lng: 126.998,
    createdAt: Ts.fromDate(new Date("2026-02-01T07:00:00.000Z")),
    postedAt: Ts.fromDate(new Date("2026-02-01T07:00:00.000Z")),
  },
  {
    id: "yobCM8o9IuB6oTqkeXPK",
    clinicName: "성북푸른치과의원",
    title: "치과위생사 (주 5일·야간 없음)",
    role: "치과위생사",
    employmentType: "정규직",
    workHours: "평일 08:30~17:30 (점심 12:30~13:30)",
    salaryLine: "월 280~320만원",
    min: 280,
    max: 320,
    description:
      "일반·소아치과 예방진료와 진료 보조, 감염관리 업무를 담당합니다. " +
      "야간 진료가 없어 생활 리듬을 유지하기 좋으며, 금요일은 17:00 퇴근입니다. " +
      "성실하고 꼼꼼한 성격의 분, 환자와의 신뢰를 중시하는 분을 기다립니다. " +
      "근처 주차 가능 구역 안내 가능, 자세한 사항은 면접 시 안내드립니다.",
    address: "서울 성북구 보문로 180",
    district: "길음동 · 성북구",
    contact: "02-7890-1234",
    benefits: ["4대보험", "퇴직금", "연차", "주차지원"],
    lat: 37.601,
    lng: 127.024,
    createdAt: Ts.fromDate(new Date("2026-02-10T05:00:00.000Z")),
    postedAt: Ts.fromDate(new Date("2026-02-10T05:00:00.000Z")),
  },
];

async function main() {
  const db = admin.firestore();
  console.log("── jobs 8건 문서 merge 업데이트 시작 ──\n");

  for (const row of JOBS) {
    const { id, ...rest } = row;
    const payload = buildPayload(rest);
    await db.collection("jobs").doc(id).set(payload, { merge: true });
    console.log("✔", id, "|", payload.title);
  }

  console.log("\n── 완료. node tools/_list_jobs.cjs 로 확인하세요. ──");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
