/**
 * 오늘 단어 전역 일별 턴 — KST 자정에 `daily_word_turns/{dateKey}` 기록.
 * (대시보드 풀 소모 집계·Dart `DailyWordService.ensureTurnHistoryThroughToday` 와 동일 시드)
 */

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const META_PATH = "daily_word_meta/state";
const TURNS = "daily_word_turns";
const DAILY_COUNT = 3;
const POOL_TRACKING_START = "2026-04-28";

function toDateKey(date: Date): string {
  const kst = new Date(date.getTime() + 9 * 60 * 60 * 1000);
  const yyyy = kst.getUTCFullYear();
  const mm = String(kst.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(kst.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

function stableSeed(input: string): number {
  let hash = 0x811c9dc5;
  for (let i = 0; i < input.length; i++) {
    hash ^= input.charCodeAt(i);
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

function mulberry32(seed: number): () => number {
  return () => {
    let t = (seed += 0x6d2b79f5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function shuffleStable<T>(arr: T[], seedInput: string): T[] {
  const a = [...arr];
  const rand = mulberry32(stableSeed(seedInput));
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

interface WordRow {
  id: string;
  order: number;
  english: string;
  isActive: boolean;
}

/** Dart `DailyWordService._syncActiveWordIndexToMeta` 가 채운 인덱스 */
async function loadActiveWordsFromMeta(
  db: admin.firestore.Firestore,
): Promise<WordRow[]> {
  const meta = await db.doc(META_PATH).get();
  const raw = meta.data()?.activeWordIndex as
    | Array<{ id?: string; order?: number; isActive?: boolean }>
    | undefined;
  if (!raw?.length) return [];
  return raw
    .filter((w) => w.isActive !== false && w.id)
    .map((w) => ({
      id: w.id as string,
      order: (w.order as number) ?? 0,
      english: "",
      isActive: true,
    }));
}

async function consumedBeforeDate(
  db: admin.firestore.Firestore,
  beforeDateKey: string,
  manualExcluded: Set<string>,
): Promise<Set<string>> {
  const consumed = new Set(manualExcluded);
  const snap = await db
    .collection(TURNS)
    .where(admin.firestore.FieldPath.documentId(), ">=", POOL_TRACKING_START)
    .where(admin.firestore.FieldPath.documentId(), "<", beforeDateKey)
    .get();
  for (const doc of snap.docs) {
    const ids = doc.data().wordIds as string[] | undefined;
    if (ids) ids.forEach((id) => consumed.add(id));
  }
  return consumed;
}

function pickForDate(
  dateKey: string,
  activeWords: WordRow[],
  consumed: Set<string>,
): WordRow[] {
  const candidates = activeWords
    .filter((w) => !consumed.has(w.id))
    .sort((a, b) => a.order - b.order);
  if (!candidates.length) return [];
  const shuffled = shuffleStable(
    candidates,
    `${dateKey}|global|${candidates.length}`,
  );
  return shuffled.slice(0, DAILY_COUNT);
}

/**
 * 해당 날짜 턴이 없으면 생성. [activeWords] 는 호출 측에서 넘기거나 embedded 메타 사용.
 */
export async function ensureDailyWordTurnForDate(
  db: admin.firestore.Firestore,
  dateKey: string,
  activeWords?: WordRow[],
): Promise<{ created: boolean; wordIds: string[] }> {
  const turnRef = db.collection(TURNS).doc(dateKey);
  const existing = await turnRef.get();
  if (existing.exists) {
    const ids = (existing.data()?.wordIds as string[]) ?? [];
    return { created: false, wordIds: ids };
  }

  const metaDoc = await db.doc(META_PATH).get();
  const meta = metaDoc.data() ?? {};
  const manual = new Set<string>(
    ((meta.skippedWordIds as string[]) ?? []).filter(Boolean),
  );
  const words = activeWords ?? (await loadActiveWordsFromMeta(db));
  if (!words.length) {
    functions.logger.warn(
      "scheduleDailyWordTurn: activeWordIndex 없음 — 앱/어드민에서 풀 동기화 필요",
    );
    return { created: false, wordIds: [] };
  }

  const consumed = await consumedBeforeDate(db, dateKey, manual);
  const picked = pickForDate(dateKey, words, consumed);
  const wordIds = picked.map((w) => w.id);
  if (!wordIds.length) return { created: false, wordIds: [] };

  await turnRef.set({
    dateKey,
    wordIds,
    selectionMode: "stableRandom",
    selectionVersion: "stable_random_v1",
    seedScope: "global",
    recordedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await db.doc(META_PATH).set(
    {
      poolTrackingStartDateKey:
        (meta.poolTrackingStartDateKey as string) || POOL_TRACKING_START,
      lastRecordedTurnDateKey: dateKey,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return { created: true, wordIds };
}

export const scheduleDailyWordTurn = functions
  .region("us-central1")
  .pubsub.schedule("5 0 * * *")
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    const db = admin.firestore();
    const dateKey = toDateKey(new Date());
    const result = await ensureDailyWordTurnForDate(db, dateKey);
    functions.logger.info("scheduleDailyWordTurn", { dateKey, ...result });
    return null;
  });
