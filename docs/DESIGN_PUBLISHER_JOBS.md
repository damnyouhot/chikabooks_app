# 공고 파트 · 웹 게시자 디자인 지침

> **`DESIGN_GUIDELINES.md`(돌보기·감성 UX)와 구분** — 치과 **공고자(게시자)** 흐름, 웹 로그인·인증·공고 작성 UI에 적용되는 톤과 규격을 정리합니다.

---

## 문서 범위

| 포함 | 제외 |
|------|------|
| 웹 `/login` 공고자(치과) 영역 | 지원자(일반) 앱 메인 탭 전체 톤 |
| `PublisherOnboarding*` · `PubScaffold` 등 게시자 화면 | `DESIGN_GUIDELINES.md`의 돌보기 말풍선·멘트 규칙 |
| 공고 작성·게시 관련 화면에서 재사용할 토큰·패턴 | 피그마 파일 (코드·토큰이 단일 소스에 가깝게 유지됨) |

---

## 핵심 톤 (에디토리얼)

- **파트 구분 (`JobPostForm` 웹 공고자)**: 섹션 사이에는 **가로 구분선(`Divider`)을 두지 않음**. 대신 **`AppPublisher.formSectionSpacing`(40px)** 등 **세로 여백만**으로 리듬을 잡는다. 첫 블록(공고 사진)은 드래그 중이 아닐 때 **하단 라인 없음**(밑줄 입력 톤 유지).
- **섹션 타이틀·내부 여백**: 제목 글자 **`formSectionTitleSize`(21px)**. 제목→필드 **`formSectionTitleGap`(22px)**. 필드 블록 끝→다음 파트 전 **`formSectionBottomGap`(32px)**.
- **칩·나란히 필드**: `Wrap` 칩은 **`formChipSpacing` / `formChipRunSpacing`(12 / 10px)**. 체어 수·스탭 수 등 **2열 필드** 사이는 **`formFieldRowGap`(20px)**. 이미지 행의 사진 추가·AI 버튼 사이는 **`formButtonRowGap`(14px)**.
- **드롭다운**: Material 기본 메뉴·호버가 보라/라벤더 톤으로 나가지 않도록, **`Theme` + `dropdownColor: white` + `accent` 계열 `ColorScheme.surfaceContainer*`** 로 `JobPostForm._pubDropdownMenuTheme` 에서 통일. **외곽 `borderRadius`는 `buttonRadius`**.
- **라운드**: 칩·썸네일·작은 타일은 **`AppPublisher.softRadius`(3px)**. 주요 **Outlined/Elevated** CTA는 **`AppPublisher.buttonRadius`(8px)**.
- **입력**: 공고자 로그인·`JobPostForm(publisherWebStyle: true)` 동일 — **밑줄(`UnderlineInputBorder`) 필드** — 포커스 시 `AppColors.accent` 2px, 에러 시 **`AppColors.cardEmphasis`** (`web_login_page` 와 동일).
- **강조 색**: **네이비(`accent` = `blue`)**와 **레드(`cardEmphasis` = `lime`)** 위주. 구형 주황 `warning`에 의존한 CTA는 피하고, 의미 있는 강조는 토큰으로 통일.
- **배경**: 웹 공고자 전용 페이지 배경은 크림 앱 배경과 구분 — **`AppColors.webPublisherPageBg` (`#F0F0F0`)**. `PubScaffold`의 `webPublisherShell: true`일 때 셸은 **흰색 + AppBar 하단 1px 라인**.

### 라인 우선 · 박스 라운드 (웹 공고 자료 입력 등)

- **네 면 테두리 박스(`Border.all`)는 최소화**한다. 구역 구분은 **`Divider`**, **하단(또는 상단) 한 줄 `BorderSide`**, **왼쪽 강조 보더(배너)** 등 **라인**을 우선한다. 불가피하게 카드형 박스가 필요할 때만 사각 테두리를 쓴다.
- **박스/칩/썸네일/패널을 쓸 때 모서리는 임의 숫자 금지** — 아래 토큰만 사용한다:
  - 작은 요소·썸네일·점선 드롭존 내부: **`AppPublisher.softRadius` (3px)**
  - 주요 CTA·큰 패널(불가피 시): **`AppPublisher.buttonRadius` (8px)** 또는 패널용 **`AppPublisher.inputPanelRadius` (10px)** — 정의는 **`lib/core/theme/app_tokens.dart`**
