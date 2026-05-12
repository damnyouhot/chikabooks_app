/**
 * 광고 상품 카탈로그 + 결제 정책 시드 스크립트
 *
 * 설계서 §1, §2-1 기준:
 *   - appConfig/billingPolicy           : 일시정지 세이브율, 자동연장 리드일, 환불 윈도우 등
 *   - productCatalog/{tierKey}          : 등급별 상품 정의 (혜택, 노출일수, 알림범위 등)
 *   - productCatalog/{tier}/prices/{id} : 가격 이력 (현재 활성가는 productCatalog.activePriceId 가 가리킴)
 *
 * 멱등(idempotent) 동작:
 *   - 기존 문서가 있으면 덮어쓰지 않음 (--force 플래그로 강제 갱신)
 *   - 가격은 항상 새 priceId 로 추가하여 과거 가격 이력을 보존
 *
 * 실행:
 *   node scripts/seed_product_catalog.js               # 신규 생성만
 *   node scripts/seed_product_catalog.js --force       # 카탈로그 덮어쓰기 (가격은 새로 추가)
 *   node scripts/seed_product_catalog.js --new-prices  # 가격만 새 버전으로 추가 + activePriceId 교체
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require(path.join(
  __dirname,
  '..',
  '..',
  'tools',
  'serviceAccountKey.json',
));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const db = admin.firestore();
const FORCE = process.argv.includes('--force');
const NEW_PRICES = process.argv.includes('--new-prices');

// ────────────────────────────────────────────────────────
// 정책 디폴트 (설계서 §1)
// ────────────────────────────────────────────────────────
const BILLING_POLICY = {
  // 일시정지 시 잔여기간 세이브 비율 (0.0 ~ 1.0). 0.5 = 정지 5일이면 2.5일을 adEndAt 에 더해줌
  pauseSaveRate: 0.5,
  // 잔여일이 이 값보다 적으면 일시정지 불가
  pauseMinDaysToAllow: 1,
  // 캠페인당 최대 일시정지 횟수
  pauseMaxCountPerCampaign: 3,
  // 자동연장 디폴트 OFF
  autoRenewDefault: false,
  // adEndAt - autoRenewLeadDays 시점에 자동결제 시도
  autoRenewLeadDays: 1,
  // 무료 공고권 사용 가능 등급. C 전용 → ["basic"]
  voucherEligibleTiers: ['basic'],
  // 결제 후 환불 가능 일수
  refundWindowDays: 7,
  // 등급 변경 정책
  upgradeAllowed: true,
  downgradeAllowed: false,
  // 연장 결제 시 추가 가능한 일수 범위
  extensionMinDays: 7,
  extensionMaxDays: 90,
  // 메타
  policyVersion: 'v1',
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
};

// ────────────────────────────────────────────────────────
// 상품 카탈로그 (설계서 §2-1)
// ────────────────────────────────────────────────────────
//
// ⚠️ 가격(`amount`)은 prices 서브컬렉션에 별도 시드. 변경 시 새 priceId 추가 + activePriceId 교체.
// ⚠️ exposureDays 는 현재 functions/src/index.ts:displayDaysForTier 와 일치(60/30/14).
// ⚠️ jobLevel 1/2/3 은 현재 jobs.jobLevel 과 호환되어야 함.
//
const PRODUCT_CATALOG = [
  {
    tierKey: 'premium',
    doc: {
      name: 'A 프리미엄',
      medal: '🥇',
      subtitle: '전국 유저에 알림, 탭 상단 고정 노출되는 가장 강력한 공고',
      jobLevel: 1,
      exposureDays: 60,
      pushAudience: 'national',
      boardPositions: ['premium_grid', 'recommended_row', 'basic_list'],
      mapPin: true,
      matchPriority: 100,
      features: [
        { icon: '🔔', label: '전국 모든 유저 알림 발송' },
        { icon: '📍', label: '광고 영역 최상단 고정 배치' },
        { icon: '🔁', label: '스크롤 중에도 상단 고정' },
        { icon: '🗺', label: '지도 내 포인트 노출' },
        { icon: '📈', label: '매칭 추천 최우선순위' },
      ],
      comparisonRow: {
        push: '전국 전체',
        adPlacement: '최상단',
        repeat: '강함',
        match: '최고',
        listing: '사진 상단',
      },
      autoRenewDiscountRate: 0.10,
      activePriceId: 'price_premium_v1',
      isActive: true,
      sortOrder: 1,
    },
    initialPrice: {
      priceId: 'price_premium_v1',
      amount: 880000,
      currency: 'KRW',
      effectiveFrom: admin.firestore.Timestamp.now(),
      effectiveTo: null,
      createdBy: 'system:seed',
      note: '초기 가격 시드',
    },
  },
  {
    tierKey: 'standard',
    doc: {
      name: 'B 추천',
      medal: '🥈',
      subtitle: '지역 기반으로 사진과 함께 노출되는 공고',
      jobLevel: 2,
      exposureDays: 30,
      pushAudience: 'region',
      boardPositions: ['recommended_row', 'basic_list'],
      mapPin: true,
      matchPriority: 50,
      features: [
        { icon: '🔔', label: '해당 시/도 유저 알림 발송' },
        { icon: '📍', label: '광고 및 추천 영역 우선 노출' },
        { icon: '📈', label: '매칭 추천에서 우대 노출' },
        { icon: '🖼', label: "필터 적용 후 '전체 공고'에서도 사진 포함 노출" },
      ],
      comparisonRow: {
        push: '지역(시/도)',
        adPlacement: '우선 노출',
        repeat: '중간',
        match: '우대',
        listing: '사진 포함',
      },
      autoRenewDiscountRate: 0.10,
      activePriceId: 'price_standard_v1',
      isActive: true,
      sortOrder: 2,
    },
    initialPrice: {
      priceId: 'price_standard_v1',
      amount: 440000,
      currency: 'KRW',
      effectiveFrom: admin.firestore.Timestamp.now(),
      effectiveTo: null,
      createdBy: 'system:seed',
      note: '초기 가격 시드',
    },
  },
  {
    tierKey: 'basic',
    doc: {
      name: 'C 일반',
      medal: '🥉',
      subtitle: '부담 없이 채용을 시작하고 싶을 때',
      jobLevel: 3,
      exposureDays: 14,
      pushAudience: 'none',
      boardPositions: ['basic_list'],
      mapPin: true,
      matchPriority: 0,
      features: [
        { icon: '📄', label: '전체 공고 목록에 노출' },
        { icon: '🗺', label: '지도 노출' },
        { icon: '⏱', label: '노출 기간: 14일' },
      ],
      comparisonRow: {
        push: '없음',
        adPlacement: '없음',
        repeat: '없음',
        match: '없음',
        listing: '기본',
      },
      autoRenewDiscountRate: 0.10,
      activePriceId: 'price_basic_v1',
      isActive: true,
      sortOrder: 3,
    },
    initialPrice: {
      priceId: 'price_basic_v1',
      amount: 110000,
      currency: 'KRW',
      effectiveFrom: admin.firestore.Timestamp.now(),
      effectiveTo: null,
      createdBy: 'system:seed',
      note: '초기 가격 시드',
    },
  },
];

// ────────────────────────────────────────────────────────
// 시드 메인 로직
// ────────────────────────────────────────────────────────
async function seedBillingPolicy() {
  const ref = db.collection('appConfig').doc('billingPolicy');
  const snap = await ref.get();
  if (snap.exists && !FORCE) {
    console.log('• appConfig/billingPolicy : 이미 존재 (skip)');
    return;
  }

  if (snap.exists && FORCE) {
    // 변경 이력 백업
    const histRef = ref.collection('history').doc();
    await histRef.set({
      ...snap.data(),
      _archivedAt: admin.firestore.FieldValue.serverTimestamp(),
      _replacedBy: 'seed:--force',
    });
    console.log(`• appConfig/billingPolicy/history/${histRef.id} : 이전 값 백업`);
  }

  await ref.set(BILLING_POLICY, { merge: false });
  console.log('✅ appConfig/billingPolicy : 시드 완료');
}

async function seedProductCatalog() {
  for (const item of PRODUCT_CATALOG) {
    const tierRef = db.collection('productCatalog').doc(item.tierKey);
    const tierSnap = await tierRef.get();

    // 카탈로그 본문
    if (!tierSnap.exists || FORCE) {
      const payload = {
        ...item.doc,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (!tierSnap.exists) {
        payload.createdAt = admin.firestore.FieldValue.serverTimestamp();
      }
      await tierRef.set(payload, { merge: tierSnap.exists });
      console.log(`✅ productCatalog/${item.tierKey} : ${tierSnap.exists ? '갱신' : '생성'}`);
    } else {
      console.log(`• productCatalog/${item.tierKey} : 이미 존재 (skip)`);
    }

    // 가격
    const priceCol = tierRef.collection('prices');
    if (NEW_PRICES) {
      // 새 가격 추가 + activePriceId 갱신
      const newPriceId = `price_${item.tierKey}_${Date.now()}`;
      const oldActiveId = (tierSnap.data() || {}).activePriceId;
      if (oldActiveId) {
        await priceCol.doc(oldActiveId).set(
          {
            effectiveTo: admin.firestore.Timestamp.now(),
          },
          { merge: true },
        );
      }
      await priceCol.doc(newPriceId).set({
        ...item.initialPrice,
        priceId: newPriceId,
        note: '신규 가격 (--new-prices)',
      });
      await tierRef.set({ activePriceId: newPriceId }, { merge: true });
      console.log(`   ↳ 새 가격 ${newPriceId} 추가, activePriceId 갱신`);
    } else {
      const priceRef = priceCol.doc(item.initialPrice.priceId);
      const priceSnap = await priceRef.get();
      if (!priceSnap.exists || FORCE) {
        await priceRef.set(item.initialPrice);
        console.log(`   ↳ prices/${item.initialPrice.priceId} : ${priceSnap.exists ? '갱신' : '생성'}`);
      } else {
        console.log(`   ↳ prices/${item.initialPrice.priceId} : 이미 존재 (skip)`);
      }
    }
  }
}

async function main() {
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('  광고 상품 카탈로그 + 결제 정책 시드');
  console.log(`  플래그: FORCE=${FORCE}, NEW_PRICES=${NEW_PRICES}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  await seedBillingPolicy();
  await seedProductCatalog();

  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('  ✅ 시드 완료');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  process.exit(0);
}

main().catch((e) => {
  console.error('❌ 시드 실패:', e);
  process.exit(1);
});
