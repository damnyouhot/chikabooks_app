# Chikabooks / 하이진랩 — 모바일 앱 디자인 시스템 (코드 동기화)

> **목적**: Figma, Stitch(Google Labs) 등에 넘길 **모바일 앱(UI/IA/토큰) 단일 레퍼런스**.  
> **진실 원천**: 구현 코드. 수치·색은 반드시 아래에 인용한 Dart 파일과 대조할 것.  
> **작성 기준**: 저장소 스냅샷, 2026-04-04.  
> **범위**: **모바일 앱(Flutter, HomeShell 중심)**.  
> **웹**: 동일 백엔드·인증·데이터와 **연동되는 웹 클라이언트가 별도로 존재**한다. 웹 전용 레이아웃·색·폼 규격은 **이 파일에서 다루지 않으며**, 별도 문서로 관리한다.

---

## 1. 제품·기술 맥락

| 항목 | 내용 |
|------|------|
| 앱 표시명 (`MaterialApp.title`) | **하이진랩** |
| 프레임워크 | Flutter, **Material 3** (`useMaterial3: true`) |
| 테마 | 라이트 **단일** (`lib/core/theme/app_theme.dart` → `AppTheme.light`) |
| 시스템 글자 크기 | `lib/main.dart`에서 `TextScaler.noScaling` → **OS 접근성 글자 크기는 반영되지 않음**. 시안은 고정 스케일 기준으로 보면 됨. |
| 폰트 패밀리(테마) | **Noto Sans KR** (`fontFamily: 'NotoSansKR'`), 폴백: Apple SD Gothic Neo, Roboto |

### 1.1 웹과의 관계 (요약만)

- 웹 앱은 **존재**하며 Firebase 인증·Firestore 등 **모바일과 동일 계정·데이터에 연동**된다.
- 웹의 화면 구조, 배경색, 입력 스타일, CTA 규격 등은 **모바일 `AppTheme`과 일치하지 않을 수 있다**.  
  → **웹 디자인/스펙 문서는 이 파일과 분리**해 유지하는 것을 권장한다.

---

## 2. 정보 구조(IA) — 메인 셸

### 2.1 진입

- 모바일에서 루트는 `GoRoute('/')` → **`AuthGate`** (`lib/pages/auth/auth_gate.dart`). 로그인·온보딩 상태에 따라 **`HomeShell`** 또는 인증 화면으로 분기된다.

### 2.2 `HomeShell` — 4탭 하단 내비게이션

구현: `lib/pages/home/home_shell.dart`.

| 인덱스 | 바 라벨 | 아이콘 (미선택 / 선택) | 본문 위젯 | 한 줄 설명 |
|--------|---------|-------------------------|-----------|------------|
| 0 | 나 | `person_outline` / `person` | `CaringPage` | 캐릭터(Rive)·상태·카드·하단 3액션 |
| 1 | 같이 | `people_outline` / `people` | `BondPage` | 공감투표 헤더 + `BondPollSection` |
| 2 | 성장하기 | `menu_book_outlined` / `menu_book` | `GrowthPage` | 상단 세그먼트 4개 + `TabBarView` |
| 3 | 커리어 | `work_outline` / `work` | `JobPage` | 커리어/채용 관련 탭·지도 등 |

내부 라벨(피드백 FAB에 넘기는 문자열 등): `나(캐릭터)`, `같이(파트너)`, `성장하기`, `커리어`.

**같이 탭 진입 제약**: 프로필 온보딩이 완료되지 않았으면 `OnboardingProfileScreen`으로 먼저 보낼 수 있음.

**온보딩**: `AppOnboardingController` + `AppOnboardingOverlay`가 `HomeShell`의 `Stack` 최상단에 덮임. 특정 스텝에서는 탭 전환만 허용하는 로직이 있다.

### 2.3 전역 오버레이 — 피드백 FAB

