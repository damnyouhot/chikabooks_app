/**
 * 특정 poll options 삭제 스크립트
 *
 * 1. 현재 활성 투표에서 닉네임 '더글라스'가 추가한 보기 삭제
 * 2. 3/27 투표에서 공감 수 1, 2위 보기 삭제
 *
 * 실행: node tools/_delete_poll_options.js
 */

const admin = require("firebase-admin");
const path = require("path");

const serviceAccount = require(path.join(__dirname, "serviceAccountKey.json"));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function purgeOption(pollId, optionDoc) {
  const optionRef = optionDoc.ref;
  const data = optionDoc.data();
  console.log(`  → 삭제: [${optionDoc.id}] "${data.content}" (공감 ${data.empathyCount}명)`);

  // votes 정리
  const votesSnap = await db
    .collection("polls")
    .doc(pollId)
    .collection("votes")
    .where("optionId", "==", optionDoc.id)
    .get();

  if (!votesSnap.empty) {
    const batch = db.batch();
    let count = 0;
    for (const vd of votesSnap.docs) {
      batch.delete(vd.ref);
      count++;
    }
    await batch.commit();
    console.log(`     votes 삭제: ${count}건`);

    // totalEmpathyCount 보정
    const pollRef = db.collection("polls").doc(pollId);
    await db.runTransaction(async (tx) => {
      const pollSnap = await tx.get(pollRef);
      const total = pollSnap.data()?.totalEmpathyCount ?? 0;
      tx.update(pollRef, { totalEmpathyCount: Math.max(0, total - count) });
    });
    console.log(`     totalEmpathyCount -${count} 보정`);
  }

  // reports 정리
  const reportsSnap = await optionRef.collection("reports").get();
  if (!reportsSnap.empty) {
    const rb = db.batch();
    for (const rd of reportsSnap.docs) rb.delete(rd.ref);
    await rb.commit();
    console.log(`     reports 삭제: ${reportsSnap.size}건`);
  }

  await optionRef.delete();
  console.log(`     옵션 문서 삭제 완료`);
}

async function main() {
  // ─── 1. 현재 진행 중인 투표에서 '더글라스' 추가 보기 삭제 ───
  console.log("\n▶ [1] 활성 투표에서 더글라스 추가 보기 찾기");
  const now = admin.firestore.Timestamp.now();
  const activeSnap = await db
    .collection("polls")
    .where("endsAt", ">", now)
    .limit(10)
    .get();

  for (const pollDoc of activeSnap.docs) {
    const pd = pollDoc.data();
    const startsAt = pd.startsAt?.toDate();
    const endsAt = pd.endsAt?.toDate();
    const isOpen =
      startsAt && endsAt && startsAt <= new Date() && endsAt > new Date();
    if (!isOpen) continue;

    console.log(`  투표 [${pollDoc.id}]: ${pd.question?.slice(0, 30)}`);
    const optionsSnap = await db
      .collection("polls")
      .doc(pollDoc.id)
      .collection("options")
      .where("isSystem", "==", false)
      .where("authorNickname", "==", "더글라스")
      .get();

    if (optionsSnap.empty) {
      console.log("  → 더글라스 추가 보기 없음 (닉네임 기준)");
    } else {
      for (const od of optionsSnap.docs) {
        await purgeOption(pollDoc.id, od);
      }
    }

    // authorUid 기반으로도 더글라스 보기 찾기 (닉네임 없는 경우 대비)
    const allOpts = await db
      .collection("polls")
      .doc(pollDoc.id)
      .collection("options")
      .where("isSystem", "==", false)
      .get();
    for (const od of allOpts.docs) {
      const d = od.data();
      if (d.content === "테스트" || d.content === "테스트통라 | 너러 | ㄴ아ㅏ | 르니아러니러니러니 러 | 닐라 | ㄴ;이런;안;이런; | ㅇ러 | ㄴ르") {
        console.log(`  → content 매칭으로 추가 삭제:`);
        await purgeOption(pollDoc.id, od);
      }
    }
  }

  // ─── 2. 3/27 투표 1·2위 보기 삭제 ───
  console.log("\n▶ [2] 3/27 투표 찾기 (startsAt 기준)");
  const mar27start = new Date("2026-03-27T00:00:00+09:00");
  const mar27end   = new Date("2026-03-27T23:59:59+09:00");

  const pollsSnap = await db
    .collection("polls")
    .where("startsAt", ">=", admin.firestore.Timestamp.fromDate(mar27start))
    .where("startsAt", "<=", admin.firestore.Timestamp.fromDate(mar27end))
    .get();

  if (pollsSnap.empty) {
    // endsAt 기준으로도 시도
    console.log("  startsAt 기준 없음 → endsAt 기준으로 재시도");
    const p2 = await db
      .collection("polls")
      .where("endsAt", ">=", admin.firestore.Timestamp.fromDate(mar27start))
      .where("endsAt", "<=", admin.firestore.Timestamp.fromDate(new Date("2026-03-28T23:59:59+09:00")))
      .get();
    if (p2.empty) {
      console.log("  3/27 투표를 찾을 수 없습니다.");
    } else {
      for (const pd of p2.docs) await deleteTop2(pd);
    }
  } else {
    for (const pd of pollsSnap.docs) await deleteTop2(pd);
  }

  console.log("\n✅ 완료");
}

async function deleteTop2(pollDoc) {
  const pd = pollDoc.data();
  console.log(`  투표 [${pollDoc.id}]: ${pd.question?.slice(0, 40)}`);
  // 인덱스 없이 전체 조회 후 클라이언트 정렬
  const optSnap = await db
    .collection("polls")
    .doc(pollDoc.id)
    .collection("options")
    .get();

  if (optSnap.empty) {
    console.log("  → 보기 없음");
    return;
  }

  const topOpts = optSnap.docs
    .sort((a, b) => (b.data().empathyCount ?? 0) - (a.data().empathyCount ?? 0))
    .slice(0, 2);

  if (topOpts.length === 0) {
    console.log("  → 보기 없음");
    return;
  }
  let rank = 1;
  for (const od of topOpts) {
    console.log(`  ${rank}위 보기:`);
    rank++;
    await purgeOption(pollDoc.id, od);
  }
}

main().catch((e) => {
  console.error("오류:", e);
  process.exit(1);
});
