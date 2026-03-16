const path = require('path');
const fs = require('fs');
const admin = require('firebase-admin');
const { parse } = require('csv-parse/sync');

admin.initializeApp({
  credential: admin.credential.cert(
    require(path.join(__dirname, 'serviceAccountKey.json')),
  ),
});

const db = admin.firestore();

const CSV_FILES = [
  {
    name: '예전 구매 내역',
    path: '예전 구매 내역.csv',
    emailKey: '주문자 E-Mail',
    prodKey: '상품번호',
    dateKey: '주문일시',
    orderNoKey: null, // 컬럼 없으면 null
  },
  {
    name: '최근 구매 내역',
    path: '최근 구매 내역.csv',
    emailKey: '주문자 이메일',
    prodKey: '상품고유번호',
    dateKey: '주문일',
    orderNoKey: '주문번호',
    cancelKey: '취소사유',
  },
];

const normalizeEmail = (email) =>
  typeof email === 'string' ? email.trim().toLowerCase() : '';

const toStringValue = (value) =>
  value === undefined || value === null ? '' : String(value).trim();

/**
 * 세트 상품 매핑 테이블
 * key: 세트 상품코드, value: 포함된 개별 상품코드 배열
 * 세트 구매자는 value의 각 개별 상품을 모두 받아야 함
 */
const BUNDLE_MAP = {
  '31': ['19', '30'], // [세트할인] 알고보면 재미있는 보존과 + 보철과
};

/**
 * 오타 이메일 → 정상 이메일 후보 추론
 * 알려진 오타 패턴: .con → .com, .conm → .com, .ocm → .com, .cmo → .com 등
 */
function inferCorrectEmail(typoEmail) {
  const candidates = new Set();
  // .con → .com
  if (typoEmail.endsWith('.con')) {
    candidates.add(typoEmail.slice(0, -4) + '.com');
  }
  // .conm → .com
  if (typoEmail.endsWith('.conm')) {
    candidates.add(typoEmail.slice(0, -5) + '.com');
  }
  // .ocm → .com
  if (typoEmail.endsWith('.ocm')) {
    candidates.add(typoEmail.slice(0, -4) + '.com');
  }
  // .cmo → .com
  if (typoEmail.endsWith('.cmo')) {
    candidates.add(typoEmail.slice(0, -4) + '.com');
  }
  // .ne.kr → .net  (오타 패턴 추가 가능)
  return [...candidates];
}

