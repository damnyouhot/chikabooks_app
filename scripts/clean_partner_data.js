/**
 * 기존 테스트 파트너 그룹 데이터 정리 스크립트
 * 
 * 실행 방법:
 * cd functions
 * node ../scripts/clean_partner_data.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('../functions/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function cleanPartnerData() {
  console.log('🧹 파트너 데이터 정리 시작...\n');

  try {
    // 1. 모든 파트너 그룹 삭제
    console.log('1️⃣ 기존 파트너 그룹 삭제 중...');
    const groupsSnapshot = await db.collection('partnerGroups').get();
    const groupBatch = db.batch();
    let groupCount = 0;

    for (const doc of groupsSnapshot.docs) {
      groupBatch.delete(doc.ref);
      groupCount++;

      // 서브컬렉션도 삭제 (memberMeta, slots, etc.)
      const memberMetaSnap = await doc.ref.collection('memberMeta').get();
      for (const metaDoc of memberMetaSnap.docs) {
        groupBatch.delete(metaDoc.ref);
      }

      const slotsSnap = await doc.ref.collection('slots').get();
      for (const slotDoc of slotsSnap.docs) {
        groupBatch.delete(slotDoc.ref);
      }

      const weeklyStampsSnap = await doc.ref.collection('weeklyStamps').get();
      for (const stampDoc of weeklyStampsSnap.docs) {
        groupBatch.delete(stampDoc.ref);
      }
    }

    await groupBatch.commit();
    console.log(`   ✅ ${groupCount}개 그룹 삭제 완료\n`);

    // 2. 매칭풀 초기화
    console.log('2️⃣ 매칭풀 초기화 중...');
    const poolSnapshot = await db.collection('partnerMatchingPool').get();
    const poolBatch = db.batch();
    let poolCount = 0;

    for (const doc of poolSnapshot.docs) {
      poolBatch.delete(doc.ref);
      poolCount++;
    }

    await poolBatch.commit();
    console.log(`   ✅ ${poolCount}개 매칭풀 항목 삭제 완료\n`);

    // 3. 모든 사용자의 파트너 관련 필드 초기화
    console.log('3️⃣ 사용자 파트너 필드 초기화 중...');
    const usersSnapshot = await db.collection('users').get();
    const userBatch = db.batch();
    let userCount = 0;

    for (const doc of usersSnapshot.docs) {
      userBatch.update(doc.ref, {
        partnerGroupId: null,
        partnerGroupEndsAt: null,
        partnerStatus: 'active',
        willMatchNextWeek: true,
        continueWithPartner: null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      userCount++;
    }

    await userBatch.commit();
    console.log(`   ✅ ${userCount}명의 사용자 파트너 필드 초기화 완료\n`);

    // 4. dailySlots 컬렉션 정리
    console.log('4️⃣ 일일 슬롯 데이터 정리 중...');
    const slotsSnapshot = await db.collection('dailySlots').get();
    const slotsBatch = db.batch();
    let slotsCount = 0;

    for (const doc of slotsSnapshot.docs) {
      // 리액션 서브컬렉션도 삭제
      const reactionsSnap = await doc.ref.collection('reactions').get();
      for (const reactionDoc of reactionsSnap.docs) {
        slotsBatch.delete(reactionDoc.ref);
      }
      
      slotsBatch.delete(doc.ref);
      slotsCount++;
    }

    await slotsBatch.commit();
    console.log(`   ✅ ${slotsCount}개 슬롯 삭제 완료\n`);

    console.log('✅ 모든 파트너 데이터 정리 완료!');
    console.log('\n📊 정리 요약:');
    console.log(`   - 파트너 그룹: ${groupCount}개`);
    console.log(`   - 매칭풀: ${poolCount}개`);
    console.log(`   - 사용자 필드 초기화: ${userCount}명`);
    console.log(`   - 일일 슬롯: ${slotsCount}개`);

  } catch (error) {
    console.error('❌ 오류 발생:', error);
    throw error;
  }
}

// 실행
cleanPartnerData()
  .then(() => {
    console.log('\n🎉 작업 완료! 프로세스를 종료합니다.');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 치명적 오류:', error);
    process.exit(1);
  });










