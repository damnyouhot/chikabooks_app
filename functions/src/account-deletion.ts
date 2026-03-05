// functions/src/account-deletion.ts
import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.firestore();
const bucket = admin.storage().bucket();

/**
 * Storage prefix 기반 파일 삭제
 */
async function deleteStorageByPrefix(prefix: string) {
  try {
    const [files] = await bucket.getFiles({ prefix });
    if (files.length === 0) {
      console.log(`✅ Storage 파일 없음: ${prefix}`);
      return;
    }
    
    await Promise.all(
      files.map((file) =>
        file.delete().catch((err) => {
          console.warn(`⚠️ 파일 삭제 실패 (무시): ${file.name}`, err);
        })
      )
    );
    
    console.log(`✅ Storage 삭제 완료: ${prefix} (${files.length}개)`);
  } catch (error) {
    console.error(`❌ Storage 삭제 실패: ${prefix}`, error);
  }
}

/**
 * bondPosts 익명화 (완전 삭제 대신)
 */
async function anonymizeBondPosts(uid: string) {
  try {
    const postsSnap = await db
      .collection("bondPosts")
      .where("uid", "==", uid)
      .get();

    if (postsSnap.empty) {
      console.log("✅ bondPosts 없음");
      return;
    }

    const batch = db.batch();
    postsSnap.docs.forEach((doc) => {
      batch.update(doc.ref, {
        uid: "deleted_user",
        nickname: "탈퇴한 사용자",
        profileImageUrl: admin.firestore.FieldValue.delete(),
      });
    });

    await batch.commit();
    console.log(`✅ bondPosts 익명화 완료: ${postsSnap.size}개`);
  } catch (error) {
    console.error("❌ bondPosts 익명화 실패:", error);
  }
}

/**
 * 파트너 그룹 내 게시물 익명화
 */
async function anonymizePartnerGroupPosts(uid: string) {
  try {
    const groupsSnap = await db
      .collection("partnerGroups")
      .where("memberUids", "array-contains", uid)
      .get();

    if (groupsSnap.empty) {
      console.log("✅ partnerGroups posts 익명화 - 소속 그룹 없음");
      return;
    }

    let totalCount = 0;

    for (const groupDoc of groupsSnap.docs) {
      const postsSnap = await groupDoc.ref
        .collection("posts")
        .where("uid", "==", uid)
        .get();

      if (postsSnap.empty) continue;

      const batch = db.batch();
      postsSnap.docs.forEach((doc) => {
        batch.update(doc.ref, {
          uid: "deleted_user",
          nickname: "탈퇴한 사용자",
          profileImageUrl: admin.firestore.FieldValue.delete(),
        });
      });
      await batch.commit();
      totalCount += postsSnap.size;
    }

    console.log(`✅ partnerGroups posts 익명화 완료: ${totalCount}개`);
  } catch (error) {
    console.error("❌ partnerGroups posts 익명화 실패:", error);
  }
}

/**
 * 구직 지원 내역 익명화
 */
async function anonymizeApplications(uid: string) {
  try {
    const snap = await db
      .collection("applications")
      .where("applicantUid", "==", uid)
      .get();

    if (snap.empty) {
      console.log("✅ applications 없음");
      return;
    }

    const batch = db.batch();
    snap.docs.forEach((doc) => {
      batch.update(doc.ref, {
        applicantUid: "deleted_user",
        name: "탈퇴한 사용자",
        phone: admin.firestore.FieldValue.delete(),
        message: admin.firestore.FieldValue.delete(),
      });
    });
    await batch.commit();

    console.log(`✅ applications 익명화 완료: ${snap.size}개`);
  } catch (error) {
    console.error("❌ applications 익명화 실패:", error);
  }
}

/**
 * HIRA 댓글 익명화
 */
async function anonymizeHiraComments(uid: string) {
  try {
    const updatesSnap = await db
      .collection("content_hira_updates")
      .limit(200)
      .get();

    if (updatesSnap.empty) {
      console.log("✅ HIRA 댓글 없음");
      return;
    }

    let totalCount = 0;

    for (const updateDoc of updatesSnap.docs) {
      const commentsSnap = await updateDoc.ref
        .collection("comments")
        .where("uid", "==", uid)
        .get();

      if (commentsSnap.empty) continue;

      const batch = db.batch();
      commentsSnap.docs.forEach((doc) => {
        batch.update(doc.ref, {
          uid: "deleted_user",
          nickname: "탈퇴한 사용자",
          profileImageUrl: admin.firestore.FieldValue.delete(),
        });
      });
      await batch.commit();
      totalCount += commentsSnap.size;
    }

    console.log(`✅ HIRA 댓글 익명화 완료: ${totalCount}개`);
  } catch (error) {
    console.error("❌ HIRA 댓글 익명화 실패:", error);
  }
}

