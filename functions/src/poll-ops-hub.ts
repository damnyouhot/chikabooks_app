/**
 * 공감투표 운영 허브용 순수 함수 (firebase-admin 미사용 — index 초기화 순서와 무관)
 */

/** getContentOpsHub 의 poll 행과 동일(ISO 시각 문자열) */
export interface PollOpsHubRow {
  id: string;
  displayOrder: number;
  question: string;
  status: string;
  startsAt: string | null;
  endsAt: string | null;
}

/**
 * 앱 `EmpathyPollService.getActivePoll` 과 동일: endsAt > now 이고 투표 진행 중인 것 중 displayOrder 최소.
 * 다음 = 미종료 투표를 displayOrder·id 정렬 후, 현재의 바로 다음(없으면 현재 없을 때 대기열 선두).
 */
export function resolvePollOpsFromRows(
  pollRows: PollOpsHubRow[],
  nowMs: number,
): {
  current: PollOpsHubRow | null;
  next: PollOpsHubRow | null;
  remainingNotClosed: number;
} {
  const remainingNotClosed = pollRows.filter((p) => p.status !== "closed").length;

  const withMs = pollRows
    .map((r) => ({
      row: r,
      startsAtMs: r.startsAt ? Date.parse(r.startsAt) : NaN,
      endsAtMs: r.endsAt ? Date.parse(r.endsAt) : NaN,
    }))
    .filter((x) => !Number.isNaN(x.startsAtMs) && !Number.isNaN(x.endsAtMs));

  const votingOpen = (startsAtMs: number, endsAtMs: number) =>
    startsAtMs <= nowMs && endsAtMs > nowMs;

  const candidates = withMs.filter(
    (x) => x.endsAtMs > nowMs && votingOpen(x.startsAtMs, x.endsAtMs),
  );
  candidates.sort((a, b) => {
    if (a.row.displayOrder !== b.row.displayOrder) {
      return a.row.displayOrder - b.row.displayOrder;
    }
    if (a.startsAtMs !== b.startsAtMs) return a.startsAtMs - b.startsAtMs;
    return a.row.id.localeCompare(b.row.id);
  });
  const current = candidates.length > 0 ? candidates[0].row : null;

  const sortedNonClosed = [...pollRows]
    .filter((p) => p.status !== "closed")
    .sort((a, b) => {
      if (a.displayOrder !== b.displayOrder) return a.displayOrder - b.displayOrder;
      return a.id.localeCompare(b.id);
    });

  let next: PollOpsHubRow | null = null;
  if (current) {
    const idx = sortedNonClosed.findIndex((p) => p.id === current.id);
    if (idx >= 0 && idx + 1 < sortedNonClosed.length) {
      next = sortedNonClosed[idx + 1];
    }
  } else if (sortedNonClosed.length > 0) {
    next = sortedNonClosed[0];
  }

  return { current, next, remainingNotClosed };
}
