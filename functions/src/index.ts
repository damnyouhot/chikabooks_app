import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

export const onGrowthEventCreated = onDocumentCreated(
  "growthEvents/{eventId}",
  (event) => {
    const snap = event.data;
    if (!snap) {
      logger.error("No data associated with the event", event);
      return;
    }
    const eventData = snap.data();
    const { userId, type, value } = eventData;

    if (!userId || !type || value === undefined) {
      logger.error("Missing fields in event data", eventData);
      return;
    }

    const userRef = db.doc(`users/${userId}`);
    let updates: { [key: string]: any } = {};

    // 각 활동 유형에 따라 적절한 스탯과 포인트를 함께 업데이트합니다.
    switch (type) {
      case "exercise":
        updates['stats.stepCount'] = admin.firestore.FieldValue.increment(value);
        updates['stats.emotionPoints'] = admin.firestore.FieldValue.increment(Math.round(value / 100)); // 100걸음당 1포인트
        break;
      case "sleep":
        updates['stats.sleepHours'] = admin.firestore.FieldValue.increment(value);
        updates['stats.emotionPoints'] = admin.firestore.FieldValue.increment(Math.round(value * 5)); // 1시간당 5포인트
        break;
      case "study":
        updates['stats.studyMinutes'] = admin.firestore.FieldValue.increment(value);
        updates['stats.emotionPoints'] = admin.firestore.FieldValue.increment(Math.round(value / 10)); // 10분당 1포인트
        break;
      case "emotion":
      case "interaction":
        updates['stats.emotionPoints'] = admin.firestore.FieldValue.increment(value);
        break;
      case "quiz":
        updates['stats.quizCount'] = admin.firestore.FieldValue.increment(value);
        updates['stats.emotionPoints'] = admin.firestore.FieldValue.increment(10); // 퀴즈 정답 시 10포인트
        break;
      default:
        logger.log(`Unhandled event type: ${type}`);
        return;
    }

    try {
      // set({}, {merge: true})를 사용하여 stats 필드 내의 특정 값들만 안전하게 업데이트
      userRef.set({ stats: updates }, { merge: true });
      logger.log(`User ${userId} stats updated:`, updates);
    } catch (error) {
      logger.error(`Failed to update stats for user ${userId}`, error);
    }
  }
);