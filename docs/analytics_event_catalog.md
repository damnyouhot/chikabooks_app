# 분석 이벤트 카탈로그 (A파트)

## 단일 출처

- **코드**: `lib/core/analytics/event_catalog.dart` (`kEventCatalog`, `EventCatalog`)
- **기록 API**: `lib/services/admin_activity_service.dart` (`ActivityEventType`, `FunnelEventType`, `log` / `logFunnel`)

새 이벤트를 추가할 때는:

1. `ActivityEventType` 또는 `FunnelEventType`에 `value` 문자열을 추가하고  
2. 동일한 `type` 키로 `kEventCatalog`에 `EventMeta`를 추가합니다.  
3. Behavior «의미 있는 행동»에 넣으려면 `meaningfulBehavior: true`로 둡니다.

## 온보딩 순차 퍼널 (v3)

| 단계 | `activityLogs.type` | 기록 방식 |
|------|---------------------|-----------|
| ① | `view_sign_in_page` | 일반 `log` |
| ② | `funnel_step_2_feed` | 계정당 1회, `FunnelOnboardingService` + `logFunnel` |
| ③ | `funnel_step_3_poll` | 계정당 1회 (첫 공감 선택 시) |
| ④ | `funnel_step_4_quiz` | 계정당 1회 (첫 퀴즈 제출 시) |
| ⑤ | `funnel_step_5_career_specialty` | 계정당 1회 (`specialtyTags` 1개 이상 저장 시) |

중복 방지 필드: `users/{uid}.funnelOnboardingV2` (`feed`, `poll`, `quiz`, `career`).

대시보드 집계: `AdminDashboardService.getFunnelSteps`에서 단계별 **교집합**(순차 퍼널)으로 계산합니다.

## Behavior / 일별 집계

`AdminBehaviorService`, `AdminAnalyticsDailyService`는 `EventCatalog.meaningfulTypes`를 사용합니다.  
`caring_feed_success`는 밥주기 성공 시 `CaringActionService.tryFeed`에서 기록됩니다.

---

## B파트 (후속)

1. **웹 로그인 분석 패리티** — `WebLoginPage` 지원자 로그인에서 앱 `SignInPage`와 동일하게 `tap_login_*`, `view_sign_in_page`, `login_success`, `funnel_signup_complete` 기록 (`page: sign_in`, `extra.platform: web`).
2. **analytics_daily 키 단일화** — `EventCatalog.dailyFeatureUsageTypes`, `dailyTabConversionPairs`를 `AdminAnalyticsDailyService`·추세 차트와 맞춤. `featureUsage`에 **밥주기**(`caring_feed_success`) 포함.
3. **관리자 기능 반응 탭** — `FeatureReactionItem.tab`으로 카탈로그 탭명 표시, 아이콘 맵 확장.

---

## C파트 (Behavior·세그먼트·운영)

1. **카탈로그 단일화** — `kTabConversionRows`로 일별 `tabConversions`와 Behavior «탭→행동»을 동기화. `kBehaviorFeatureUsageRows`, `kBehaviorRepeatRows`, 세그먼트용 `kSegment*Types`를 [EventCatalog]에 두고 [AdminBehaviorService]가 참조.
2. **교감형 세그먼트** — `view_bond`·`poll_*` 이벤트가 있으면 «교감형» 카운트. 유령(ghost) 판정에서 교감·의미행동과 배타적으로 정리.
3. **Behavior UI** — 기능 실행률에 **캐릭터 밥주기**, 반복 사용에 **밥주기 2회+**, 유저 타입에 **교감형** 카드 추가.
4. **추세 차트** — 일별 `segments.bond` 라인 추가 (백필 후 데이터 반영).
5. **스냅샷 워밍** — [OnboardingGate] `initState`에서 `AdminActivityService.warmupCache()` 호출 (로그인 세션에서 첫 이벤트부터 스냅샷 캐시 활용).
6. **첫 클릭** — `caring_feed_success`, `poll_*`, `view_career`·`tap_career_edit`를 탭 버킷에 매핑, **커리어 탭** 버킷 추가.
