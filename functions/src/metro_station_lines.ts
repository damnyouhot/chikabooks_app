/**
 * 서울 수도권 지하철 역명(한글·역 접미) → 노선 표기 (표시용)
 * Places API는 호선을 주지 않아 주요 역만 매핑한다.
 */
export const METRO_STATION_LINES: Record<string, string[]> = {
  "마포역": ["5호선", "경의·중앙선", "공항철도", "서해선"],
  "공덕역": ["5호선", "6호선", "경의·중앙선", "공항철도"],
  "대흥역": ["6호선"],
  "홍대입구역": ["2호선", "경의·중앙선", "공항철도"],
  "합정역": ["2호선", "6호선"],
  "상수역": ["6호선"],
  "광흥창역": ["6호선"],
  "신촌역": ["2호선"],
  "이대역": ["2호선"],
  "아현역": ["2호선"],
  "충정로역": ["2호선", "5호선"],
  "서대문역": ["5호선"],
  "애오개역": ["5호선"],
  "여의나루역": ["5호선"],
  "여의도역": ["5호선", "9호선"],
  "당산역": ["2호선", "9호선"],
  "영등포구청역": ["2호선", "5호선"],
  "영등포역": ["1호선"],
  "신길역": ["1호선", "5호선"],
  "용산역": ["1호선", "경의·중앙선"],
  "이촌역": ["4호선", "경의·중앙선"],
  "효창공원앞역": ["6호선", "경의·중앙선"],
  "삼각지역": ["4호선", "6호선"],
  "녹사평역": ["6호선"],
  "이태원역": ["6호선"],
  "한강진역": ["6호선"],
  "버티고개역": ["6호선"],
  "약수역": ["6호선"],
  "금호역": ["3호선"],
  "옥수역": ["3호선"],
  "압구정역": ["3호선"],
  "신사역": ["3호선"],
  "강남역": ["2호선", "신분당선"],
  "역삼역": ["2호선"],
  "선릉역": ["2호선", "수인·분당선"],
  "삼성역": ["2호선"],
  "종합운동장역": ["2호선", "9호선"],
  "잠실나루역": ["2호선"],
  "잠실역": ["2호선", "8호선"],
  "문래역": ["2호선"],
};

export function linesForStationDisplayName(name: string): string[] {
  const t = name.trim();
  if (!t) return [];
  const candidates = [
    t,
    t.endsWith("역") ? t : `${t}역`,
    t.replace(/\s*Station$/i, "역"),
    t.replace(/\s*station$/i, "역"),
  ];
  const seen = new Set<string>();
  const out: string[] = [];
  for (const c of candidates) {
    const lines = METRO_STATION_LINES[c];
    if (lines) {
      for (const line of lines) {
        if (!seen.has(line)) {
          seen.add(line);
          out.push(line);
        }
      }
    }
  }
  return out;
}

export function haversineMeters(
  lat1: number, lon1: number, lat2: number, lon2: number
): number {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}