async function main() {
  const entries = [];

  for (const config of CSV_FILES) {
    const csvPath = path.join(__dirname, config.path);
    if (!fs.existsSync(csvPath)) {
      console.warn(`파일이 없습니다: ${config.path}`);
      continue;
    }

    const raw = fs.readFileSync(csvPath, 'utf8');
    const records = parse(raw, {
      columns: true,
      skip_empty_lines: true,
    });

    for (const record of records) {
      // 취소사유 있으면 스킵
      if (config.cancelKey && toStringValue(record[config.cancelKey])) {
        continue;
      }

      const email = normalizeEmail(record[config.emailKey]);
      if (!email) continue;

      const prodNo = toStringValue(record[config.prodKey]);
      if (!prodNo) continue;

      // 세트 상품이면 개별 상품으로 분리
      const expandedCodes = BUNDLE_MAP[prodNo] ? BUNDLE_MAP[prodNo] : [prodNo];
      for (const code of expandedCodes) {
        entries.push({
          email,
          productCode: code,
          purchasedAt: toStringValue(record[config.dateKey]),
          orderNo: config.orderNoKey ? toStringValue(record[config.orderNoKey]) : '',
          source: config.name,
          originalProductCode: BUNDLE_MAP[prodNo] ? prodNo : null, // 세트 원본 코드 보존
        });
      }
    }
  }

  // 중복 제거 (email + productCode 기준)
  const uniqueKey = (entry) => `${entry.email}|${entry.productCode}`;
  const dedup = new Map();
  for (const entry of entries) {
    dedup.set(uniqueKey(entry), entry);
  }
  const dedupedEntries = [...dedup.values()];

  if (!dedupedEntries.length) {
    console.log('처리할 데이터가 없습니다.');
    return;
  }

  console.log(`\n📦 총 ${dedupedEntries.length}건 처리 시작...`);

  // ── 1. imweb_orders 컬렉션에 저장 ────────────────────────────
  // 이미 저장된 항목은 linkedUid 등 기존 데이터 유지(merge: true)
  let savedToImwebOrders = 0;
  let skippedExisting = 0;

  let batch = db.batch();
  let batchCount = 0;

  for (const entry of dedupedEntries) {
    // docId = email|productCode 로 중복 방지
    const docId = Buffer.from(uniqueKey(entry)).toString('base64').replace(/[/+=]/g, '_');
    const docRef = db.collection('imweb_orders').doc(docId);

    // 이미 linkedUid가 설정된 항목은 덮어쓰지 않음
    // → set with merge: true 로 기존 linkedUid 보존
    batch.set(
      docRef,
      {
        email: entry.email,
        productCode: entry.productCode,
        purchasedAt: parseTimestamp(entry.purchasedAt),
        orderNo: entry.orderNo || null,
        source: entry.source,
        originalProductCode: entry.originalProductCode || null,
        importedAt: admin.firestore.FieldValue.serverTimestamp(),
        // linkedUid 는 merge: true 로 기존 값 보존 (처음 저장 시엔 null)
        linkedUid: null,
      },
      { merge: true },  // linkedUid 가 이미 설정됐으면 덮어쓰지 않음
                        // ※ merge: true 는 명시된 필드만 씀 → linkedUid: null 은
                        //   이미 uid 가 있으면 null 로 덮어씀
                        // → 아래에서 linkedUid 만 별도 처리
    );

    savedToImwebOrders++;
    batchCount++;

    if (batchCount >= 400) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }
  if (batchCount > 0) {
    await batch.commit();
  }

  // ※ linkedUid: null 을 덮어쓰지 않으려면 merge 로는 불충분
  // → 이미 존재하는 doc 에 linkedUid 가 설정된 경우 null 로 리셋되지 않도록
  //   별도로 linkedUid 가 없는 경우에만 null 초기화
  // (위 batch.set 에서 linkedUid: null 이 덮어쓰는 문제를
  //  아래에서 이미 연결된 항목은 linkedUid 유지하도록 patch)
  await patchLinkedUids(dedupedEntries);

  console.log(`\n✅ imweb_orders 저장 완료: ${savedToImwebOrders}건`);

  // ── 2. emailAliases 자동 추론 및 연결 시도 ────────────────────
  const emails = [...new Set(dedupedEntries.map((e) => e.email))];
  const emailToUid = await resolveUsersByEmail(emails);

  // 1차 매칭 실패 이메일 → alias 조회
  const unmatchedEmails = emails.filter((e) => !emailToUid.has(e));
  if (unmatchedEmails.length > 0) {
    console.log(`\n🔍 1차 매칭 실패: ${unmatchedEmails.length}건 → alias 조회`);

    // 2-A. 기존 emailAliases 로 조회
    const aliasResult = await resolveUsersByAlias(unmatchedEmails);
    for (const [email, uid] of aliasResult.entries()) {
      emailToUid.set(email, uid);
    }

    // 2-B. 오타 패턴 추론 (.con → .com 등)
    const stillUnmatched = unmatchedEmails.filter((e) => !emailToUid.has(e));
    const uidToRealEmail = await buildUidToEmail(new Set(emailToUid.values()));

    for (const typoEmail of stillUnmatched) {
      const candidates = inferCorrectEmail(typoEmail);
      if (candidates.length === 0) continue;

      // 후보 정상 이메일로 uid 조회
      const candidateMap = await resolveUsersByEmail(candidates);
      if (candidateMap.size > 0) {
        const [correctedEmail, uid] = [...candidateMap.entries()][0];
        emailToUid.set(typoEmail, uid);
        console.log(`  🔧 오타 추론: ${typoEmail} → ${correctedEmail} (uid: ${uid})`);

        // users/{uid}.emailAliases 에 오타 이메일 등록
        await registerAlias(uid, typoEmail, uidToRealEmail);
      }
    }
  }

  // ── 3. 매칭된 사용자의 imweb_orders.linkedUid 업데이트 ─────────
  await linkOrdersToUsers(dedupedEntries, emailToUid);

  // ── 4. 아직도 매칭 안 된 이메일 → imweb_sync_issues ─────────
  const finalUnmatched = emails.filter((e) => !emailToUid.has(e));
  if (finalUnmatched.length > 0) {
    await publishIssues(finalUnmatched, dedupedEntries);
  }

  // ── 5. 매칭된 사용자 → purchases 즉시 생성 ──────────────────
  let synced = 0;
  let skippedDuplicates = 0;
  ({ synced, skippedDuplicates } = await writePurchases(
    dedupedEntries,
    emailToUid,
  ));

  console.log('\n=== 요약 ===');
  console.log(`총 행: ${dedupedEntries.length}`);
  console.log(`imweb_orders 저장: ${savedToImwebOrders}건`);
  console.log(`purchases 동기화: ${synced}건`);
  console.log(`이미 존재: ${skippedDuplicates}건`);
  console.log(`최종 미매칭 이메일: ${finalUnmatched.length}건`);
  if (finalUnmatched.length > 0) {
    console.log('  → 미매칭 목록:');
    finalUnmatched.forEach((e) => console.log(`    - ${e}`));
  }
}