- `FeedbackFab` (`lib/features/feedback/widgets/feedback_fab.dart`): **온보딩이 아닐 때만** 표시.
- 위치: 화면 **우하단**, `SafeArea bottom` + **`kBottomNavigationBarHeight` + 16** 위.
- 크기 **52×52** 원형, 채움색 **`#2E7D32`** (앱 토큰 `AppColors`와 **별도 하드코딩** — 디자인 시스템 예외).
- 그림자: `blur 10`, `offset (0,4)`, 색은 같은 그린 40% opacity.
- 아이콘: `Icons.feedback_outlined`, 흰색, 24.
- 등장: 400ms 지연 후 `easeOutBack` 스케일 애니메이션, 지속 **180ms**.
- 탭 시 `FeedbackListPage`로 푸시(목록 → 작성 → 상세 흐름은 해당 피처 코드 참고).

### 2.4 모바일 딥링크·서브 화면(참고)

`lib/core/router/app_router.dart`에 `/quiz`, `/books`, `/policy`, `/jobs`, `/feedback`, 이력서·관리자 등이 정의되어 있다. 시안을 나눌 때 **「탭 안의 탭」**과 **「풀스크린 푸시」**를 구분하면 혼선이 줄어든다.

---

## 3. 색상 시스템 (`AppColors`)

단일 소스: `lib/core/theme/app_colors.dart`.

코멘트에 남아 있는 "Green / Orange" 표기는 **_palette 리브랜딩 이전 문구**가 남은 경우가 있다. 실제 Hex는 아래 표를 따른다.

### 3.1 프리미티브 (4개)

| 토큰 | HEX | 비고 |
|------|-----|------|
| `white` | `#FFFFFF` | |
| `black` | `#000000` | |
| `blue` | `#0A0A3A` | Steel Marine — 브랜드 **네이비** |
| `lime` | `#AD1F23` | 이름은 `lime`이나 색은 **Lobster Red (레드)** |

### 3.2 앱 셸·텍스트·서피스

| 토큰 | HEX | 용도 |
|------|-----|------|
| `appBg` | `#FDFAF5` | **Scaffold 기본 배경** (크림 화이트) |
| `navBg` | `#FDFAF5` | 하단 `BottomNavigationBar` 배경 |
| `textPrimary` | `#000000` | 제목·본문 기본 |
| `textSecondary` | `#555555` | 부제·보조 |
| `textDisabled` | `#999999` | 비활성·약한 아이콘 |
| `surfaceMuted` | `#F0EDE6` | 세그먼트 트랙, `AppMutedCard` 배경 등 |
| `onSurfaceMuted` | (= `textSecondary`) | |
| `disabledBg` | `#E2DDD6` | 비활성 버튼 배경 |
| `disabledText` | `#B5B0A8` | |
| `divider` | `#E2DDD6` | 구분선 |
| `creamWhite` | `#FDFAF5` | 진한 면 위 밝은 텍스트용 |

### 3.3 카드·강조·CTA

| 토큰 | HEX | 용도 |
|------|-----|------|
| `cardPrimary` | `#0A0A3A` | **진한 카드** (네이비 배경) |
| `onCardPrimary` | `#FFFFFF` | 네이비 카드 위 텍스트·아이콘 |
| `cardEmphasis` | `#AD1F23` | 강조 카드/배지, **하단 탭 선택 색** |
| `onCardEmphasis` | `#FDFAF5` | 레드 면 위 텍스트 |
| `accent` | `#0A0A3A` | 기본 강조 CTA 채움 (네이비) |
| `onAccent` | `#FFFFFF` | 네이비 CTA 위 전경 |

### 3.4 세그먼트·내비게이션

| 토큰 | 매핑 | 설명 |
|------|------|------|
| `segmentSelected` | `blue` | 세그먼트 선택 칩 배경 |
| `onSegmentSelected` | `white` | 선택 라벨 |
| `segmentUnselected` | 투명 | 인디케이터 아래 면 |
| `onSegmentUnselected` | `textSecondary` | 미선택 라벨 |
| `navSelected` | `blue` *(테마 필드명상)* | `BottomNavigationBarTheme`에서는 **`selectedItemColor: cardEmphasis`** 로 **실제 선택색은 레드** |
| `navUnselected` | `textSecondary` | 비선택 탭 |

