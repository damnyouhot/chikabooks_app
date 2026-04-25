import * as admin from "firebase-admin";

/**
 * walletOps.ts
 *
 * 지갑(공고권 + 충전 잔액)에 대한 서버 전용 트랜잭션 유틸.
 *
 * 모든 함수는 단일 Firestore 트랜잭션에서 실행되도록 설계되어,
 * 잔액·ledger·만료 큐가 항상 일관된 상태를 유지한다.
 *
 * 클라이언트는 이 모듈을 직접 호출할 수 없고, Cloud Function 내부에서만
 * 사용된다(보안 룰로 wallets/* 쓰기 차단).
 */

export type LedgerType =
  | "voucher_use"
  | "voucher_charge"
  | "credit_use"
  | "credit_charge"
  | "credit_refund";

export interface VoucherEntryDoc {
  source: "purchase" | "promo" | "refund";
  qty: number;
  issuedAt: admin.firestore.Timestamp;
  expiresAt?: admin.firestore.Timestamp;
}

export interface WalletDoc {
  vouchers: number;
  creditBalance: number;
  creditLastUsedAt?: admin.firestore.Timestamp;
  voucherEntries: VoucherEntryDoc[];
  updatedAt: admin.firestore.Timestamp;
}

const EMPTY_WALLET: Omit<WalletDoc, "updatedAt"> = {
  vouchers: 0,
  creditBalance: 0,
  voucherEntries: [],
};

/**
 * wallets/{uid} 문서 참조.
 *
 * @param {string} uid 지갑 소유자 UID
 * @return {FirebaseFirestore.DocumentReference} 문서 참조
 */
function walletRef(uid: string) {
  return admin.firestore().collection("wallets").doc(uid);
}

/**
 * wallets/{uid}/ledger 서브컬렉션 참조.
 *
 * @param {string} uid 지갑 소유자 UID
 * @return {FirebaseFirestore.CollectionReference} 컬렉션 참조
 */
function ledgerRef(uid: string) {
  return walletRef(uid).collection("ledger");
}

/**
 * 빈 지갑(잔액·이력 없음)을 안전하게 머지 — 신규 사용자에서 호출.
 * 기존 잔액이 있으면 덮어쓰지 않는다.
 *
 * @param {string} uid 지갑 소유자 UID
 * @return {Promise<void>}
 */
