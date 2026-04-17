const path = require('path');
const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require(path.join(__dirname, 'serviceAccountKey.json'))) });
const db = admin.firestore();

async function main() {
  const linkedUid = 'GszyJb56t9RqhRTvFlMRodSnof82';
  const actualUid = 'naver_2N8hQjr1fDKcopVuvdEfJq17SQsd4nuMkQHQIahNyjQ';

  console.log('=== [1] imweb_orders에 연결된 uid 계정 조회 ===');
  console.log('linkedUid:', linkedUid);
  const linkedDoc = await db.collection('users').doc(linkedUid).get();
  if (linkedDoc.exists) {
    const d = linkedDoc.data();
    console.log('✅ users 컬렉션에 존재');
    console.log('  email:', d.email);
    console.log('  emailAliases:', d.emailAliases);
    const pSnap = await db.collection('users').doc(linkedUid).collection('purchases').get();
    console.log('  purchases 수:', pSnap.docs.length);
    pSnap.docs.forEach(doc => console.log('   -', doc.id.slice(0, 40)));
  } else {
    console.log('❌ users 컬렉션에 없음 → 삭제된(또는 존재하지 않는) 계정');
  }

  console.log('\n=== [2] 실제 유저(bma2080@naver.com) 계정 ===');
  console.log('actualUid:', actualUid);
  const actualDoc = await db.collection('users').doc(actualUid).get();
  if (actualDoc.exists) {
    const d = actualDoc.data();
    console.log('  email:', d.email);
    console.log('  emailAliases:', d.emailAliases);
  }
  const pSnap2 = await db.collection('users').doc(actualUid).collection('purchases').get();
  console.log('  현재 purchases 목록:');
  pSnap2.docs.forEach(doc => console.log('   -', doc.id.slice(0, 50)));

  console.log('\n=== [3] imweb_orders 문서 linkedUid 상태 ===');
  const ordersSnap = await db.collection('imweb_orders').where('email', '==', 'bma2080@naver.com').get();
  ordersSnap.docs.forEach(doc => {
    const d = doc.data();
    console.log('  문서ID:', doc.id);
    console.log('  productCode:', d.productCode);
    console.log('  linkedUid:', d.linkedUid);
    console.log('  linkedUid === actualUid?', d.linkedUid === actualUid);
  });
}

main().catch(e => { console.error(e); process.exit(1); });