**중요**: `app_theme.dart`의 `bottomNavigationBarTheme.selectedItemColor`는 **`AppColors.cardEmphasis`(레드)**. Figma 변수 만들 때 탭 선택색을 네이비로 두면 **구현과 불일치**한다.

### 3.5 퀴즈·투표 공통 (`poll*` / `quiz*`)

| 용도 | 배경 | 전경/테두리 |
|------|------|-------------|
| 배지(이번 주, Q1 등) | `pollBadgeBg` (= `cardEmphasis`) | `pollBadgeText` (= `onCardEmphasis`) |
| 선택지 기본 | `pollOptionBg` (= `disabledBg`) | `pollOptionText` (= `textPrimary`) |
| 선택지 선택됨 | `pollOptionSelectedBg` (= `cardEmphasis`) | `pollOptionSelectedText` (= `onCardEmphasis`) |
| 정답 피드백 | `quizCorrectBg` `#E8EAF6` | `quizCorrect` / `quizCorrectText` = `blue` |
| 오답 피드백 | `quizWrongBg` `#FFECEC` | `quizWrong` = `lime`(레드) |

### 3.6 배지·상태·기타

| 토큰 | HEX | 용도 |
|------|-----|------|
| `emphasisBadgeBg` | `cardEmphasis` | 강조 배지 배경 |
| `emphasisBadgeText` | `onCardEmphasis` | 강조 배지 글자 |
| `prepBadgeGreen` | `#14532D` | `PrepInProgressBadge` — 「준비중」 느낌의 포레스트 그린 |
| `naverLoginGreen` | `#54B73B` | 네이버 로그인 에셋 톤 |
| `success` | `#00E676` | 성공 스낵바 등 |
| `warning` | `#FF9100` | 경고 |
| `error` | `#FF1744` | Material 의미의 오류 |
| `destructive` | `lime`(레드) | 삭제 등 — **Material `error`와 구분**, 브랜드 레드 사용 |
| `jobPreviewOverflowChipBg` | `surfaceMuted` | 공고 미리보기 `+N` 칩 |
| `jobPreviewOverflowChipText` | `textSecondary` | |

코드에 **웹 전용으로 쓰이는 색 토큰**이 더 있을 수 있으나, 값·용도는 **웹 스펙 문서**에서 정의·동기화한다.

### 3.7 원칙(코드 주석 요약)와 예외

- 지향: **그림자 없음, 테두리 없음**, 탭 간 색 철학 통일.
- 예외: **피드백 FAB**는 그림자·전용 그린. 일부 **레거시/퍼블리셔** 화면은 그림자·라운드가 다를 수 있음 — 화면별 위젯 확인.

---

## 4. 타이포그래피

### 4.1 테마 `TextTheme`

`AppTheme.light` (`lib/core/theme/app_theme.dart`):

- `bodyLarge` / `bodyMedium` / `titleLarge` / `titleMedium` / `titleSmall` → 색 **`textPrimary`**
- `bodySmall` → **`textSecondary`**

### 4.2 화면별 패턴 (코드에서 반복되는 규모)

| 맥락 | 예시 | 스타일 |
|------|------|--------|
| 탭 대제목 | 나 / 공감투표 / 성장하기 헤더 | 20pt, **w800**, `textPrimary` |
| 탭 부제(한 줄) | 서브카피 | 12pt, `textSecondary` |
| 하단 탭 라벨 | `BottomNavigationBarTheme` | 선택 12 **w700**, 비선택 12 w400 |
| 세그먼트 라벨 | `AppSegmentedControl` 내부 `TabBar` | 선택 12 **w700** 흰색, 비선택 12 w400 `textSecondary` |

### 4.3 영문 헤드라인 (`GoogleFonts.poppins`)

나 탭 상단 카드(`Jobs`, `Policy Updates`, `Weekly Book` 등)는 **Poppins** 굵은 헤드라인 + 흰색(`onCardPrimary`). 한글 본문과 **패밀리가 섞이는 것이 의도된 패턴**이다.

### 4.4 말풍선 (`SpeechOverlay`)

