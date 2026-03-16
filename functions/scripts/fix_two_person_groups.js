/**
 * 기존 2인 활성 그룹에 needsSupplementation: true 일괄 업데이트
 *
 * 실행: node scripts/fix_two_person_groups.js
 * 옵션: --dry-run  → 실제 수정 없이 대상만 출력
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require(path.join(__dirname, '..', '..', 'tools', 'serviceAccountKey.json'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const isDryRun = process.argv.includes('--dry-run');

async function main() {
  console.log(`🔍 2인 활성 그룹 조회 중... (dry-run: ${isDryRun})`);

  const snap = await db.collection('partnerGroups')
    .where('isActive', '==', true)
    .get();

  const now = new Date();

  let total = 0;
  let alreadyTrue = 0;
  let updated = 0;
  let skippedExpired = 0;
  let skippedNotTwo = 0;

  const batch = db.batch();
  let batchCount = 0;

  for (const doc of snap.docs) {
    const d = doc.data();
    const memberCount = (d.activeMemberUids || []).length;
    const endsAt = d.endsAt?.toDate?.();
    const isExpired = endsAt && endsAt <= now;

    total++;

    // 만료된 그룹 스킵
    if (isExpired) {
      skippedExpired++;
      continue;
    }

    // 2인이 아닌 그룹 스킵
    if (memberCount !== 2) {
      skippedNotTwo++;
      continue;
    }

    const currentVal = d.needsSupplementation;
    console.log(
      `  [${doc.id}] members: ${memberCount}` +
      ` | needsSupplementation: ${currentVal}` +
      ` | endsAt: ${endsAt?.toISOString() ?? 'null'}`
    );

    if (currentVal === true) {
      alreadyTrue++;
      continue;
    }

    // 업데이트 대상
    if (!isDryRun) {
      batch.update(doc.ref, {
        needsSupplementation: true,
        supplementationMarkedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      batchCount++;

      // Firestore 배치는 500개 제한
      if (batchCount >= 490) {
        await batch.commit();
        console.log(`  ✅ 중간 배치 commit (${batchCount}건)`);
        batchCount = 0;
      }
    }

    updated++;
  }

  if (!isDryRun && batchCount > 0) {
    await batch.commit();
  }

  console.log('\n=== 결과 ===');
  console.log(`활성 그룹 전체: ${total}`);
  console.log(`만료 그룹 스킵: ${skippedExpired}`);
  console.log(`2인 아닌 그룹 스킵: ${skippedNotTwo}`);
  console.log(`이미 true: ${alreadyTrue}`);
  console.log(`업데이트${isDryRun ? ' 예정(dry-run)' : ' 완료'}: ${updated}`);

  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });

