// 치과책방 전자책(ebooks 컬렉션) 기준 집계:
//   - 서재 동기화: users/{uid}/purchases 서브컬렉션에 문서 존재
//   - 열람 추정: lastReadAt 필드 존재 (뷰어에서 진행 저장 시 갱신)
// 사용: node count_ebook_readers.js
const path = require('path');
const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.cert(
    require(path.join(__dirname, 'serviceAccountKey.json')),
  ),
});

const db = admin.firestore();

async function main() {
  const ebooksSnap = await db.collection('ebooks').get();
  const ebookIds = new Set(ebooksSnap.docs.map((d) => d.id));
  console.log(`ebooks 문서 수(카탈로그): ${ebookIds.size}`);

  const usersWithPurchase = new Set();
  const usersWithLastRead = new Set();
  const purchaseDocCount = { inCatalog: 0, other: 0 };

  let lastDoc = null;
  const pageSize = 500;
  for (;;) {
    let q = db.collectionGroup('purchases').orderBy(admin.firestore.FieldPath.documentId()).limit(pageSize);
    if (lastDoc) q = q.startAfter(lastDoc);
    const snap = await q.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      const ebookId = doc.id;
      const inCat = ebookIds.has(ebookId);
      if (inCat) purchaseDocCount.inCatalog++;
      else purchaseDocCount.other++;

      const segs = doc.ref.path.split('/');
      if (segs.length < 4 || segs[0] !== 'users' || segs[2] !== 'purchases') continue;
      const uid = segs[1];
      if (!inCat) continue;

      usersWithPurchase.add(uid);
      const data = doc.data() || {};
      if (data.lastReadAt != null) usersWithLastRead.add(uid);
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.size < pageSize) break;
  }

  console.log('\n── 집계 (ebooks 카탈로그에 해당하는 purchases만 유저 수에 반영) ──');
  console.log(`purchases 문서: 카탈로그 일치 ${purchaseDocCount.inCatalog}건, 기타 ebookId ${purchaseDocCount.other}건`);
  console.log(`서재에 치과책방 전자책이 1권 이상 있는 유저 수: ${usersWithPurchase.size}`);
  console.log(`lastReadAt 이 있는 유저 수 (뷰어에서 열람/진행 저장 추정): ${usersWithLastRead.size}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