- **`/post-job/input` (`job_input_page`)** 는 위 원칙을 따른다: 임시저장 초안은 **`OutlinedButton` 풍 버튼**(구분은 `divider` 테두리), 본문 블록은 **구분선·탭 인디케이터 위주**, 텍스트 입력은 **`JobPostForm`과 동일한 밑줄 필드(`UnderlineInputBorder`)** 톤을 사용한다.

### `/post-job/input` 좌우 2-column 레이아웃

- **구조**: 뷰포트 높이 기준 **세로 중앙 정렬**(`LayoutBuilder` + `Center` + `SingleChildScrollView` + `minHeight`) — `ConstrainedBox(maxWidth: 1100)` 안에 `Row(flex 4:5)` — 좌측 **「임시저장/ 사용 공고」**, 우측 **「새로 만들기」**.
- **좌측**: 임시저장 목록(`watchMyDrafts`) + 게시된 공고 목록(`jobs` 컬렉션) — 초안은 **버튼형**, 게시 목록은 **행 단위 하단 라인**(`BorderSide`) 구분.
- **우측 탭(4종)**: 「홍보이미지 업로드」 · 「캡처 이미지 업로드」 · 「텍스트 붙여넣기」 · 「기존 공고 복사」 — 선택 탭 아래 **`accent` 굵은 라인(3px)**, 비선택은 **얇은 `divider` 라인(1px)** 으로 구분.
- **CTA 분기**: 홍보이미지(`sourceType: promotional`) → **"다음 단계"** (AI 스킵, `editorStep: step3`). 캡처/텍스트 → **"AI 초안 생성하기"**. 복사 → 목록에서 바로 이동.
- **CTA 아래**: **「처음부터 직접 작성하기」** `TextButton` — `sourceType: manual`, 빈 폼 `step3`로 이동.

### 홍보이미지 (`promotionalImageUrls`)

- **정의**: AI 추출 없이 공고에 **직접 노출**되는 이미지(치과 소개·시설·분위기 등).
- **모델**: `JobDraft.promotionalImageUrls`, `JobPostData.promotionalImageUrls` — `List<String>`.
- **프리뷰 배치**: `JobPostPreview`에서 **담당업무 ↔ 병원정보 사이**에 `_sectionPromotionalImages()`로 삽입. 각 이미지는 **모바일 폭 전체(`width: double.infinity`, `fitWidth`)**를 차지하고, 여러 장이면 **세로로 쌓여** 배치된다.
- **업로드 흐름**: `job_input_page` → `JobImageUploader.uploadImages` → `promotionalImageUrls`로 저장, `aiParseStatus: done`, `currentStep: ai_generated` 세팅 → 에디터 `step3`로 이동.

### 미리보기 2열 그리드 (짧은 설명)

- **지금 구조**: `JobPostPreview`의 정보 행은 **짝을 이루면 가로로 두 칸**(한 줄에 두 항목). **마지막에 항목이 하나만 남으면** 그 줄은 **한 칸만 쓰고 나머지는 비움**(자동으로 아래 줄까지 길게 늘리지는 않음).
- **“긴 글만 한 줄 전체”**를 쓰고 싶다면, 일반적인 방법은 **그 행을 2열 묶음에 넣지 않고** `Row` 밖에서 **폭 전체(`width: double.infinity` 또는 `Column` 안의 단일 `JobDetailInfoRow`)** 로 두는 식으로 **레이아웃만 따로** 잡는 것이다. (지금 위젯은 모든 행을 같은 2열 규칙으로 묶고 있음.)

---

## 컬러 (코드 단일 소스)

실제 값은 **`lib/core/theme/app_colors.dart`** 를 따릅니다. 공고 파트에서 자주 쓰는 매핑:

| 용도 | 토큰 | 비고 |
|------|------|------|
| 웹 공고자 페이지 배경 | `webPublisherPageBg` | 뉴트럴 라이트 그레이 |
| 포인트·진행률(진행 중) | `accent` | Steel Marine 네이비 |
| 완료·강조 CTA·단계 완료 표시 | `cardEmphasis` | Lobster Red |
| 본문·제목 | `textPrimary` / `textSecondary` | |
| 구분선 | `divider` | |
| 에러·반려·정지 안내 | `error` + 배너 패턴 | 왼쪽 보더 3px + 연한 배경 |

