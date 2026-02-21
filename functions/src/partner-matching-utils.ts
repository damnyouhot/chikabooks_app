import * as admin from "firebase-admin";

const db = admin.firestore();

// ========== 타입 정의 ==========

interface UserProfile {
  uid: string;
  nickname: string;
  region: string;
  careerGroup: string;
  careerBucket: string;
  mainConcerns: string[];
  partnerStatus: string;
  willMatchNextWeek: boolean;
  partnerGroupId?: string | null;
  partnerPreferences?: PartnerPreferences;
}

interface PartnerPreferences {
  priority1: PreferenceItem;
  priority2: PreferenceItem;
  priority3: PreferenceItem;
}

interface PreferenceItem {
  type: "region" | "career" | "tags";
  value: string;
}

// ========== 유틸리티 함수 ==========

/**
 * 연차 그룹을 careerBucket으로 변환
 * "학생" | "1년차" | "2년차" → "0-2"
 * "3년차" | "4년차" | "5년차" → "3-5"
 * "6~10년차" | ... → "6+"
 */
export function mapCareerGroupToBucket(careerGroup: string): string {
  if (["학생", "1년차", "2년차"].includes(careerGroup)) {
    return "0-2";
  } else if (["3년차", "4년차", "5년차"].includes(careerGroup)) {
    return "3-5";
  } else {
    return "6+";
  }
}

/**
 * 연차 버킷을 숫자로 변환 (비교용)
 */
function careerBucketToNumber(bucket: string): number {
  switch (bucket) {
    case "0-2":
      return 1;
    case "3-5":
      return 2;
    case "6+":
      return 3;
    default:
      return 1;
  }
}

/**
 * 두 사용자 간의 매칭 점수 계산
 * 설계서 기반: priority1 가중치 3, priority2 가중치 2, priority3 가중치 1
 */
export function calculateMatchScore(
  userA: UserProfile,
  userB: UserProfile,
  preferences: PartnerPreferences
): number {
  let score = 0;
  const weights = {priority1: 3, priority2: 2, priority3: 1};

  [1, 2, 3].forEach((priority) => {
    const key = `priority${priority}` as "priority1" | "priority2" | "priority3";
    const pref = preferences[key];
    const weight = weights[key];

    switch (pref.type) {
      case "region":
        // ✅ "가깝게"는 광역(시/도) 일치만 확인
        // 안전: 구/동 레벨 데이터는 절대 사용하지 않음
        if (pref.value === "nearby" && userA.region === userB.region) {
          score += 10 * weight;
          console.log(`  📍 지역 일치 (광역): ${userA.region}`);
        }
        // ✅ "멀게"는 광역이 다른 경우
        else if (pref.value === "far" && userA.region !== userB.region) {
          score += 10 * weight;
          console.log(`  📍 지역 분산: ${userA.region} ≠ ${userB.region}`);
        } else if (pref.value === "any") {
          score += 5 * weight;
        }
        break;

      case "career":
        const bucketA = userA.careerBucket || mapCareerGroupToBucket(userA.careerGroup);
        const bucketB = userB.careerBucket || mapCareerGroupToBucket(userB.careerGroup);
        const numA = careerBucketToNumber(bucketA);
        const numB = careerBucketToNumber(bucketB);

        if (pref.value === "similar" && bucketA === bucketB) {
          score += 10 * weight;
        } else if (pref.value === "senior" && numB > numA) {
          score += 10 * weight;
        } else if (pref.value === "any") {
          score += 5 * weight;
        }
        break;

      case "tags":
        if (pref.value === "similar") {
          const commonTags = userA.mainConcerns.filter((tag) =>
            userB.mainConcerns.includes(tag)
          ).length;
          score += commonTags * 5 * weight;
        } else if (pref.value === "any") {
          score += 5 * weight;
        }
        break;
    }
  });

  return score;
}

/**
 * 3명 그룹에서 평균 매칭 점수 계산
 * A-B, B-C, A-C 세 쌍의 점수를 평균
 */
function calculateGroupScore(
  users: UserProfile[]
): number {
  if (users.length !== 3) return 0;

  const [userA, userB, userC] = users;

  // 각 사용자의 선호도를 기준으로 점수 계산
  const prefA = userA.partnerPreferences || getDefaultPreferences();
  const prefB = userB.partnerPreferences || getDefaultPreferences();
  const prefC = userC.partnerPreferences || getDefaultPreferences();

  const scoreAB = calculateMatchScore(userA, userB, prefA);
  const scoreBA = calculateMatchScore(userB, userA, prefB);
  const scoreBC = calculateMatchScore(userB, userC, prefB);
  const scoreCB = calculateMatchScore(userC, userB, prefC);
  const scoreAC = calculateMatchScore(userA, userC, prefA);
  const scoreCA = calculateMatchScore(userC, userA, prefC);

  // 양방향 점수의 평균
  return (scoreAB + scoreBA + scoreBC + scoreCB + scoreAC + scoreCA) / 6;
}

/**
 * 기본 선호도 (편한 공감형)
 */
export function getDefaultPreferences(): PartnerPreferences {
  return {
    priority1: {type: "career", value: "similar"},
    priority2: {type: "tags", value: "similar"},
    priority3: {type: "region", value: "any"},
  };
}

/**
 * 현재 KST 월요일 09:00 시작 기준 주차 키 반환
 * 예: "2026-W08"
 */
