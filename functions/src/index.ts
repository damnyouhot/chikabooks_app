// 최신 v2 버전의 함수들을 import 합니다.
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";

// Firestore 앱 초기화
admin.initializeApp();
const db = admin.firestore();

/**
 * growthEvents 컬렉션에 새 문서가 생성될 때마다 트리거됩니다. (v2 구문)
 * 이벤트 유형에 따라 users/{uid}/stats 필드를 안전하게 업데이트합니다.
 */
export const onGrowthEventCreated = onDocumentCreated(
  "growthEvents/{eventId}", // 1. 감시할 문서 경로
  (event) => {                // 2. 이벤트가 발생했을 때 실행할 내용

    // 생성된 이벤트 데이터(주문서) 가져오기
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

    // 통계(stats)의 어느 필드를 업데이트할지 결정
    let fieldToUpdate: string;
    switch (type) {
      case "exercise":
        fieldToUpdate = "stepCount";
        break;
      case "sleep":
        fieldToUpdate = "sleepHours";
        break;
      case "study":
        fieldToUpdate = "studyMinutes";
        break;
      case "emotion":
      case "interaction":
        fieldToUpdate = "emotionPoints";
        break;
      case "stamp":
      case "quiz":
        fieldToUpdate = "quizCount";
        break;
      default:
        logger.log(`Unhandled event type: ${type}`);
        return;
    }

    const userRef = db.doc(`users/${userId}`);

    // users/{uid} 문서의 stats 필드 누적 (안전한 방식)
    try {
      userRef.set(
        {
          stats: {
            [fieldToUpdate]: admin.firestore.FieldValue.increment(value),
          },
        },
        { merge: true }
      );
      logger.log(
        `User ${userId} stats updated: ${fieldToUpdate} by ${value}`
      );
    } catch (error) {
      logger.error(
        `Failed to update stats for user ${userId}`,
        error
      );
    }
  }
);