- 일반: 기준 **16sp × 0.85** × `contentScale`, **w400**, `textPrimary`, **letterSpacing 0.2 × 0.85 × scale**, **line height 1.5**
- 온보딩: 기준 **17sp** × 0.85 … (동일 규칙)
- 온보딩에서 `onboardingBoldWord`가 있으면 해당 구간만 **w700**
- 최대 너비: 화면의 **75%**
- 세로 패딩: `8 × 0.85 × scale`, 가로 패딩 `16 × 0.85 × scale`
- 최소 높이: **2줄 분** (`minHeight: 2 * lineHeight`), 텍스트는 **하단 정렬**

---

## 5. 간격·라운드 (`AppTokens`)

파일: `lib/core/theme/app_tokens.dart`.

### 5.1 `AppRadius`

| 토큰 | dp | 비고 |
|------|-----|------|
| `xs` | 6 | 소형 뱃지 등 |
| `sm` | 8 | 세그먼트 인디케이터 기본 |
| `md` | 10 | 세그먼트 컨테이너 기본 |
| `lg` | 14 | `AppMutedCard` 기본 radius |
| `xl` | 16 | 큰 카드 |
| `full` | 999 | pill |

### 5.2 `AppSpacing`

| 토큰 | dp |
|------|-----|
| `xs` | 4 |
| `sm` | 8 |
| `md` | 12 |
| `lg` | 16 |
| `xl` | 20 |
| `xxl` | 24 |

### 5.3 `AppSegmentedControl` 기본 여백

- 컨테이너 `margin`: 좌우 **20**, 상하 **8** (`AppSpacing.xl` / `sm`)
- `TabBar` `indicatorPadding`: **3** (전 방향)

### 5.4 테마와 토큰의 의도적 차이

| 요소 | 구현값 | 비고 |
|------|--------|------|
| `ElevatedButton` / `FilledButton` | `BorderRadius.circular(12)` | `AppRadius.md`(10)와 **2dp 차이** |
| `CardTheme.shape` | **16** | `AppRadius.xl`과 일치 |
| `CaringPage` 카드 (`_TapCard` 등) | **12** | 전역 카드 16과 **불일치** |

시안을 찍을 때 버튼은 **12**, 뮤티드 카드는 **14**, 테마 `Card`는 **16**처럼 **역할별로 다를 수 있음**을 기록해 두는 것이 좋다.

---

## 6. 공통 컴포넌트 (모바일)

### 6.1 `AppMutedCard`

`lib/core/widgets/app_muted_card.dart`

- 배경: `surfaceMuted`, **그림자/보더 없음**
- 기본 내부 패딩: **16** (`AppSpacing.lg`)
- 기본 radius: **14** (`AppRadius.lg`)
- 탭 시: `Material` + `InkWell`, ripple은 `borderRadius`에 맞춤

**사용 예(코멘트 기준)**: 퀴즈 카드·통계 카드·HIRA 카드·내 서재 타일·일부 Caring 관련 카드 등.

### 6.2 `AppSegmentedControl`

`lib/core/widgets/app_segmented_control.dart`

- 트랙: `surfaceMuted`, radius 기본 **10**
- 인디케이터: `segmentSelected`(네이비), radius 기본 **8**, **indicatorPadding 3**
- WIP 탭: 라벨 옆 **`PrepInProgressBadge`**

### 6.3 `AppBadge` / `AppStatusBadge`

`lib/core/widgets/app_badge.dart`

- 기본 배경 `surfaceMuted`, 텍스트 `textSecondary`, **그림자 없음**
- 원형 번호 뱃지: 기본 크기 **28**, 글자 11 **w700**
- Pill 뱃지: 가로 패딩 8, 세로 3 (`xs - 1`), radius `AppRadius.xs`(6)

### 6.4 `PrepInProgressBadge`

- 배경색: **`prepBadgeGreen`** (`#14532D`)

### 6.5 테마 버튼·카드

- **Elevated / Filled**: 배경 `accent`, 전경 `onAccent`, elevation **0**, radius **12**
- **AppBar**: 배경 **투명**, elevation **0**, `scrolledUnderElevation` **0**, 전경 `textPrimary`

