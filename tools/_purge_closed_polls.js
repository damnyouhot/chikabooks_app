/**
 * 종료된(과거) 투표의 데이터만 삭제
 * - polls 문서 + options/votes/reports/pollComments 서브컬렉션 일괄 삭제
 * - 활성(진행 중) 투표는 건드리지 않음
 *
 * 실행: node tools/_purge_closed_polls.js
 */

const admin = require("firebase-admin");
const path = require("path");

const serviceAccount = require(path.join(__dirname, "serviceAccountKey.json"));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function deleteSubcollection(docRef, subName) {
  let total = 0;
  // eslint-disable-next-line no-constant-condition
  while (true) {
    const snap = await docRef.collection(subName).limit(400).get();
    if (snap.empty) break;
    const batch = db.batch();
    for (const d of snap.docs) batch.delete(d.ref);
    await batch.commit();
    total += snap.size;
  }
  return total;
}

async function purgeOption(optionRef) {
  const reports = await deleteSubcollection(optionRef, "reports");
  await optionRef.delete();
  return reports;
}

async function main() {
  const now = admin.firestore.Timestamp.now();

  // endsAt < now인 투표 = 종료된 투표
  const closedSnap = await db
    .collection("polls")
    .where("endsAt", "<", now)
    .get();

  if (closedSnap.empty) {
    console.log("종료된 투표가 없습니다.");
    return;
  }

  console.log(`종료된 투표 ${closedSnap.size}개 발견\n`);

  for (const pollDoc of closedSnap.docs) {
    const pd = pollDoc.data();
    const pollRef = pollDoc.ref;
    console.log(`▶ [${pollDoc.id}] ${pd.question?.slice(0, 40)}`);

    // options (+ 각 option의 reports)
    const optSnap = await pollRef.collection("options").get();
    let reportTotal = 0;
    for (const od of optSnap.docs) {
      reportTotal += await purgeOption(od.ref);
    }
    console.log(`  options: ${optSnap.size}건, reports: ${reportTotal}건 삭제`);

    // votes
    const votes = await deleteSubcollection(pollRef, "votes");
    console.log(`  votes: ${votes}건 삭제`);

    // pollComments
    const comments = await deleteSubcollection(pollRef, "pollComments");
    console.log(`  pollComments: ${comments}건 삭제`);

    // poll 문서 자체 삭제
    await pollRef.delete();
    console.log(`  poll 문서 삭제 완료\n`);
  }

  console.log("✅ 과거 투표 데이터 삭제 완료");
}

main().catch((e) => {
  console.error("오류:", e);
  process.exit(1);
});
