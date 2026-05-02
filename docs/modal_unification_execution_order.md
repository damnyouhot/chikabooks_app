# 모달 UI 통일 — 실행 순서표

작업 계획서(게이지 팝업 기준의 `Dialog` + `AppColors.appBg` 카드 패밀리)에 따른 **실행 순서**입니다.  
**선행 조건**: 공통 래퍼(`AppModalScaffold` 등)가 있어야 하는 단계는 표에 명시했습니다.

---

## 0. 작업 전 스냅샷

| 항목 | 값 |
|------|-----|
| 커밋 | `b7c6ec7` — `chore: 모달 UI 통일 작업 전 워킹트리 스냅샷` |
| 원격 | `origin/main` 푸시 완료 |

### 진행 로그

| 날짜 | 단계 | 내용 |
|------|------|------|
| 2026-05-02 | Phase A (순서 1–2) | `app_modal_scaffold.dart`, `app_confirm_modal.dart` 추가. 호출부 이전 없음. |
| 2026-05-02 | Phase B (순서 3–5) | `bond_poll_section`, `hira_comment_sheet`, `user_goal_sheet`의 `AlertDialog`를 `AppConfirmModal` / `AppModalDialog`로 교체. |
| 2026-05-02 | Phase C (순서 6–9) | `bond_page`, `diary_timeline_page`, `growth_page`, `job_page`의 `AlertDialog`를 `AppModalDialog` / `AppConfirmModal`로 교체(일기 삭제는 확인 후 본문에서만 삭제). |
| 2026-05-02 | Phase D (순서 10–15) | `career_tab`·`career_network_section` 삭제 확인을 `AppConfirmModal`로 통일. 11·12·13·15행 파일은 `AlertDialog` 없음(시트·날짜만, 모달 통일 범위 외). |
| 2026-05-02 | Phase E (순서 16–23) | 이력서 홈·편집·지원내역, 구인 웹(`job_post_web_page`, `job_input`, `job_draft_editor`, `job_manage_section`, `published_job_detail`)의 `AlertDialog`를 `AppConfirmModal` / `AppModalDialog`로 교체. `job_post_form`(순서 24)은 제외. |
| 2026-05-02 | Phase F (순서 25–29) | `me_notifications`, `me_orders`, `me_billing`, `me_clinic`, `me_applicants_pool` 및 `edit_pool_meta_dialog`·`notify_past_applicants_dialog`의 `AlertDialog`를 `AppConfirmModal` / `AppModalDialog`로 교체. |
| 2026-05-02 | Phase G (순서 30–32) | `publisher_pending_page` 문의 `AppModalDialog`, `publisher_clinic_identity_section` 관리자 확인 `AppConfirmModal`. `clinic_selector`는 `AlertDialog` 없음·출판 각진 `Dialog` 톤 유지로 코드 변경 없음(검토 완료). |
| 2026-05-02 | 순서 24 | `job_post_form` 교통편 추가 `Dialog`를 `AppModalDialog`로 교체. `showDatePicker`는 Phase N 정책 전까지 유지. |

## 1. 인벤토리 스프레드시트 (착수 직후 1일 이내)

**열 정의** (각 행 = 모달 1건 이상 가능, 파일 단위로도 가능)

| 열 | 설명 |
|----|------|
| ID | 고유 번호 |
| 파일 | `lib/...dart` |
| API | `showDialog` / `showModalBottomSheet` / `showDatePicker` / `showLicensePage` |
| 유형 | `AlertDialog` / `Dialog` / `Dialog.fullscreen` / 시트 / 시스템 |
| 도메인 | 본드·나·속닥·구인·… |
| 위험도 | Low / Med / High |
| 반환 타입 | `bool` / `String` / void / 제네릭 |
| 게이지 패밀리 여부 | Y / N (현재 기준) |
| 상태 | 미착수 / 진행 / 완료 / 보류 |
| 비고 | Stateful·폼·웹 전용 등 |

---

## 2. Phase 요약

| Phase | 내용 | 선행 |
|-------|------|------|
| **A** | 공통 위젯 추가 (`AppModalScaffold`, `AppConfirmModal` 등), 사용처 변경 없음 | 없음 |
| **B** | 위젯 레이어·단순 확인 위주 (Low) | A |
| **C** | `pages/` 단순 다이얼로그 | A |
| **D** | 커리어·이력 (시트 + 다이얼로그 혼재) | A |
| **E** | 구인·채용 (웹/폼) | A |
| **F** | 나·알림·결제·클리닉 | A |
| **G** | 출판·클리닉 선택 | A |
| **H** | 속닥속닥 (댓글 시트 `AlertDialog` 등 주의) | A |
| **I** | 관리자 탭 | A |
| **J** | 인증·웹 계정 | A |
| **K** | 온보딩 | A |
| **L** | 전자책·PDF·설정(라이선스) | A |
| **M** | 바텀시트 전용 래퍼 도입 후 시트 일괄 | A 권장 |
| **N** | `showDatePicker` / `showLicensePage` 정책 반영 | 디자인 결정 |