/**
 * 파트너 그룹 내 replies 익명화
 */
async function anonymizePartnerGroupReplies(uid: string) {
  try {
    const groupsSnap = await db
      .collection("partnerGroups")
      .where("memberUids", "array-contains", uid)
      .get();

    if (groupsSnap.empty) return;

    let totalCount = 0;

    for (const groupDoc of groupsSnap.docs) {
      const postsSnap = await groupDoc.ref.collection("posts").get();
      if (postsSnap.empty) continue;

      for (const postDoc of postsSnap.docs) {
        const repliesSnap = await postDoc.ref
          .collection("replies")
          .where("uid", "==", uid)
          .get();

        if (repliesSnap.empty) continue;

        const batch = db.batch();
        repliesSnap.docs.forEach((doc) => {
          batch.update(doc.ref, {
            uid: "deleted_user",
            nickname: "탈퇴한 사용자",
            profileImageUrl: admin.firestore.FieldValue.delete(),
          });
        });
        await batch.commit();
        totalCount += repliesSnap.size;
      }
    }

    console.log(`✅ partnerGroups replies 익명화 완료: ${totalCount}개`);
  } catch (error) {
    console.error("❌ partnerGroups replies 익명화 실패:", error);
  }
}

/**
 * 파트너 그룹 내 reactions 익명화
 */
async function anonymizePartnerGroupReactions(uid: string) {
  try {
    const groupsSnap = await db
      .collection("partnerGroups")
      .where("memberUids", "array-contains", uid)
      .get();

    if (groupsSnap.empty) return;

    let totalCount = 0;

    for (const groupDoc of groupsSnap.docs) {
      const postsSnap = await groupDoc.ref.collection("posts").get();
      if (postsSnap.empty) continue;

      for (const postDoc of postsSnap.docs) {
        const reactionsSnap = await postDoc.ref
          .collection("reactions")
          .where("uid", "==", uid)
          .get();

        if (reactionsSnap.empty) continue;

        const batch = db.batch();
        reactionsSnap.docs.forEach((doc) => {
          batch.update(doc.ref, {
            uid: "deleted_user",
          });
        });
        await batch.commit();
        totalCount += reactionsSnap.size;
      }
    }

    console.log(`✅ partnerGroups reactions 익명화 완료: ${totalCount}개`);
  } catch (error) {
    console.error("❌ partnerGroups reactions 익명화 실패:", error);
  }
}

/**
 * 파트너 그룹 내 enthrones 삭제 (docId가 uid)
 */
async function deletePartnerGroupEnthrones(uid: string) {
  try {
    const groupsSnap = await db
      .collection("partnerGroups")
      .where("memberUids", "array-contains", uid)
      .get();

    if (groupsSnap.empty) return;

    let totalCount = 0;

    for (const groupDoc of groupsSnap.docs) {
      const postsSnap = await groupDoc.ref.collection("posts").get();
      if (postsSnap.empty) continue;

      for (const postDoc of postsSnap.docs) {
        const enthroneRef = postDoc.ref.collection("enthrones").doc(uid);
        const enthroneDoc = await enthroneRef.get();

        if (enthroneDoc.exists) {
          await enthroneRef.delete();
          totalCount++;
        }
      }
    }

    console.log(`✅ partnerGroups enthrones 삭제 완료: ${totalCount}개`);
  } catch (error) {
    console.error("❌ partnerGroups enthrones 삭제 실패:", error);
  }
}

/**
 * 파트너 그룹 activityLogs 익명화
 */
async function anonymizePartnerGroupActivityLogs(uid: string) {
  try {
    const groupsSnap = await db
      .collection("partnerGroups")
      .where("memberUids", "array-contains", uid)
      .get();

    if (groupsSnap.empty) return;

    let totalCount = 0;

    for (const groupDoc of groupsSnap.docs) {
      const logsSnap = await groupDoc.ref
        .collection("activityLogs")
        .where("actorUid", "==", uid)
        .get();

      if (logsSnap.empty) continue;

      const batch = db.batch();
      logsSnap.docs.forEach((doc) => {
        batch.update(doc.ref, {
          actorUid: "deleted_user",
        });
      });
      await batch.commit();
      totalCount += logsSnap.size;
    }

    console.log(`✅ partnerGroups activityLogs 익명화 완료: ${totalCount}개`);
  } catch (error) {
    console.error("❌ partnerGroups activityLogs 익명화 실패:", error);
  }
}

/**
 * dailyWallPosts 익명화
 */