- **베이지·크림 톤 금지 (공고 파트 웹)**: 배경·채움·플레이스홀더에 **`surfaceMuted`**, **`creamWhite`** 등 크림/베이지 계열을 쓰지 않는다. 뉴트럴은 **`webPublisherPageBg`**, **`white`**, **`divider`** 조합으로 맞춘다. (의미 색은 **`accent` / `cardEmphasis` / `text*`**.)

`publisher_shared.dart` 의 `kPub*` 상수는 레거시 호환용이며, 새 코드는 **`AppColors`** 를 직접 쓰는 것을 권장합니다.

---

## 타이포그래피

- 폰트: **`GoogleFonts.notoSansKr`** (앱 전역과 동일 계열).
- **자간**: 본문·라벨 계열은 대략 **`-0.12` ~ `-0.18`** (과한 트래킹 지양). 섹션 라벨 **「진행 단계」** 등만 **양수 자간**(예: `0.72`)으로 에디토리얼 느낌.
- **제목 스케일 예시** (웹 공고자 로그인 카드): 타이틀 20 / w800 / height 1.2, 서브 13 / height 1.4.

---

## 컴포넌트 규격 (구현 기준)

### CTA 버튼

- **높이 48px** — **`AppPublisher.ctaHeight`**. 웹 로그인·공고 폼·입력·게시 완료·`job_publish_page` 등 주요 CTA 와 통일.
- **모서리(버튼)**: **`AppPublisher.buttonRadius`(8px)** — `JobPostForm` 상단 사진/AI·임시저장·등록, `job_input_page`·`job_publish_success_page`·`job_publish_page` 등.
- 온보딩 등 기존 `PubPrimaryButton`(radius 14) 패턴과 병존; **신규 공고 웹 플로우는 `AppPublisher` 토큰**을 따름.

### 카드 · 진행 헤더

- 상단 진행 요약 블록: **흰 배경 + 직각 + 은은한 그림자** (`blur 20`, `offset (0,6)`, black 8%).

### 단계 리스트 (`PublisherOnboardingStepRow`)

- 단계 번호 **01 / 02 / 03** 스타일, 상태별 색: 진행 **accent**, 완료 **cardEmphasis**, 잠금 **textDisabled**.
- 행 사이 **디바이더 1px**, 상하 패딩으로 리듬 유지.

### 상태 배너 (`PublisherOnboardingStatusBanner`)

- **왼쪽 컬러 보더 3px**, 배경은 `color.withOpacity(0.08)`, 아이콘 + 본문 13px.

---

## 관련 파일 (유지보수 시)

| 역할 | 경로 |
|------|------|
| 색·토큰 | `lib/core/theme/app_colors.dart` |
| 라운드·간격 공통 · 공고자 CTA/약한 라운드 | `lib/core/theme/app_tokens.dart` (`AppPublisher`) |
| 웹 통합 로그인(공고자 카드·라인 필드) | `lib/features/auth/web/web_login_page.dart` |
| 게시자 공통 위젯·`PubScaffold` | `lib/features/publisher/pages/publisher_shared.dart` |
| 인증 진행 UI | `lib/features/publisher/pages/publisher_onboarding_*.dart` |
| 웹 공고 등록 폼(밑줄·섹션 간격·드롭다운 테마) | `lib/features/jobs/ui/job_post_form.dart` |
| 웹 공고 **자료 입력**(좌우 2열 · 4탭 · 홍보이미지) | `lib/features/jobs/web/job_input_page.dart` |
| 공고 **초안 미리보기**(홍보이미지 갤러리 포함) | `lib/features/jobs/ui/job_post_preview.dart` |

---

## 변경 시 체크리스트

1. 색 변경은 **`AppColors`** 에서 primitive/semantic을 조정해 전파되는지 확인.
2. 웹 공고자만의 배경·셸 규칙을 바꿀 경우 **`webPublisherPageBg`** 와 `PubScaffold.webPublisherShell` 동작을 함께 검토.
3. 이 문서는 **의도·패턴**을 적는 곳이고, 픽셀 단일 소스는 **코드**입니다 — 수치가 어긋나면 코드를 기준으로 이 문서를 업데이트합니다.