export async function ensureWallet(uid: string): Promise<void> {
  const ref = walletRef(uid);
  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists) return;
    tx.set(ref, {
      ...EMPTY_WALLET,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

interface ChargeVoucherParams {
  uid: string;
  qty: number;
  expiryMonths: number;
  source?: "purchase" | "promo" | "refund";
  orderId?: string;
  label?: string;
}

/**
 * 공고권 충전(증액). 만료 큐(`voucherEntries`)에 1개 entry 추가.
 *
 * 이 함수는 일반적으로 결제 검증 직후 같은 트랜잭션에서 호출되어야 한다.
 *
 * @param {ChargeVoucherParams} params 충전 파라미터
 * @return {Promise<{balanceAfter: number}>} 충전 후 공고권 잔액
 */
export async function chargeVouchers(
  params: ChargeVoucherParams
): Promise<{ balanceAfter: number }> {
  const {uid, qty, expiryMonths, source = "purchase", orderId, label} = params;
  if (qty <= 0) throw new Error("qty must be positive");

  const ref = walletRef(uid);
  const ledger = ledgerRef(uid).doc();

  const issuedAt = admin.firestore.Timestamp.now();
  const expiresAt = admin.firestore.Timestamp.fromMillis(
    issuedAt.toMillis() + expiryMonths * 30 * 24 * 60 * 60 * 1000
  );

  return admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = (snap.exists ? snap.data() : {...EMPTY_WALLET}) as WalletDoc;

    const newBalance = (data.vouchers ?? 0) + qty;
    const entries = Array.isArray(data.voucherEntries) ?
      [...data.voucherEntries] :
      [];
    entries.push({source, qty, issuedAt, expiresAt});

    tx.set(
      ref,
      {
        vouchers: newBalance,
        voucherEntries: entries,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );

    tx.set(ledger, {
      type: "voucher_charge" satisfies LedgerType,
      delta: qty,
      balanceAfter: newBalance,
      orderId: orderId ?? null,
      label: label ?? `공고권 ${qty}장 충전`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {balanceAfter: newBalance};
  });
}

interface ChargeCreditParams {
  uid: string;
  amount: number;
  bonus?: number;
  orderId?: string;
  label?: string;
}

/**
 * 충전 잔액 증액. `bonus` 가 있으면 ledger 라벨에 기록한다.
 *
 * @param {ChargeCreditParams} params 충전 파라미터
 * @return {Promise<{balanceAfter: number}>} 충전 후 충전 잔액
 */
export async function chargeCredit(
  params: ChargeCreditParams
): Promise<{ balanceAfter: number }> {
  const {uid, amount, bonus = 0, orderId, label} = params;
  if (amount <= 0) throw new Error("amount must be positive");

  const ref = walletRef(uid);
  const ledger = ledgerRef(uid).doc();
  const totalIn = amount + bonus;

  return admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = (snap.exists ? snap.data() : {...EMPTY_WALLET}) as WalletDoc;

    const newBalance = (data.creditBalance ?? 0) + totalIn;

    tx.set(
      ref,
      {
        creditBalance: newBalance,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );

    tx.set(ledger, {
      type: "credit_charge" satisfies LedgerType,
      delta: totalIn,
      balanceAfter: newBalance,
      orderId: orderId ?? null,
      label:
        label ??
        (bonus > 0 ?
          `충전 ${amount.toLocaleString()}원 + 보너스 ${bonus.toLocaleString()}원` :
          `충전 ${amount.toLocaleString()}원`),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {balanceAfter: newBalance};
  });
}

interface UseForJobParams {
  uid: string;
  /** 공고 1건당 비용(원). 충전 잔액 차감 시에만 사용. */
  jobPriceWon: number;
  orderId: string;
  /** 공고권만 / 충전만 / 둘 다 모드 */
  mode: "voucher" | "credit" | "both";
}

export interface UseForJobResult {
  paidWith: "voucher" | "credit" | "insufficient";
  voucherAfter: number;
  creditAfter: number;
}

/**
 * 공고 1건 게시 시 잔액에서 자동 차감.
 *
 * - mode=voucher: 공고권 1장만 차감. 부족 시 'insufficient'
 * - mode=credit:  jobPriceWon 만큼 충전 잔액 차감. 부족 시 'insufficient'
 * - mode=both:    공고권 우선 차감, 없으면 충전 잔액에서 차감
 *
 * 가장 앞에 있는(만료 임박) voucherEntry 부터 차감한다.
 *
 * @param {UseForJobParams} params 차감 파라미터
 * @return {Promise<UseForJobResult>} 차감 결과 + 잔액 스냅샷
 */
export async function useForJobPosting(
  params: UseForJobParams
): Promise<UseForJobResult> {
  const {uid, jobPriceWon, orderId, mode} = params;
  const ref = walletRef(uid);
  const ledger = ledgerRef(uid).doc();

  return admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = (snap.exists ? snap.data() : {...EMPTY_WALLET}) as WalletDoc;

    const vouchers = data.vouchers ?? 0;
    const credit = data.creditBalance ?? 0;
    const entries = Array.isArray(data.voucherEntries) ?
      [...data.voucherEntries].sort((a, b) => {
        const ax = a.expiresAt?.toMillis() ?? Number.MAX_SAFE_INTEGER;
        const bx = b.expiresAt?.toMillis() ?? Number.MAX_SAFE_INTEGER;
        return ax - bx;
      }) :
      [];

    const tryVoucher = mode !== "credit" && vouchers > 0;
    const tryCredit = mode !== "voucher" && credit >= jobPriceWon;

    if (tryVoucher) {
      const newVouchers = vouchers - 1;
      // 가장 앞 엔트리에서 1장 차감
      let remaining = 1;
      const updated: VoucherEntryDoc[] = [];
      for (const e of entries) {
        if (remaining > 0 && e.qty > 0) {
          const take = Math.min(e.qty, remaining);
          remaining -= take;
          if (e.qty - take > 0) updated.push({...e, qty: e.qty - take});
        } else {
          updated.push(e);
        }
      }

      tx.set(
        ref,
        {
          vouchers: newVouchers,
          voucherEntries: updated,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true}
      );
      tx.set(ledger, {
        type: "voucher_use" satisfies LedgerType,
        delta: -1,
        balanceAfter: newVouchers,
        orderId,
        label: "공고 게시",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        paidWith: "voucher",
        voucherAfter: newVouchers,
        creditAfter: credit,
      };
    }

    if (tryCredit) {
      const newCredit = credit - jobPriceWon;
      tx.set(
        ref,
        {
          creditBalance: newCredit,
          creditLastUsedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true}
      );
      tx.set(ledger, {
        type: "credit_use" satisfies LedgerType,
        delta: -jobPriceWon,
        balanceAfter: newCredit,
        orderId,
        label: "공고 게시 (잔액 차감)",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return {
        paidWith: "credit",
        voucherAfter: vouchers,
        creditAfter: newCredit,
      };
    }

    return {
      paidWith: "insufficient",
      voucherAfter: vouchers,
      creditAfter: credit,
    };
  });
}