async function anonymizeDailyWallPosts(uid: string) {
  try {
    const snap = await db
      .collection("dailyWallPosts")
      .where("authorUid", "==", uid)
      .get();

    if (snap.empty) {
      console.log("✅ dailyWallPosts 없음");
      return;
    }

    const batch = db.batch();
    snap.docs.forEach((doc) => {
      batch.update(doc.ref, {
        authorUid: "deleted_user",
        // authorMeta는 careerBucket/region만 있어 식별 불가 - 유지
      });
    });
    await batch.commit();

    console.log(`✅ dailyWallPosts 익명화 완료: ${snap.size}개`);
  } catch (error) {
    console.error("❌ dailyWallPosts 익명화 실패:", error);
  }
}

/**
 * dailyWallPosts reactions 삭제 (docId = uid)
 */
async function deleteDailyWallReactions(uid: string) {
  try {
    const postsSnap = await db.collection("dailyWallPosts").limit(200).get();
    if (postsSnap.empty) return;

    let totalCount = 0;

    for (const postDoc of postsSnap.docs) {
      const reactionRef = postDoc.ref.collection("reactions").doc(uid);
      const reactionDoc = await reactionRef.get();

      if (reactionDoc.exists) {
        await reactionRef.delete();
        totalCount++;
      }
    }

    console.log(`✅ dailyWallPosts reactions 삭제 완료: ${totalCount}개`);
  } catch (error) {
    console.error("❌ dailyWallPosts reactions 삭제 실패:", error);
  }
}

/**
 * bondPosts reports 삭제 (docId = uid, 신고자 정보 제거)
 */
async function deleteBondPostReports(uid: string) {
  try {
    const postsSnap = await db.collection("bondPosts").limit(500).get();
    if (postsSnap.empty) return;

    let totalCount = 0;

    for (const postDoc of postsSnap.docs) {
      const reportRef = postDoc.ref.collection("reports").doc(uid);
      const reportDoc = await reportRef.get();

      if (reportDoc.exists) {
        await reportRef.delete();
        totalCount++;
      }
    }

    console.log(`✅ bondPosts reports 삭제 완료: ${totalCount}개`);
  } catch (error) {
    console.error("❌ bondPosts reports 삭제 실패:", error);
  }
}

/**
 * 파트너 그룹에서 멤버 제거 + 빈 그룹 삭제
 */
async function removeFromPartnerGroups(uid: string) {
  try {
    const groupsSnap = await db
      .collection("partnerGroups")
      .where("memberUids", "array-contains", uid)
      .get();

    if (groupsSnap.empty) {
      console.log("✅ 소속 파트너 그룹 없음");
      return;
    }

    // 1단계: uid 제거
    const batch = db.batch();
    groupsSnap.docs.forEach((doc) => {
      batch.update(doc.ref, {
        memberUids: admin.firestore.FieldValue.arrayRemove(uid),
        activeMemberUids: admin.firestore.FieldValue.arrayRemove(uid),
      });
    });
    await batch.commit();
    console.log(`✅ 파트너 그룹에서 제거: ${groupsSnap.size}개`);

    // 2단계: 빈 그룹 삭제 (하위 컬렉션 포함)
    for (const doc of groupsSnap.docs) {
      const fresh = await doc.ref.get();
      const memberUids = (fresh.data()?.memberUids ?? []) as string[];

      if (memberUids.length === 0) {
        console.log(`🗑️ 빈 그룹 삭제 시작: ${doc.id}`);
        // @ts-ignore - recursiveDelete는 타입 정의가 없을 수 있음
        await db.recursiveDelete(doc.ref);
        console.log(`✅ 빈 그룹 삭제 완료: ${doc.id}`);
      }
    }
  } catch (error) {
    console.error("❌ 파트너 그룹 처리 실패:", error);
    throw error; // 중요한 작업이므로 에러 전파
  }
}

/**
 * 주간 목표 삭제
 */
async function deleteWeeklyGoals(uid: string) {
  try {
    const goalsSnap = await db
      .collection("weeklyGoals")
      .where(admin.firestore.FieldPath.documentId(), ">=", `${uid}_`)
      .where(admin.firestore.FieldPath.documentId(), "<", `${uid}_\uf8ff`)
      .get();

    if (goalsSnap.empty) {
      console.log("✅ 주간 목표 없음");
      return;
    }

    const batch = db.batch();
    goalsSnap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();

    console.log(`✅ 주간 목표 삭제 완료: ${goalsSnap.size}개`);
  } catch (error) {
    console.error("❌ 주간 목표 삭제 실패:", error);
  }
}

/**
 * 사용자 데이터 완전 삭제
 */