---

## 7. 하단 내비게이션 바 (정리)

`AppTheme.bottomNavigationBarTheme`:

- `backgroundColor`: `navBg`
- `selectedItemColor`: **`cardEmphasis`(레드)**
- `unselectedItemColor`: `navUnselected`
- `elevation`: **0**
- `type`: **fixed**
- 아이콘 테마: 선택/비선택 모두 크기 **24**

---

## 8. 화면별 상세 — 「나」탭 (`CaringPage`)

파일: `lib/pages/caring_page.dart`.

### 8.1 구조(위→아래)

1. **상단 바**(온보딩 일부 구간에서는 제목 숨김): 타이틀 **「나」** (20 w800), `info_outline`(18, `textSecondary`) / `settings_outlined`(20, `textDisabled`), 부제 **「오늘 하루도 잘 버텼어요.»** (12, `textSecondary`).
2. **정보 카드 4개** (온보딩 시 일부 숨김/고정 문구): Jobs(준비중), Policy 롤링, Weekly Book, Quiz 롤링.
   - 카드: `Material` `cardPrimary`, radius **12**, **InkWell**, 내부 패딩 대략 12h×10v, 좌우 카드 바깥 패딩 14h, 4v.
   - 타이틀 영역: Poppins 14 **w800** 흰색, 셰브론 아이콘 20.
3. **게이지 행** (온보딩 아닐 때): 가로 균등 배치, 각 **52×52** 원형 커스텀 게이지.
   - 스트로크 두께: 코드 상 `3.5 * 2.5`
   - 트랙: `0x20000000`
   - 채움 색: 배고픔 **`AppColors.lime`**, 기분 **`#FFD54F`**, 에너지 **`#81C784`**, 유대 **`#F48FB1`** (전역 시맨틱 외 **로컬 보조색**).
   - 중앙: 이모지 14 높이 1.0 + 값 **11 w700** `textPrimary`.
4. **캐릭터 영역** (`Expanded` + `ClipRect` + 상단 패딩 18): Rive 강아지, 화면 높이 대비 스케일 (**기준 비율 약 0.38** × 기기 보정), 온보딩 시 별도 배율.
   - 탭: 캐릭터 영역에서 **쓰다듬기** 트리거.
   - 배고픔 낮음: 컬러 매트릭스 필터.
   - 수면: `Zzz` + 어둡게/투명도 **AnimatedBuilder** (컨트롤러 500ms, `Curves.easeInOut`).
5. **말풍선**: 캐릭터 위 `SpeechOverlay` — 리액션 우선, 온보딩 시 대사·볼드 단어.
   - 페이드 인 **500ms** `easeOut`. dismiss 시 **즉시 투명 처리**(바람·블러 등 없음).
6. **하단 고정 영역** (크림 배경 `appBg`, 패딩 20,16,20,16): **3개** 액션 버튼 가로 균등.

### 8.2 하단 액션 (`_ActionBtn`)

- 라벨: **밥주기** / **쓰다듬기** / **재우기·깨우기** (수면 상태에 따라 아이콘·텍스트 전환).
- 크기: `btnSize = screenWidth * 0.13`, **clamp(44, 64)**; 아이콘 `btnSize * 0.43` clamp(20, 28).
- 형태: **원**, 배경 활성 **`accent`**, 아이콘 **`onAccent`**; 비활성 `disabledBg` / `disabledText` / 아이콘색 동일 계열.
- 라벨: 11 **w600**, 색 비활성 시 `textDisabled` 아니면 `textPrimary`.
- 탭 스케일: 100ms, 1.0 ↔ 0.88 `easeInOut`.
- 비활성 페이드: 220ms `easeInOut` (온보딩에서는 0).

### 8.3 멘트 타이밍(일반 모드, 코드 상수)

- 이벤트 기반 기본 멘트 표시: **4초**
- 리액션 멘트: **2초**
- 랜덤 기본 멘트 간격: **5초**

### 8.4 레이아웃 애니메이션

