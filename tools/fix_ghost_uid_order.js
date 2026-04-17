/**
 * 유령 uid 수동 수정 스크립트
 *
 * 대상 유저: bma2080@naver.com
 * 문제: CSV import 당시 삭제된 계정(GszyJb56t9RqhRTvFlMRodSnof82)의 uid로
 *       imweb_orders 문서가 연결되어 syncImwebPurchases가 해당 주문을 스킵함.
 *
 * 처리 내용:
 *   1. imweb_orders/Ym1hMjA4MEBuYXZlci5jb218MTI_ 의 linkedUid 교정
 *   2. users/{TARGET_UID}/purchases/{ebookId} 문서 생성
 *
 * 실행: node tools/fix_ghost_uid_order.js
 */

const path = require('path');
const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.cert(
    require(path.join(__dirname, '../functions/serviceAccountKey.json'))
  ),
});

const db = admin.firestore();

const TARGET_UID       = 'naver_2N8hQjr1fDKcopVuvdEfJq17SQsd4nuMkQHQIahNyjQ';
const GHOST_UID        = 'GszyJb56t9RqhRTvFlMRodSnof82';
const ORDER_DOC_ID     = 'Ym1hMjA4MEBuYXZlci5jb218MTI_';
const IMWEB_PRODUCT_CODE = '12';
const PURCHASED_AT     = new Date('2023-09-14T00:00:00+09:00'); // KST 기준

async function main() {
  console.log('=== fix_ghost_uid_order 시작 ===\n');

  // 1. ebooks 에서 imwebProductCode: "12" 인 ebookId 조회
  const ebooksSnap = await db.collection('ebooks')
    .where('imwebProductCode', '==', IMWEB_PRODUCT_CODE)
    .limit(1)
    .get();

  if (ebooksSnap.empty) {
    console.error(`❌ imwebProductCode=${IMWEB_PRODUCT_CODE} 에 해당하는 ebook을 찾을 수 없습니다.`);
    process.exit(1);
  }

  const ebookDoc  = ebooksSnap.docs[0];
  const ebookId   = ebookDoc.id;
  const ebookTitle = ebookDoc.data().title ?? ebookId;
  console.log(`✅ ebook 확인: ${ebookId} (${ebookTitle})\n`);

  // 2. imweb_orders 문서 확인
  const orderRef = db.collection('imweb_orders').doc(ORDER_DOC_ID);
  const orderDoc = await orderRef.get();

  if (!orderDoc.exists) {
    console.error(`❌ imweb_orders/${ORDER_DOC_ID} 문서를 찾을 수 없습니다.`);
    process.exit(1);
  }

  const orderData = orderDoc.data();
  console.log('현재 imweb_orders 문서:');
  console.log(`  linkedUid  : ${orderData.linkedUid}`);
  console.log(`  email      : ${orderData.email}`);
  console.log(`  productCode: ${orderData.productCode}`);
  console.log(`  purchasedAt: ${orderData.purchasedAt?.toDate?.() ?? orderData.purchasedAt}\n`);

  if (orderData.linkedUid !== GHOST_UID) {
    console.error(`❌ 안전 중단: 예상한 ghost uid(${GHOST_UID})와 다릅니다.`);
    console.error(`   현재값: ${orderData.linkedUid}`);
    console.error('   GHOST_UID 상수를 확인하세요.');
    process.exit(1);
  }

  // 3. 대상 유저 존재 여부 확인
  const targetUserDoc = await db.collection('users').doc(TARGET_UID).get();
  if (!targetUserDoc.exists) {
    console.error(`❌ users/${TARGET_UID} 유저가 존재하지 않습니다.`);
    process.exit(1);
  }
  console.log(`✅ 대상 유저 확인: ${TARGET_UID} (${targetUserDoc.data().email ?? '이메일 없음'})\n`);

  // 4. purchases 이미 있는지 확인
  const purchaseRef = db.collection('users').doc(TARGET_UID)
    .collection('purchases').doc(ebookId);
  const purchaseDoc = await purchaseRef.get();

  if (purchaseDoc.exists) {
    console.log(`ℹ️  purchases/${ebookId} 이미 존재합니다.`);
    console.log('   linkedUid 교정만 진행합니다.\n');
  }

  // 5. 배치로 두 작업 동시 처리
  const batch = db.batch();

  // 5-A. imweb_orders linkedUid 교정
  batch.update(orderRef, { linkedUid: TARGET_UID });

  // 5-B. purchases 문서 생성 (이미 있으면 생략)
  if (!purchaseDoc.exists) {
    batch.set(purchaseRef, {
      ebookId,
      purchasedAt: admin.firestore.Timestamp.fromDate(PURCHASED_AT),
      source:      'manual_fix',
      syncedAt:    admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();

  console.log('=== 처리 완료 ===');
  console.log(`  imweb_orders/${ORDER_DOC_ID}`);
  console.log(`    linkedUid: ${GHOST_UID} → ${TARGET_UID}`);
  if (!purchaseDoc.exists) {
    console.log(`  users/${TARGET_UID}/purchases/${ebookId} 생성됨`);
    console.log(`    purchasedAt: ${PURCHASED_AT.toISOString()}`);
    console.log(`    source     : manual_fix`);
  } else {
    console.log(`  purchases/${ebookId} 는 이미 존재하여 생략됨`);
  }
}

main().catch((err) => {
  console.error('\n실패:', err);
  process.exit(1);
});