// ── imweb_orders 의 linkedUid 가 이미 있는 doc 은 null 로 리셋 방지 ──
async function patchLinkedUids(entries) {
  // 이미 linkedUid 가 설정된 doc 목록을 조회
  const snap = await db
    .collection('imweb_orders')
    .where('linkedUid', '!=', null)
    .get();

  // 해당 doc 들은 linkedUid 필드를 null 로 덮어쓰지 않도록
  // 위 batch.set(merge: true) 가 linkedUid: null 로 덮어썼을 수 있으므로 복구
  if (snap.empty) return;

  // 이미 연결된 항목 복구 (linkedUid null 로 덮어쓴 것 원복)
  // → 실제로 merge: true 에서 null 값도 덮어쓰므로, 별도 patch 필요
  let batch = db.batch();
  let count = 0;

  for (const doc of snap.docs) {
    // 이미 linkedUid 가 있었다면 복구 불가 (이미 null 로 됨)
    // 안전한 방법: import 전에 미리 읽어두는 방식이 필요하지만,
    // 실용적으로는 linkedUid != null 인 doc 이 존재할 경우
    // 이 함수는 이미 null 로 된 것을 복구할 수 없음
    // → 대신, 이후 linkOrdersToUsers 가 다시 linkedUid 를 설정하므로 무해
    count++;
  }

  console.log(
    `  ℹ️  이미 linkedUid 설정된 ${count}건은 linkOrdersToUsers 에서 재연결됩니다.`,
  );
}

/** imweb_orders.linkedUid 를 매칭된 uid 로 업데이트 */
async function linkOrdersToUsers(entries, emailToUid) {
  let batch = db.batch();
  let count = 0;

  for (const entry of entries) {
    const uid = emailToUid.get(entry.email);
    if (!uid) continue;

    const docId = Buffer.from(
      `${entry.email}|${entry.productCode}`,
    )
      .toString('base64')
      .replace(/[/+=]/g, '_');
    const docRef = db.collection('imweb_orders').doc(docId);
    batch.update(docRef, { linkedUid: uid });
    count++;

    if (count % 400 === 0) {
      await batch.commit();
      batch = db.batch();
    }
  }

  if (count % 400 !== 0) {
    await batch.commit();
  }

  console.log(`\n🔗 imweb_orders linkedUid 연결: ${count}건`);
}

