/**
 * 속닥속닥(seniorQuestions) 최신 글 3개 + 댓글·답글 좋아요 수 조정
 *
 * 봇 앵커 버그로 과도하게 올라간 likeCount / cheerCount 를
 * "수정된 봇 로직 기준 현재 시각 기대값" 으로 낮춥니다.
 * 이미 기대값보다 낮으면 건드리지 않습니다 (감소만, 증가 없음).
 *
 * 실행: node tools/whisper-reset-recent-likes.cjs
 *       DRY_RUN=1 node tools/whisper-reset-recent-likes.cjs
 */

'use strict';
const { execSync } = require('child_process');
const https = require('https');
const os = require('os');
const fs = require('fs');
const path = require('path');

const DRY_RUN    = process.env.DRY_RUN === '1';
const PROJECT_ID = 'chikabooks3rd';
const BASE_URL   = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

// ── 봇과 동일한 상수 / 헬퍼 ──────────────────────────────────
const BASE_DAY0      = 9;
const DAILY_INC_MIN  = 5;
const DAILY_INC_SPAN = 4;
const PLATEAU_MIN    = 60;
const PLATEAU_SPAN   = 16;
const RATIO_MIN      = 0.8;
const RATIO_SPAN     = 0.1;

function hash01(s) {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); }
  return (h >>> 0) / 4294967296;
}
function ratio80to90(key)  { return RATIO_MIN + RATIO_SPAN * hash01(key); }
function likePlateau(qid)  { return PLATEAU_MIN + Math.floor(hash01(`${qid}|likePlateau`) * PLATEAU_SPAN); }
function dailyInc(qid, d)  { return DAILY_INC_MIN + Math.floor(hash01(`${qid}|likeStep|${d}`) * DAILY_INC_SPAN); }

function kstStartOfDay(ms) {
  const fmt = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Seoul', year: 'numeric', month: 'numeric', day: 'numeric'
  });
  const parts = fmt.formatToParts(new Date(ms));
  const get = t => parseInt(parts.find(p => p.type === t).value, 10);
  const y = get('year'), m = String(get('month')).padStart(2,'0'), d = String(get('day')).padStart(2,'0');
  return Date.parse(`${y}-${m}-${d}T00:00:00+09:00`);
}
function kstDayIndex(createdMs, nowMs) {
  return Math.round((kstStartOfDay(nowMs) - kstStartOfDay(createdMs)) / 86400000);
}
function fracDayElapsed(nowMs) {
  return Math.min(1, (nowMs - kstStartOfDay(nowMs)) / 86400000);
}
function buildChain(qid, plateau, upTo) {
  const t = [Math.min(plateau, BASE_DAY0)];
  for (let d = 1; d <= upTo; d++) t[d] = Math.min(plateau, t[d-1] + dailyInc(qid, d));
  return t;
}
function expectedNow(qid, createdMs, nowMs) {
  const dayIdx  = kstDayIndex(createdMs, nowMs);
  if (dayIdx < 0) return { like: 0, cheer: 0 };
  const phi     = fracDayElapsed(nowMs);
  const plateau = likePlateau(qid);
  const chain   = buildChain(qid, plateau, dayIdx);
  const end     = chain[dayIdx] ?? chain[chain.length - 1] ?? 0;
  const start   = dayIdx === 0 ? 0 : (chain[dayIdx - 1] ?? 0);
  const expLike = start + (end - start) * phi;
  const cheerR  = ratio80to90(`${qid}|cheerVsLike`);
  return { like: Math.round(expLike), cheer: Math.round(expLike * cheerR) };
}
function expComment(qid, cid, expLike)       { return Math.round(expLike * ratio80to90(`${qid}|${cid}|commentVsBody`)); }
function expReply(qid, cid, rid, expCL)      { return Math.round(expCL   * ratio80to90(`${qid}|${cid}|${rid}|replyVsComment`)); }

// ── Firestore REST 헬퍼 ───────────────────────────────────────
let _token = null;
function getToken() {
  if (_token) return _token;
  _token = execSync('gcloud auth print-access-token', { encoding: 'utf8' }).trim();
  return _token;
}