export function getCurrentWeekKey(): string {
  const now = new Date();
  const kst = new Date(now.getTime() + 9 * 60 * 60 * 1000);

  // ISO 주차 계산
  const year = kst.getFullYear();
  const startOfYear = new Date(year, 0, 1);
  const days = Math.floor(
    (kst.getTime() - startOfYear.getTime()) / (24 * 60 * 60 * 1000)
  );
  const weekNumber = Math.ceil((days + 1) / 7);

  return `${year}-W${weekNumber.toString().padStart(2, "0")}`;
}

/**
 * 매칭 가능한 사용자 목록 조회
 * - active 상태: 무조건 매칭 대상 (willMatchNextWeek 무시)
 * - pause 상태: willMatchNextWeek=true인 경우만 매칭 대상
 * - 현재 활성 그룹이 없는 사용자만
 */
export async function getMatchableUsers(): Promise<UserProfile[]> {
  try {
    const now = admin.firestore.Timestamp.now();
    
    // 1. active 상태 사용자 (무조건 매칭 대상, willMatchNextWeek 무시)
    const activeSnapshot = await db
      .collection("users")
      .where("partnerStatus", "==", "active")
      .get();

    // 2. pause 상태지만 명시적으로 매칭 희망한 사용자만
    const pauseButWillingSnapshot = await db
      .collection("users")
      .where("partnerStatus", "==", "pause")
      .where("willMatchNextWeek", "==", true)
      .get();

    const allDocs = [...activeSnapshot.docs, ...pauseButWillingSnapshot.docs];
    const users: UserProfile[] = [];

    for (const doc of allDocs) {
      const data = doc.data();

      // 현재 활성 그룹이 있는지 확인
      const hasActiveGroup =
        data.partnerGroupId &&
        data.partnerGroupEndsAt &&
        data.partnerGroupEndsAt.toDate() > now.toDate();

      if (hasActiveGroup) {
        continue; // 이미 그룹이 있으면 제외
      }

      // 프로필 완성 체크
      if (!data.nickname || !data.careerGroup || !data.mainConcerns?.length) {
        continue; // 프로필 미완성 제외
      }

      users.push({
        uid: doc.id,
        nickname: data.nickname,
        region: data.region || "",
        careerGroup: data.careerGroup || "",
        careerBucket: data.careerBucket || mapCareerGroupToBucket(data.careerGroup || ""),
        mainConcerns: data.mainConcerns || [],
        partnerStatus: data.partnerStatus || "active",
        willMatchNextWeek: data.willMatchNextWeek !== false,
        partnerGroupId: data.partnerGroupId,
        partnerPreferences: data.partnerPreferences || getDefaultPreferences(),
      });
    }

    return users;
  } catch (error) {
    console.error("⚠️ getMatchableUsers error:", error);
    return [];
  }
}

/**
 * 3명 최적 조합 찾기 (브루트포스)
 * 모든 3인 조합을 평가하고 가장 높은 점수의 그룹 반환
 */
export function findBest3PersonGroups(
  users: UserProfile[],
  maxGroups: number = 100
): UserProfile[][] {
  if (users.length < 3) return [];

  const groups: Array<{users: UserProfile[]; score: number}> = [];

  // 모든 3명 조합 생성 및 점수 계산
  for (let i = 0; i < users.length - 2; i++) {
    for (let j = i + 1; j < users.length - 1; j++) {
      for (let k = j + 1; k < users.length; k++) {
        const trio = [users[i], users[j], users[k]];
        const score = calculateGroupScore(trio);
        groups.push({users: trio, score});
      }
    }
  }

  // 점수 기반 정렬 (높은 순)
  groups.sort((a, b) => b.score - a.score);

  // 중복 사용자 제거하며 상위 그룹 선택
  const selectedGroups: UserProfile[][] = [];
  const usedUids = new Set<string>();

  for (const group of groups) {
    // 이미 다른 그룹에 할당된 사용자가 있는지 확인
    const hasUsedUser = group.users.some((u) => usedUids.has(u.uid));
    if (hasUsedUser) continue;

    // 그룹 추가
    selectedGroups.push(group.users);
    group.users.forEach((u) => usedUids.add(u.uid));

    if (selectedGroups.length >= maxGroups) break;
  }

  return selectedGroups;
}

/**
 * 2명 그룹 찾기 (3명이 안 될 때 대안)
 * 설계서: "2명으로도 시작 가능, 주중 보충"
 */
export function findBest2PersonGroups(
  users: UserProfile[],
  maxGroups: number = 50
): UserProfile[][] {
  if (users.length < 2) return [];

  const pairs: Array<{users: UserProfile[]; score: number}> = [];

  // 모든 2명 조합 생성 및 점수 계산
  for (let i = 0; i < users.length - 1; i++) {
    for (let j = i + 1; j < users.length; j++) {
      const duo = [users[i], users[j]];
      
      const prefA = users[i].partnerPreferences || getDefaultPreferences();
      const prefB = users[j].partnerPreferences || getDefaultPreferences();
      
      const scoreAB = calculateMatchScore(users[i], users[j], prefA);
      const scoreBA = calculateMatchScore(users[j], users[i], prefB);
      const avgScore = (scoreAB + scoreBA) / 2;
      
      pairs.push({users: duo, score: avgScore});
    }
  }

  // 점수 기반 정렬
  pairs.sort((a, b) => b.score - a.score);

  // 중복 제거하며 선택
  const selectedPairs: UserProfile[][] = [];
  const usedUids = new Set<string>();

  for (const pair of pairs) {
    const hasUsedUser = pair.users.some((u) => usedUids.has(u.uid));
    if (hasUsedUser) continue;

    selectedPairs.push(pair.users);
    pair.users.forEach((u) => usedUids.add(u.uid));

    if (selectedPairs.length >= maxGroups) break;
  }

  return selectedPairs;
}