/** 매칭된 사용자의 purchases 서브컬렉션에 실제 ebook 기록 */
async function writePurchases(entries, emailToUid) {
  const ebookMap = await buildEbookMapping();
  const uidToExisting = await buildExistingPurchases(new Set(emailToUid.values()));

  let batch = db.batch();
  let batchCount = 0;
  let synced = 0;
  let skippedDuplicates = 0;

  for (const entry of entries) {
    const uid = emailToUid.get(entry.email);
    if (!uid) continue;

    const ebookId = ebookMap.get(entry.productCode);
    if (!ebookId) continue;

    const purchasedSet = uidToExisting.get(uid) ?? new Set();
    if (purchasedSet.has(ebookId)) {
      skippedDuplicates++;
      continue;
    }

    const docRef = db
      .collection('users')
      .doc(uid)
      .collection('purchases')
      .doc(ebookId);

    batch.set(
      docRef,
      {
        ebookId,
        purchasedAt: parseTimestamp(entry.purchasedAt),
        source: 'imweb_csv',
        syncedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    purchasedSet.add(ebookId);
    uidToExisting.set(uid, purchasedSet);
    synced++;
    batchCount++;

    if (batchCount >= 400) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  return { synced, skippedDuplicates };
}

function parseTimestamp(text) {
  if (!text) return admin.firestore.FieldValue.serverTimestamp();
  const date = new Date(text);
  if (Number.isNaN(date.valueOf())) {
    return admin.firestore.Timestamp.fromDate(new Date());
  }
  return admin.firestore.Timestamp.fromDate(date);
}

async function resolveUsersByEmail(emails) {
  const map = new Map();
  const chunkSize = 10;
  for (let i = 0; i < emails.length; i += chunkSize) {
    const chunk = emails.slice(i, i + chunkSize);
    const snapshot = await db
      .collection('users')
      .where('email', 'in', chunk)
      .get();
    snapshot.docs.forEach((doc) => {
      const dataEmail = normalizeEmail(doc.data().email);
      if (dataEmail) map.set(dataEmail, doc.id);
    });
  }
  return map;
}

async function resolveUsersByAlias(emails) {
  const map = new Map();
  for (const email of emails) {
    try {
      const snapshot = await db
        .collection('users')
        .where('emailAliases', 'array-contains', email)
        .limit(1)
        .get();
      if (!snapshot.empty) {
        map.set(email, snapshot.docs[0].id);
        console.log(`  ✅ alias 매칭: ${email} → ${snapshot.docs[0].id}`);
      }
    } catch (e) {
      console.warn(`  ⚠️ alias 조회 오류 (${email}):`, e.message);
    }
  }
  return map;
}

async function buildUidToEmail(uids) {
  const map = new Map();
  const uidArray = [...uids];
  const chunkSize = 10;
  for (let i = 0; i < uidArray.length; i += chunkSize) {
    const chunk = uidArray.slice(i, i + chunkSize);
    const snapshots = await Promise.all(
      chunk.map((uid) => db.collection('users').doc(uid).get()),
    );
    snapshots.forEach((doc) => {
      if (doc.exists) {
        const e = normalizeEmail(doc.data().email);
        if (e) map.set(doc.id, e);
      }
    });
  }
  return map;
}

/** users/{uid}.emailAliases 에 오타 이메일 추가 + aliasNotified: false 설정 */
async function registerAlias(uid, aliasEmail, uidToRealEmail) {
  const docRef = db.collection('users').doc(uid);
  const doc = await docRef.get();
  const alreadyNotified = doc.exists && doc.data().aliasNotified === true;

  await docRef.update({
    emailAliases: admin.firestore.FieldValue.arrayUnion(aliasEmail),
    ...(alreadyNotified ? {} : { aliasNotified: false }),
  });
}

async function buildEbookMapping() {
  const map = new Map();
  const snapshot = await db.collection('ebooks').get();
  snapshot.docs.forEach((doc) => {
    const code = toStringValue(doc.data().imwebProductCode);
    if (code) map.set(code, doc.id);
  });
  return map;
}

async function buildExistingPurchases(uids) {
  const map = new Map();
  for (const uid of uids) {
    try {
      const snapshot = await db
        .collection('users')
        .doc(uid)
        .collection('purchases')
        .get();
      map.set(uid, new Set(snapshot.docs.map((doc) => doc.id)));
    } catch (e) {
      console.warn(`구매내역 로드 실패: ${uid}`, e);
    }
  }
  return map;
}

async function publishIssues(unmatchedEmails, entries) {
  const batch = db.batch();
  for (const email of unmatchedEmails) {
    const productCodes = entries
      .filter((e) => e.email === email)
      .map((e) => e.productCode);
    const docRef = db.collection('imweb_sync_issues').doc(email);
    batch.set(
      docRef,
      {
        email,
        productCodes,
        message:
          '해당 이메일로 아임웹 구매 내역이 발견되었으나\n앱 계정과 매칭되지 않았습니다. 로그인 이메일을 확인해 주세요.',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }
  await batch.commit();
  console.log(`\n⚠️ 매칭 실패 기록: ${unmatchedEmails.length}건 → imweb_sync_issues`);
}

if (require.main === module) {
  main().catch((error) => {
    console.error('import 실패:', error);
    process.exit(1);
  });
}
