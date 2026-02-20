/**
 * Firestore에 관리자 UID 설정
 * 
 * 사용법:
 * node tools/setup_admin.js YOUR_UID_HERE
 */

const admin = require('firebase-admin');
const serviceAccount = require('../functions/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function setupAdmin() {
  const adminUid = process.argv[2];
  
  if (!adminUid) {
    console.error('❌ 사용법: node tools/setup_admin.js YOUR_UID_HERE');
    process.exit(1);
  }

  try {
    // config/admins 문서에 관리자 UID 목록 저장
    await db.collection('config').doc('admins').set({
      uids: [adminUid],
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log('✅ 관리자 설정 완료!');
    console.log(`   UID: ${adminUid}`);
    console.log('');
    console.log('📋 이제 Firestore 규칙을 배포하세요:');
    console.log('   firebase deploy --only firestore:rules');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ 오류:', error);
    process.exit(1);
  }
}

setupAdmin();

