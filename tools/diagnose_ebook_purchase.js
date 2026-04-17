/**
 * 진단 스크립트: 특정 유저의 "신입을 위한 친절한 임상문답" 구매 누락 원인 파악
 *
 * 확인 항목:
 *  1. ebooks 컬렉션에서 해당 책 문서 + imwebProductCode 필드
 *  2. imweb_orders 컬렉션에서 해당 유저 이메일로 된 주문 목록
 *  3. users/{uid}/purchases 에 해당 ebook 문서 존재 여부
 *
 * 사용:  node diagnose_ebook_purchase.js <이메일>
 *        (이메일 생략 시 주문번호 202309140938723 기준으로만 ebooks 확인)
 */

const path = require('path');
const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.cert(
    require(path.join(__dirname, 'serviceAccountKey.json')),
  ),
});

const db = admin.firestore();

const TARGET_TITLE_KEYWORD = '임상문답';
const TARGET_ORDER_NO = '202309140938723';

async function main() {
  const emailArg = process.argv[2]?.trim().toLowerCase();

  console.log('='.repeat(60));
  console.log('📋 진단 시작');
  console.log('='.repeat(60));

  // ── 1. ebooks 컬렉션에서 해당 책 찾기 ──────────────────────
  console.log('\n[1] ebooks 컬렉션 → "임상문답" 키워드 검색');
  const ebooksSnap = await db.collection('ebooks').get();
  const matchingBooks = [];

  for (const doc of ebooksSnap.docs) {
    const d = doc.data();
    if ((d.title || '').includes(TARGET_TITLE_KEYWORD)) {
      matchingBooks.push({ id: doc.id, ...d });
    }
  }

  if (matchingBooks.length === 0) {
    console.log('  ❌ 해당 제목의 ebook 문서를 찾지 못했습니다.');
  } else {
    for (const b of matchingBooks) {
      console.log(`  ✅ 문서 ID   : ${b.id}`);
      console.log(`     제목      : ${b.title}`);
      console.log(`     imwebProductCode : ${b.imwebProductCode ?? '⚠️  필드 없음'}`);
      console.log(`     productId  : ${b.productId ?? '없음'}`);
    }
  }

  // ebookMap 전체 출력 (어떤 코드들이 매핑됐는지 확인)
  console.log('\n  ─ 전체 ebooks imwebProductCode 매핑 ─');
  const ebookMap = new Map(); // productCode → docId
  for (const doc of ebooksSnap.docs) {
    const code = doc.data().imwebProductCode;
    if (code) {
      ebookMap.set(String(code), doc.id);
      console.log(`  "${code}" → ${doc.id}  (${doc.data().title?.slice(0, 20)})`);
    } else {
      console.log(`  ⚠️  imwebProductCode 없음 → ${doc.id}  (${doc.data().title?.slice(0, 20)})`);
    }
  }

  if (!emailArg) {
    console.log('\n⚠️  이메일 인자 없음 → imweb_orders / purchases 조회 건너뜀');
    console.log('   사용법: node diagnose_ebook_purchase.js <이메일>');
    return;
  }

  // ── 2. imweb_orders 에서 해당 이메일 주문 조회 ─────────────
  console.log(`\n[2] imweb_orders → email="${emailArg}" 검색`);
  const ordersSnap = await db
    .collection('imweb_orders')
    .where('email', '==', emailArg)
    .get();

  if (ordersSnap.empty) {
    console.log('  ❌ imweb_orders에 해당 이메일 기록 없음');
  } else {
    console.log(`  총 ${ordersSnap.docs.length}건 발견:`);
    for (const doc of ordersSnap.docs) {
      const d = doc.data();
      const productCode = String(d.productCode ?? '');
      const ebookId = ebookMap.get(productCode);
      const cancelFlag = d.cancelReason || d.cancel_reason || d.취소사유 || d.isCancelled || d.orderStatus;
      console.log(`\n  문서 ID      : ${doc.id}`);
      console.log(`  productCode  : ${productCode}`);
      console.log(`  linkedUid    : ${d.linkedUid ?? 'null (미연결)'}`);
      console.log(`  orderNo      : ${d.orderNo ?? '없음'}`);
      console.log(`  purchasedAt  : ${d.purchasedAt?.toDate?.() ?? d.purchasedAt}`);
      console.log(`  cancelReason 등: ${cancelFlag ?? '없음'}`);
      console.log(`  → ebookMap 매핑: ${ebookId ? `✅ ${ebookId}` : '❌ 매핑 안 됨'}`);
    }
  }

  // ── 3. users 컬렉션에서 해당 이메일 uid 찾기 ───────────────
  console.log(`\n[3] users 컬렉션 → email="${emailArg}" 검색`);
  const usersSnap = await db
    .collection('users')
    .where('email', '==', emailArg)
    .limit(1)
    .get();

  if (usersSnap.empty) {
    console.log('  ❌ users 컬렉션에 해당 이메일 유저 없음');
    return;
  }

  const userDoc = usersSnap.docs[0];
  const uid = userDoc.id;
  console.log(`  ✅ uid: ${uid}`);
  console.log(`  emailAliases: ${JSON.stringify(userDoc.data().emailAliases ?? [])}`);

  // ── 4. purchases 서브컬렉션 확인 ──────────────────────────
  console.log(`\n[4] users/${uid}/purchases 서브컬렉션`);
  const purchasesSnap = await db
    .collection('users')
    .doc(uid)
    .collection('purchases')
    .get();

  if (purchasesSnap.empty) {
    console.log('  ❌ purchases 서브컬렉션이 비어있음');
  } else {
    console.log(`  총 ${purchasesSnap.docs.length}건:`);
    for (const doc of purchasesSnap.docs) {
      console.log(`  - ${doc.id}`);
    }
  }

  // 매칭 책의 ebookId가 purchases에 있는지 교차 확인
  if (matchingBooks.length > 0) {
    console.log('\n[최종 교차 확인]');
    for (const b of matchingBooks) {
      const inPurchases = purchasesSnap.docs.some((d) => d.id === b.id);
      console.log(`  "${b.title}"`);
      console.log(`   ebook docId: ${b.id}`);
      console.log(`   purchases에 존재: ${inPurchases ? '✅ 있음' : '❌ 없음 ← 이게 원인'}`);
      console.log(`   imwebProductCode: ${b.imwebProductCode ?? '⚠️ 필드 없음 ← 이게 원인'}`);
    }
  }

  console.log('\n' + '='.repeat(60));
  console.log('📋 진단 완료');
  console.log('='.repeat(60));
}

main().catch((e) => {
  console.error('오류:', e);
  process.exit(1);
});
