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

---

## 변경 시 체크리스트

1. 색 변경은 **`AppColors`** 에서 primitive/semantic을 조정해 전파되는지 확인.
2. 웹 공고자만의 배경·셸 규칙을 바꿀 경우 **`webPublisherPageBg`** 와 `PubScaffold.webPublisherShell` 동작을 함께 검토.
3. 이 문서는 **의도·패턴**을 적는 곳이고, 픽셀 단일 소스는 **코드**입니다 — 수치가 어긋나면 코드를 기준으로 이 문서를 업데이트합니다.