---

## 3. 실행 순서표 (파일 단위 · 권장 순서)

**규칙**: 한 PR은 이 표에서 **연속한 소그룹**만 묶는다. High는 **파일당 PR 분리** 가능.

| 순서 | Phase | 경로 | 주요 API·내용 | 위험 | 상태 |
|------|-------|------|----------------|------|------|
| 1 | A | `lib/core/widgets/app_modal_scaffold.dart` | `AppModalCard` / `AppModalDialog` 추가 | Low | ✅ |
| 2 | A | `lib/core/widgets/app_confirm_modal.dart` | `AppConfirmModal` 추가 | Low | ✅ |
| 3 | B | `lib/widgets/bond/bond_poll_section.dart` | `showDialog`+`AlertDialog` | Low | ✅ |
| 4 | B | `lib/widgets/hira_comment_sheet.dart` | `showDialog` | Med | ✅ |
| 5 | B | `lib/widgets/user_goal_sheet.dart` | 시트 + 내부 `showDialog` | Med | ✅ |
| 6 | C | `lib/pages/bond_page.dart` | `showDialog` | Low | ✅ |
| 7 | C | `lib/pages/diary_timeline_page.dart` | `showDialog` | Low | ✅ |
| 8 | C | `lib/pages/growth_page.dart` | `showDialog` 다수 + 시트 | Med | ✅ |
| 9 | C | `lib/pages/job_page.dart` | `showDialog` | Med | ✅ |
| 10 | D | `lib/pages/career/career_tab.dart` | `showDialog` | Low | ✅ |
| 11 | D | `lib/pages/career/career_stage_section.dart` | `showModalBottomSheet` | Low | ✅ |
| 12 | D | `lib/pages/career/career_skill_section.dart` | 시트 | Low | ✅ |
| 13 | D | `lib/pages/career/career_identity_section.dart` | 시트 + `showDatePicker` | Med | ✅ |
| 14 | D | `lib/pages/career/career_network_section.dart` | 시트·다이얼로그·날짜 | Med | ✅ |
| 15 | D | `lib/pages/career/resume_pick_for_network_sheet.dart` | 시트 | Low | ✅ |
| 16 | E | `lib/features/resume/screens/resume_home_screen.dart` | `showDialog` 다수 | Med | ✅ |
| 17 | E | `lib/features/resume/screens/resume_edit_screen.dart` | `showDialog` | Low | ✅ |
| 18 | E | `lib/features/resume/screens/my_applications_screen.dart` | `showDialog` | Med | ✅ |
| 19 | E | `lib/features/jobs/web/job_post_web_page.dart` | `showDialog` | Med | ✅ |
| 20 | E | `lib/features/jobs/web/job_input_page.dart` | `showDialog` | Med | ✅ |
| 21 | E | `lib/features/jobs/web/job_draft_editor_page.dart` | `showDialog` | Med | ✅ |
| 22 | E | `lib/features/jobs/web/job_manage_section.dart` | `showDialog` | Med | ✅ |
| 23 | E | `lib/features/jobs/web/published_job_detail_page.dart` | `showDialog` | Med | ✅ |
| 24 | E | `lib/features/jobs/ui/job_post_form.dart` | `Dialog`+`showDatePicker` | High | ✅ |
| 25 | F | `lib/features/me/pages/me_notifications_page.dart` | `showDialog` | Med | ✅ |
| 26 | F | `lib/features/me/pages/me_orders_page.dart` | `showDialog` | Med | ✅ |
| 27 | F | `lib/features/me/pages/me_billing_page.dart` | `showDialog` | High | ✅ |
| 28 | F | `lib/features/me/pages/me_clinic_page.dart` | `showDialog` | Med | ✅ |
| 29 | F | `lib/features/me/pages/me_applicants_pool_page.dart` | `showDialog` 다수 + 위젯 다이얼로그 연동 | Med | ✅ |
| 30 | G | `lib/features/publisher/pages/publisher_pending_page.dart` | `showDialog` | Med | ✅ |
| 31 | G | `lib/features/publisher/widgets/publisher_clinic_identity_section.dart` | `showDialog` | Med | ✅ |
| 32 | G | `lib/features/publisher/widgets/clinic_selector.dart` | `showDialog` | Med | ✅ |
| 33 | H | `lib/features/senior_qna/widgets/senior_question_comments_sheet.dart` | 시트 + `AlertDialog` | Med | |
| 34 | H | `lib/features/senior_qna/widgets/senior_question_card.dart` | 이미 일부 게이지 패밀리 — 나머지·풀스크린 검토 | Med | |
| 35 | H | `lib/features/senior_qna/widgets/senior_sticker_widgets.dart` | 시트 | Low | |
| 36 | I | `lib/pages/admin/tabs/admin_overview_tab.dart` | `showDialog` 다수 | High | |
| 37 | I | `lib/pages/admin/tabs/admin_verify_tab.dart` | `showDialog` | High | |
| 38 | I | `lib/pages/admin/tabs/admin_billing_tab.dart` | `showDialog` | High | |
| 39 | I | `lib/pages/admin/admin_ebook_create_page.dart` | `showDatePicker` | Med | |
| 40 | I | `lib/pages/admin/admin_ebook_edit_page.dart` | `showDatePicker` | Med | |
| 41 | J | `lib/pages/auth/sign_in_page.dart` | `showDialog` | High | |
| 42 | J | `lib/features/auth/services/web_account_actions_service.dart` | `showDialog` | High | |
| 43 | K | `lib/features/onboarding/app_onboarding_overlay.dart` | `showDialog` | Med | |
| 44 | L | `lib/pages/ebook/ebook_detail_page.dart` | 커스텀 `Dialog` 톤 정렬 | Low | |
| 45 | L | `lib/pages/ebook/ebook_list_page.dart` | 시트 | Low | |
| 46 | L | `lib/pages/ebook/pdf_reader_page.dart` | `AlertDialog` | Low | |
| 47 | L | `lib/pages/settings/settings_page.dart` | `showLicensePage` | Low | |
| 48 | M | `lib/widgets/diary_input_sheet.dart` | 시트 | Low | |
| 49 | M | `lib/widgets/job/filter_bottom_sheet.dart` | 시트 | Low | |
| 50 | M | `lib/widgets/job/quick_apply_sheet.dart` | 시트 | Low | |
| 51 | M | `lib/widgets/fee_lookup_section.dart` | 시트 | Low | |
| 52 | M | `lib/widgets/hira_web_view_sheet.dart` | 시트 | Low | |
| 53 | M | `lib/widgets/hira_update_card.dart` | 시트 | Low | |
| 54 | M | `lib/widgets/hira_update_compact_item.dart` | 시트 | Low | |
| 55 | M | `lib/widgets/hira_update_detail_sheet.dart` | 시트(중첩 시트 주의) | Med | |
| 56 | N | *(정책 반영)* `Theme` 또는 래핑 | `showDatePicker` 공통 | 결정 후 | |
| 57 | N | *(정책 반영)* 라이선스 화면 | `showLicensePage` | 결정 후 | |
| 58 | 검수 | `lib/pages/caring_page.dart` | 게이지 외 `AlertDialog` 2건(먹이·개념) | Low | |

