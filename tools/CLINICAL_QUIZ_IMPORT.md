# 임상문제 시트 → Firestore (`quiz_pool`) — 실제 `공감투표.xlsx` 기준

Desktop `공감투표.xlsx`의 **`임상문제`** 시트를 Node(xlsx)로 읽어 확인한 구조입니다.  
(시트 목록: `공감투표` | `국시문제` | `임상문제`)

---

## 실측 헤더 (1행)

| 열 인덱스 | 헤더 셀 값 |
|-----------|------------|
| 0 | 문제 |
| 1 | 보기 |
| 2 | 정답 |
| 3 | 해설 |
| 4 | 출처 |
| 5~7 | (샘플 구간 비어 있음) |

---

## 실측 데이터 형태 (2행 이후)

동일 시트에 **두 가지 보기 레이아웃이 혼재**합니다.

**A. 한 셀형**  
- **한 문항 = 한 행**. **보기(열 1)** 한 셀에 `1) … 2) … 3) …` 또는 `1. … 2. … 3. …` 처럼 **세 보기가 연속** (예: `1) 2,600mg 2) 3,200mg 3) 4,000mg`).

**B. 여러 행형**  
- 첫 행: **문제·정답·해설·출처**는 그대로 두고, **보기 열(1열)** 에는 `1. 첫번째보기` 만 적힘.  
- 다음 몇 행: **문제 열(0열)은 비우고**, 보기 열에만 `2. …`, (빈 행) `3. …` 가 이어짐.  
- `import_clinical_quiz_xlsx.js` 가 A/B 를 자동 구분합니다.

**정답(열 2)**: `1`, `2`, `3` — **1-based 보기 번호** → Firestore `correctIndex = 정답 - 1`.

**출처(열 4)**: 예) `치과책방 치과 처방약 바로 알기, 11p` 또는 `치과책방_저연차 … (p.7)` — `sourceName` 전체 + 가능하면 책명/페이지 분리.

---

## Firestore 필드 매핑 (확정)

| 엑셀 | Firestore | 변환 규칙 |
|------|-----------|-----------|
| 문제 (0) | `question` | trim |
| 보기 (1) | `options` | `1)…2)…3)…` 문자열을 파싱해 문자열 배열 3개 (`import_clinical_quiz_xlsx.js`의 `parseOptionsThree`) |
| 정답 (2) | `correctIndex` | **앱/Firestore는 0-based** → `Number(정답) - 1` (정답이 1~3일 때만 허용) |
| 해설 (3) | `explanation` | trim |
| 출처 (4) | `sourceName` | 전체 문자열 그대로 |
| 출처 (4) | `sourceBook` | 마지막 `,` 뒤가 `…p` 패턴이면 앞부분을 책명으로 (없으면 전체를 책명 또는 `sourceName`만 사용) |
| 출처 (4) | `sourcePage` | `, 11p` → `11` 등으로 추출 (없으면 `""`) |
| (없음) | `category` | 기본값 `임상` (또는 출처에서 유도 가능 시 스크립트 확장) |
| (없음) | `order` | `CLINICAL_ORDER_BASE`(기본 300000) + 시트 내 데이터 행 순번(1부터) |
| 스크립트 | `questionType` | `"clinical"` |
| 스크립트 | `difficulty` | `"basic"` |
| `--pack-id` | `packId` | 필수 |
| `--pack-version` | `packVersion` | 기본 `1` |
| 스크립트 | `sourceFileName` | `""` |
| 스크립트 | `isActive` | `true` (레거시 정리는 별도) |

---

## correctIndex

- 코드: `lib/models/quiz_pool_item.dart` — `correctIndex // 0-based`
- 엑셀 정답 `1`~`3` → Firestore `0`~`2`

---

## 국시 시트와의 차이

| 항목 | 국시문제 (`import_national_quiz_xlsx.js`) | 임상문제 (실측) |
|------|------------------------------------------|-----------------|
| 보기 | 여러 행에 보기 열만 누적 (연속 행) | **한 셀 3보기** 또는 **1.만 첫 행 + 2. 3. 후속 행** |
| 번호/과목 열 | 있음 | **없음** (`order`/`category`는 스크립트가 부여) |

따라서 임상 전용 파서가 필요하며, 국시 스크립트를 그대로 쓰면 안 됩니다.

---

## 운영 순서 (요약)

1. **dry-run + 샘플 10문항**  
   `node ../tools/import_clinical_quiz_xlsx.js --dry-run "경로/공감투표.xlsx" --pack-id=YOUR_PACK --sample-n=10`  
   → `question`, `options`, `correctIndex`, `explanation` JSON 확인
2. **본 업로드**  
   동일 명령에서 `--dry-run` 제거
3. **quiz_pool 건수**  
   Firestore 콘솔 또는 `node tools/quiz_cutover_verify.cjs --pack-id=YOUR_PACK` (활성 임상 중 해당 pack 건수)
4. **후보 풀 미리보기**  
   `node tools/quiz_cutover_preview.cjs`
5. **config 컷오버**  
   `node tools/quiz_content_apply_clinical_pack.cjs --pack-id=YOUR_PACK --yes` (`--no-legacy` 선택)
6. **오늘 스케줄**  
   유지 vs `manualScheduleQuiz` + `forceReplace` 결정 후  
   `node tools/quiz_cutover_verify.cjs --pack-id=YOUR_PACK` (날짜 기본 KST 오늘) 로 `items`의 `questionType` / `packId` / `packVersion` 확인
7. **앱**에서 국시1+임상1·정답/해설 확인
8. **레거시**  
   `quiz_deactivate_clinical_except_pack.cjs --except-pack-id=YOUR_PACK --dry-run` → `--yes`


랜덤 선정·국시 pack 통일·당일 스케줄 유지 여부는 프로젝트 `functions/src/index.ts` 및 기존 논의와 동일합니다.
