/**
 * Firebase Auth + Firestore users/{uid} 대량 삭제 (지정 UID 제외)
 *
 * ⚠️ 프로덕션 파괴 작업. 신중히 실행.
 * - Auth 사용자 삭제 + users/{uid} recursiveDelete
 * - bondPosts/지원서 등 다른 컬렉션의 uid 참조는 deleteMyAccount(클라우드 함수)만큼 정리하지 않음.
 *   공개 데이터 정리가 필요하면 별도 작업 필요.
 *
 * 사용:
 *   FIREBASE_SERVICE_ACCOUNT=... node tools/delete-all-auth-users-except.cjs YhgjdjXMtlY2LIBHAfQnE7uBNv02
 *
 * 확인만:
 *   DRY_RUN=1 node tools/delete-all-auth-users-except.cjs <keepUid>
 *
 * Firestore users 문서만 지우기(Auth는 그대로) — SA에 Auth Admin이 없을 때:
 *   FIRESTORE_USERS_ONLY=1 node tools/delete-all-auth-users-except.cjs <keepUid>
 *   → 이후 Firebase Console → Authentication 에서 수동으로 나머지 계정 삭제
 *
 * SA 권한: Auth 삭제까지 하려면 서비스 계정에「Firebase Authentication Admin」등 필요.
 */

const path = require('path');
const fs = require('fs');

const adminModulePath = path.join(__dirname, '..', 'functions', 'node_modules', 'firebase-admin');
const admin = require(adminModulePath);

function initAdmin() {
  const root = path.join(__dirname, '..');
  let projectId;
  try {
    const rc = JSON.parse(fs.readFileSync(path.join(root, '.firebaserc'), 'utf8'));
    projectId = rc.projects?.default;
  } catch (_) {}

  const saEnv = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (saEnv) {
    const saPath = path.isAbsolute(saEnv) ? saEnv : path.join(root, saEnv);
    const sa = JSON.parse(fs.readFileSync(saPath, 'utf8'));
    admin.initializeApp({
      credential: admin.credential.cert(sa),
      projectId: projectId || sa.project_id,
    });
    return;
  }
  admin.initializeApp(projectId ? { projectId } : undefined);
}

async function deleteUserDocTree(db, uid) {
  const ref = db.collection('users').doc(uid);
  const snap = await ref.get();
  if (!snap.exists) {
    console.log(`  (Firestore users/${uid} 없음)`);
    return;
  }
  await db.recursiveDelete(ref);
  console.log(`  ✅ Firestore users/${uid} recursive 삭제`);
}

async function main() {
  const keepUid = (process.argv[2] || '').trim();
  if (!keepUid) {
    console.error('사용법: node tools/delete-all-auth-users-except.cjs <보존할_UID>');
    process.exit(1);
  }

  const dry = process.env.DRY_RUN === '1';
  const firestoreOnly = process.env.FIRESTORE_USERS_ONLY === '1';
  initAdmin();
  const auth = admin.auth();
  const db = admin.firestore();

  /** @type {string[]} */
  let toDelete = [];

  if (firestoreOnly) {
    const snap = await db.collection('users').get();
    toDelete = snap.docs.map((d) => d.id).filter((id) => id !== keepUid);
    console.log(`보존 UID: ${keepUid}`);
    console.log(
      `모드: Firestore users 문서만 삭제 (${toDelete.length}건)${dry ? ' (DRY_RUN)' : ''}`
    );
    if (firestoreOnly && !dry) {
      console.log('※ Firebase Auth 계정은 삭제하지 않습니다. 콘솔에서 별도 정리하세요.');
    }
  } else {
    let pageToken;
    try {
      do {
        const result = await auth.listUsers(1000, pageToken);
        for (const u of result.users) {
          if (u.uid !== keepUid) toDelete.push(u.uid);
        }
        pageToken = result.pageToken;
      } while (pageToken);
    } catch (e) {
      console.error(
        '\n❌ Auth 사용자 목록 조회 실패. 서비스 계정에 Firebase Authentication Admin 권한이 있는지 확인하세요.\n' +
          '   또는 Firestore만 지우려면:\n' +
          '   FIRESTORE_USERS_ONLY=1 node tools/delete-all-auth-users-except.cjs ' +
          keepUid +
          '\n'
      );
      throw e;
    }

    console.log(`보존 UID: ${keepUid}`);
    console.log(`삭제 대상 Auth 사용자 수: ${toDelete.length}${dry ? ' (DRY_RUN)' : ''}`);
  }

  if (dry) {
    toDelete.slice(0, 30).forEach((uid) => console.log('  -', uid));
    if (toDelete.length > 30) console.log(`  ... 외 ${toDelete.length - 30}명`);
    process.exit(0);
  }

  for (const uid of toDelete) {
    console.log(`처리 중: ${uid}`);
    try {
      await deleteUserDocTree(db, uid);
    } catch (e) {
      console.error(`  ⚠️ Firestore 삭제 실패 (계속):`, e.message);
    }
    if (!firestoreOnly) {
      try {
        await auth.deleteUser(uid);
        console.log(`  ✅ Auth 삭제 완료`);
      } catch (e) {
        console.error(`  ❌ Auth 삭제 실패:`, e.message);
      }
    }
  }

  console.log('완료.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