- 카드·버튼 등장: **1200ms** `AnimationController`, 카드는 200ms 간격 스태거, 버튼은 500ms 이후 시작.

### 8.5 `docs/DESIGN_GUIDELINES.md`와의 관계

그 문서는 **과거 다른 UX 방향**(4버튼·다른 팔레트·바람 디스미스 등)을 묘사할 수 있다. **현 구현은 본 절을 따른다.**

---

## 9. 화면별 상세 — 「같이」탭 (`BondPage`)

- 배경: `appBg`, `SafeArea` + `CustomScrollView`.
- 헤더: **「공감투표»** 20 w800, `info` 18 `textDisabled`, `settings` 20 `textDisabled`, 부제 **「오늘의 주제에 공감을 표현해보세요.»** 12 `textSecondary`.
- 본문: **`BondPollSection`** — 투표 UI는 **`AppColors.poll*`** 토큰과 연동(3.5절).

---

## 10. 화면별 상세 — 「성장하기」(`GrowthPage`)

- 배경: `appBg`.
- 헤더: 성장 탭 타이틀 + 동일한 info/settings 패턴 (패딩 `AppSpacing.xl`).
- **`AppSegmentedControl`** 라벨: **`오늘 퀴즈` / `보험정보` / `치과책방` / `내 서재`**
- `TabBarView`:
  1. `QuizTodayPage` — 정답/오답 색은 `quizCorrect*` / `quizWrong*`
  2. `HiraUpdatePage` — 보험정보; 내부 소탭 전환은 notifier로 제어 가능
  3. `EbookListPage`
  4. `_MyLibraryView` — 내 서재

외부에서 `subTabNotifier`로 **특정 소탭으로 점프**할 수 있음(나 탭 카드에서 성장 탭으로 보낼 때 등).

---

## 11. 화면별 상세 — 「커리어」(`JobPage`)

- 상단 헤더 + **`DefaultTabController`** 기반 하위 탭(목록/지도/커리어 카드 등) 구조.
- `CareerSkillAutoHintScope`: 토큰이 올라오면 스킬 탭으로 애니메이션 + 바텀시트 오픈 등 **온보딩/힌트 연계**.

(세부 타이포·지도 핀 색은 화면별 위젯을 추가 조사할 때 보강.)

---

## 12. 기타 구현 참고

| 항목 | 파일/위치 |
|------|-----------|
| 색 단일 소스 | `lib/core/theme/app_colors.dart` |
| 간격·라운드 | `lib/core/theme/app_tokens.dart` |
| ThemeData | `lib/core/theme/app_theme.dart` |
| 라우터 | `lib/core/router/app_router.dart` |
| 앱 엔트리 | `lib/main.dart` |

---

## 13. 레거시 문서 정리

| 문서 | 용도 |
|------|------|
| **`docs/DESIGN_GUIDELINES.md`** | 과거 돌보기 UX 기획 성격. 현 `CaringPage`와 전부 일치하지 않을 수 있음. |
| **본 문서 (`APP_DESIGN_SYSTEM.md`)** | **모바일** IA·토큰·주요 화면 패턴. |
| **웹 전용** | 별도 MD로 관리 (URL·폼·배경 등). 코드의 `AppPublisher`, `webPublisherPageBg` 등은 웹 문서에서 설명하는 편이 맞다. |

---

## 14. 외부 도구용 체크리스트

1. 색: **`lime` = 레드** 재확인. 탭 선택 = **레드(`cardEmphasis`)**.
2. 앱 배경 = **`#FDFAF5`** 한 종류로 통일하는 편이 안전(탭 바까지 동일).
3. 버튼 라운드 **12** vs 카드 **12/14/16** 혼재 허용.
4. 나 탭 게이지 보조색은 **디자인 토큰 문서화 전용** — 위 표의 HEX를 Figma에 옮겨 적을 것.
5. 피드백 FAB = **전역 토큰 무시**, 그린 **`#2E7D32`** 고정.
6. 웹 시안은 **이 문서만으로 불충분** — 웹 전용 스펙 파일을 병행할 것.