/**
 * 탈퇴 이력 저장 (재가입 온보딩 판단용)
 * deletedUsers/{uid} 에 deletedAt + signUpCount 누적
 */
async function saveDeletedUserRecord(uid: string) {
  try {
    const ref = db.collection("deletedUsers").doc(uid);
    const snap = await ref.get();
    const prevCount: number = snap.exists ? (snap.data()?.signUpCount ?? 0) : 0;

    await ref.set({
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
      signUpCount: prevCount + 1,
    });

    console.log(`✅ deletedUsers/${uid} 이력 저장 완료 (signUpCount=${prevCount + 1})`);
  } catch (error) {
    // 이력 저장 실패는 계정 삭제 자체를 막지 않음
    console.warn("⚠️ deletedUsers 이력 저장 실패 (무시):", error);
  }
}

async function deleteUserData(uid: string) {
  try {
    const userRef = db.collection("users").doc(uid);
    // @ts-ignore - recursiveDelete는 하위 컬렉션까지 삭제
    await db.recursiveDelete(userRef);
    console.log(`✅ users/${uid} 삭제 완료 (하위 컬렉션 포함)`);
  } catch (error) {
    console.error("❌ 사용자 데이터 삭제 실패:", error);
    throw error; // 중요한 작업이므로 에러 전파
  }
}

/**
 * Firebase Auth 계정 삭제
 */
async function deleteAuthAccount(uid: string) {
  try {
    await admin.auth().deleteUser(uid);
    console.log(`✅ Firebase Auth 계정 삭제 완료: ${uid}`);
  } catch (error) {
    console.error("❌ Auth 계정 삭제 실패:", error);
    throw error; // 가장 중요한 작업이므로 에러 전파
  }
}

/**
 * 📞 Callable Function: 계정 완전 삭제
 */
export const deleteMyAccount = functions
  .region("asia-northeast3")
  .https.onCall(async (data: any, context: functions.https.CallableContext) => {
    // 1. 인증 확인
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다."
      );
    }

    const uid = context.auth.uid;
    console.log(`🗑️ 계정 삭제 시작: ${uid}`);

    try {
      // ── 1단계: 익명화 (uid 흔적 제거) ──────────────────
      // bondPosts 익명화 (공개 피드 보호)
      await anonymizeBondPosts(uid);

      // partnerGroups 내 게시물 익명화
      await anonymizePartnerGroupPosts(uid);

      // partnerGroups 내 replies 익명화
      await anonymizePartnerGroupReplies(uid);

      // partnerGroups 내 reactions 익명화
      await anonymizePartnerGroupReactions(uid);

      // partnerGroups 내 enthrones 삭제 (docId = uid)
      await deletePartnerGroupEnthrones(uid);

      // partnerGroups activityLogs 익명화
      await anonymizePartnerGroupActivityLogs(uid);

      // 구직 지원 내역 익명화
      await anonymizeApplications(uid);

      // HIRA 댓글 익명화
      await anonymizeHiraComments(uid);

      // dailyWallPosts 익명화
      await anonymizeDailyWallPosts(uid);

      // dailyWallPosts reactions 삭제
      await deleteDailyWallReactions(uid);

      // bondPosts reports 삭제 (신고자 정보 제거)
      await deleteBondPostReports(uid);

      // ── 2단계: 개인 데이터 삭제 ────────────────────────
      // 주간 목표 삭제
      await deleteWeeklyGoals(uid);

      // ── 3단계: 그룹 멤버 제거 ──────────────────────────
      // (익명화 후 제거해야 쿼리가 정상 작동)
      await removeFromPartnerGroups(uid);

      // ── 4단계: Storage 삭제 ─────────────────────────────
      await Promise.all([
        deleteStorageByPrefix(`users/${uid}/`),
        deleteStorageByPrefix(`profileImages/${uid}/`),
        deleteStorageByPrefix(`avatars/${uid}/`),
      ]);

      // ── 5단계: Firestore 사용자 문서 삭제 ───────────────
      await deleteUserData(uid);

      // ── 5.5단계: 탈퇴 이력 저장 (재가입 온보딩 판단용) ──
      await saveDeletedUserRecord(uid);

      // ── 6단계: Auth 계정 삭제 (최후) ────────────────────
      await deleteAuthAccount(uid);

      console.log(`✅ 계정 삭제 완료: ${uid}`);
      return { success: true, message: "계정이 완전히 삭제되었습니다." };
    } catch (error) {
      console.error(`❌ 계정 삭제 실패: ${uid}`, error);
      throw new functions.https.HttpsError(
        "internal",
        `계정 삭제 중 오류가 발생했습니다: ${error}`
      );
    }
  });



