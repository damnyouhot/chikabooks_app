/**
 * 유령 linkedUid 일괄 점검 스크립트
 *
 * imweb_orders 전체를 스캔하여:
 *   1. linkedUid 가 설정되어 있으나 users 컬렉션에 존재하지 않는 "유령 uid" 탐지
 *   2. 해당 이메일 기준 현재 활성 계정 조회
 *   3. 현재 계정의 purchases 에서 누락된 ebook 여부 교차 확인
 *
 * 실행: node tools/check_ghost_linked_uid.js
 * 옵션: DRY_RUN=false node tools/check_ghost_linked_uid.js
 *       → DRY_RUN=false 이면 발견된 유령 uid 문서의 linkedUid 를 자동 교정
 *         (purchases 생성은 포함하지 않음 — 교정 후 앱에서 동기화 버튼 사용)
 */

const path = require('path');
const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.cert(
    require(path.join(__dirname, '../functions/serviceAccountKey.json'))
  ),
});

const db = admin.firestore();
const DRY_RUN = process.env.DRY_RUN !== 'false';

async function main() {
  console.log(`=== check_ghost_linked_uid 시작 (DRY_RUN=${DRY_RUN}) ===\n`);

  // 1. linkedUid 가 null 이 아닌 문서 전체 조회
  const snap = await db.collection('imweb_orders')
    .where('linkedUid', '!=', null)
    .get();

  console.log(`linkedUid 설정 문서 수: ${snap.size}건\n`);
  if (snap.empty) {
    console.log('처리할 문서가 없습니다.');
    return;
  }

  // 2. 고유 uid 추출
  const uidSet = new Set();
  for (const doc of snap.docs) {
    const uid = doc.data().linkedUid;
    if (uid) uidSet.add(uid);
  }
  console.log(`고유 linkedUid 수: ${uidSet.size}개`);

  // 3. users 컬렉션에서 존재 여부 확인 (10개씩 청크)
  const uidArray = [...uidSet];
  const existingUids = new Set();

  for (let i = 0; i < uidArray.length; i += 10) {
    const chunk = uidArray.slice(i, i + 10);
    const docs = await Promise.all(
      chunk.map((uid) => db.collection('users').doc(uid).get())
    );
    docs.forEach((d) => { if (d.exists) existingUids.add(d.id); });
  }

  const ghostUids = uidArray.filter((uid) => !existingUids.has(uid));
  console.log(`유령 uid 수: ${ghostUids.length}개\n`);

  if (ghostUids.length === 0) {
    console.log('✅ 유령 uid 없음. 문제 없습니다!');
    return;
  }

  // 4. ebooks 맵 로드 (productCode → { id, title })
  const ebooksSnap = await db.collection('ebooks').get();
  const ebookMap = new Map();
  for (const doc of ebooksSnap.docs) {
    const code = doc.data().imwebProductCode;
    if (code) ebookMap.set(String(code), { id: doc.id, title: doc.data().title ?? doc.id });
  }

  // 5. 유령 uid 별 상세 분석
  let totalAffected = 0;
  let totalMissingPurchases = 0;
  const fixQueue = []; // DRY_RUN=false 일 때 자동 교정 대상

  for (const ghostUid of ghostUids) {
    const affectedDocs = snap.docs.filter((d) => d.data().linkedUid === ghostUid);
    totalAffected += affectedDocs.length;

    console.log(`──────────────────────────────────────────`);
    console.log(`👻 유령 uid: ${ghostUid} (${affectedDocs.length}건)`);

    for (const doc of affectedDocs) {
      const data = doc.data();
      const email = String(data.email ?? '').trim().toLowerCase();
      const productCode = String(data.productCode ?? '');
      const ebook = productCode ? ebookMap.get(productCode) : null;

      console.log(`\n  문서ID    : ${doc.id}`);
      console.log(`  이메일    : ${email || '(없음)'}`);
      console.log(`  상품코드  : ${productCode} → ${ebook ? ebook.title : '❓ 미매핑'}`);

      if (!email) continue;

      // 현재 활성 계정 조회 (email 직접 매칭 → emailAliases 매칭)
      let currentUid = null;

      const userByEmail = await db.collection('users')
        .where('email', '==', email).limit(1).get();
      if (!userByEmail.empty) {
        currentUid = userByEmail.docs[0].id;
      } else {
        const userByAlias = await db.collection('users')
          .where('emailAliases', 'array-contains', email).limit(1).get();
        if (!userByAlias.empty) currentUid = userByAlias.docs[0].id;
      }

      if (!currentUid) {
        console.log(`  현재 uid  : ❓ (활성 계정 없음 — 아직 재가입 안 함)`);
        continue;
      }

      console.log(`  현재 uid  : ${currentUid}`);

      // purchases 누락 여부 확인
      if (ebook) {
        const purchaseDoc = await db.collection('users').doc(currentUid)
          .collection('purchases').doc(ebook.id).get();
        const missing = !purchaseDoc.exists;
        console.log(`  purchases : ${missing ? '⚠️  누락 (동기화 필요)' : '✅ 있음'}`);
        if (missing) totalMissingPurchases++;
      }

      fixQueue.push({ docRef: doc.ref, newUid: currentUid, ghostUid });
    }
  }

  console.log(`\n══════════════════════════════════════════`);
  console.log(`요약:`);
  console.log(`  유령 uid 수          : ${ghostUids.length}개`);
  console.log(`  영향 받는 주문 문서  : ${totalAffected}건`);
  console.log(`  purchases 누락       : ${totalMissingPurchases}건`);

  if (DRY_RUN) {
    console.log(`\nℹ️  DRY_RUN 모드 — 변경 없음.`);
    console.log(`   자동 교정하려면: DRY_RUN=false node tools/check_ghost_linked_uid.js`);
    console.log(`   (단, purchases 생성은 앱에서 동기화 버튼을 사용하세요.)`);
  } else {
    // 자동 교정: imweb_orders.linkedUid 만 업데이트
    const requeue = fixQueue.filter((item) => item.newUid);
    if (requeue.length === 0) {
      console.log('\n교정 가능한 항목 없음 (현재 활성 계정을 찾은 건이 없습니다).');
      return;
    }

    let batch = db.batch();
    let count = 0;

    for (const { docRef, newUid } of requeue) {
      batch.update(docRef, { linkedUid: newUid });
      count++;
      if (count % 400 === 0) {
        await batch.commit();
        batch = db.batch();
      }
    }
    if (count % 400 !== 0) await batch.commit();

    console.log(`\n✅ imweb_orders linkedUid 교정 완료: ${count}건`);
    console.log('   각 유저가 앱에서 동기화 버튼을 누르면 purchases 가 자동 생성됩니다.');
  }
}

main().catch((err) => {
  console.error('\n실패:', err);
  process.exit(1);
});