**참고**: `lib/pages/caring_page.dart`는 이미 게이지 패밀리가 있으므로 순서 **후반**에 나머지 `AlertDialog`만 정리하면 충돌이 적다.

---

## 4. PR 묶음 예시 (연속 순서 기준)

| PR 이름 | 순서 범위 | 설명 |
|---------|-----------|------|
| `modal-A-scaffold` | 1–2 | 공통 위젯만 |
| `modal-B-widgets-hira-bond` | 3–5 | 위젯 3종 |
| `modal-C-pages-core` | 6–9 | 본드·일기·성장·구인 탭 |
| `modal-D-career` | 10–15 | 커리어 |
| `modal-E-resume-jobs-1` | 16–23 | 이력 + 구인(폼 제외) |
| `modal-E-job-post-form` | 24 | **단독 PR** 권장 |
| `modal-F-me` | 25–29 | 나 |
| `modal-G-publisher` | 30–32 | 출판 |
| `modal-H-senior-qna` | 33–35 | 속닥속닥 |
| `modal-I-admin` | 36–40 | 관리자 + 날짜 |
| `modal-J-auth` | 41–42 | 인증·계정 |
| `modal-K-onboarding` | 43 | 온보딩 |
| `modal-L-ebook-settings` | 44–47 | 전자책·설정 |
| `modal-M-sheets` | 48–55 | 바텀시트 묶음 |
| `modal-N-system-pickers` | 56–57 | 시스템 UI 정책 |
| `modal-caring-alerts` | 58 | 돌보기 나머지 |

---

## 5. 완료 정의 (매 PR)

- [ ] 해당 파일의 모달 **반환값·분기** 동일  
- [ ] `dart analyze` 통과  
- [ ] PR 본문에 **수동 테스트 체크리스트** 3줄 이상  
- [ ] 인벤토리 시트 행 **상태 갱신**

---

## 6. 관련 위젯(다이얼로그만 빌드하는 파일)

인벤토리에 포함하되, `showDialog` 호출부는 부모에 있을 수 있음.

- `lib/features/me/pages/widgets/edit_pool_meta_dialog.dart`
- `lib/features/me/pages/widgets/notify_past_applicants_dialog.dart` *(해당 시)*

부모 `me_applicants_pool_page.dart`와 **같은 PR**에서 다루는 것을 권장한다.

---

이 문서는 저장소 루트 `docs/modal_unification_execution_order.md`에 두었다. 다음 단계는 **Phase H(속닥속닥, 33–35)** 또는 **Phase N**에서 `showDatePicker` 정책 반영 및 `job_post_form` 내 날짜 피커 정리다.