function fsRequest(method, urlPath, body) {
  return new Promise((resolve, reject) => {
    const token  = getToken();
    const data   = body ? JSON.stringify(body) : null;
    const url    = new URL(BASE_URL + urlPath);
    const opts = {
      hostname: url.hostname,
      path:     url.pathname + url.search,
      method,
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type':  'application/json',
        ...(data ? { 'Content-Length': Buffer.byteLength(data) } : {}),
      },
    };
    const req = https.request(opts, res => {
      let raw = '';
      res.on('data', c => raw += c);
      res.on('end', () => {
        if (res.statusCode >= 400) return reject(new Error(`HTTP ${res.statusCode}: ${raw}`));
        resolve(JSON.parse(raw || '{}'));
      });
    });
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

/** Firestore REST 문서 → 필드 값 추출 */
function fv(doc, field) {
  const v = doc.fields?.[field];
  if (!v) return 0;
  if ('integerValue' in v) return parseInt(v.integerValue, 10);
  if ('doubleValue'  in v) return v.doubleValue;
  return 0;
}
/** Firestore 문서 이름에서 ID만 추출 */
function docId(name) { return name.split('/').pop(); }

/** Firestore PATCH: 특정 필드만 업데이트 */
async function patchFields(docName, fields) {
  const fieldPaths = Object.keys(fields).map(k => `updateMask.fieldPaths=${encodeURIComponent(k)}`).join('&');
  const body = {
    fields: Object.fromEntries(
      Object.entries(fields).map(([k, v]) => [k, { integerValue: String(v) }])
    ),
  };
  // PATCH는 절대 경로 사용
  const relPath = docName.replace(`projects/${PROJECT_ID}/databases/(default)/documents`, '');
  await fsRequest('PATCH', `${relPath}?${fieldPaths}`, body);
}

// ── 메인 ─────────────────────────────────────────────────────
async function main() {
  console.log(DRY_RUN ? '[DRY RUN] 실제 쓰기 없음\n' : '[LIVE] Firestore 업데이트\n');
  const nowMs = Date.now();

  // 최신 글 3개 (createdAt desc)
  const qRes = await fsRequest('GET',
    '/seniorQuestions?orderBy=createdAt%20desc&pageSize=3'
  );
  const qDocs = qRes.documents ?? [];
  if (qDocs.length === 0) { console.log('글이 없습니다.'); return; }

  for (const qDoc of qDocs) {
    const qid = docId(qDoc.name);
    const isDeleted = qDoc.fields?.isDeleted?.booleanValue;
    const isHidden  = qDoc.fields?.isHidden?.booleanValue;
    if (isDeleted || isHidden) { console.log(`[SKIP] ${qid} (삭제/숨김)`); continue; }

    // createdAt 읽기
    const tsStr = qDoc.fields?.createdAt?.timestampValue;
    if (!tsStr) { console.log(`[SKIP] ${qid} (createdAt 없음)`); continue; }
    const createdMs = new Date(tsStr).getTime();

    const { like: expLike, cheer: expCheer } = expectedNow(qid, createdMs, nowMs);
    const curLike  = fv(qDoc, 'likeCount');
    const curCheer = fv(qDoc, 'cheerCount');
    const newLike  = Math.min(curLike,  expLike);
    const newCheer = Math.min(curCheer, expCheer);

    console.log(`[Q] ${qid}`);
    console.log(`    likeCount : ${curLike} → ${newLike}  (기대값 ${expLike})`);
    console.log(`    cheerCount: ${curCheer} → ${newCheer}  (기대값 ${expCheer})`);

    if (!DRY_RUN) {
      const upd = {};
      if (newLike  !== curLike)  upd.likeCount  = newLike;
      if (newCheer !== curCheer) upd.cheerCount = newCheer;
      if (Object.keys(upd).length) await patchFields(qDoc.name, upd);
    }

    // 댓글 (최신 14개)
    const cRes = await fsRequest('GET',
      `/${encodeURIComponent('seniorQuestions')}/${qid}/comments?orderBy=createdAt%20desc&pageSize=14`
    );
    for (const cDoc of (cRes.documents ?? [])) {
      const cid = docId(cDoc.name);
      if (cDoc.fields?.isDeleted?.booleanValue || cDoc.fields?.isHidden?.booleanValue) continue;

      const expCL = expComment(qid, cid, expLike);
      const curCL = fv(cDoc, 'likeCount');
      const newCL = Math.min(curCL, expCL);
      console.log(`  [C] ${cid}  likeCount: ${curCL} → ${newCL}  (기대값 ${expCL})`);
      if (!DRY_RUN && newCL !== curCL) await patchFields(cDoc.name, { likeCount: newCL });

      // 답글 (최신 8개)
      const rRes = await fsRequest('GET',
        `/seniorQuestions/${qid}/comments/${cid}/replies?orderBy=createdAt%20desc&pageSize=8`
      );
      for (const rDoc of (rRes.documents ?? [])) {
        const rid = docId(rDoc.name);
        if (rDoc.fields?.isDeleted?.booleanValue) continue;
        const expRL = expReply(qid, cid, rid, expCL);
        const curRL = fv(rDoc, 'likeCount');
        const newRL = Math.min(curRL, expRL);
        console.log(`    [R] ${rid}  likeCount: ${curRL} → ${newRL}  (기대값 ${expRL})`);
        if (!DRY_RUN && newRL !== curRL) await patchFields(rDoc.name, { likeCount: newRL });
      }
    }
    console.log();
  }
  console.log('완료.');
}

main().catch(e => { console.error(e); process.exit(1); });
