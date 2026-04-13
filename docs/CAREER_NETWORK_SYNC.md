# 나의 치과 히스토리 · 이력서 경력 동기화 (검증·배포)

이력서 경력을 커리어 카드(치과 히스토리, Firestore `careerNetwork`)에 반영하는 기능은 **웹과 모바일이 같은 Flutter 화면**을 씁니다. 다만 **스토어에 올린 앱은 웹 배포만으로는 갱신되지 않습니다.**

## 화면에서 어디로 가나

1. 하단 **「커리어」** 탭 (앱) 또는 웹에서 **`/jobs`** 로 이동  
2. 상단 세그먼트에서 **「커리어 카드」** 선택 (채용이 아닌 쪽)  
3. **「나의 치과 히스토리」** 영역에서 항목을 탭하거나, 영역을 펼쳐 **나의 치과 히스토리** 시트를 연다  
4. **「이력서에서 추출하기」** — 경력이 있는 이력서가 **1건 이상**이면 항상 **이력서 선택 시트**가 뜨고, 탭해 확정  
5. **「최근 AI 불러오기」** 배지는 OCR로 이력서를 확정한 뒤 `users/{uid}.lastImportedResumeId`가 있을 때, 목록에서 해당 이력서에 표시

코드 위치: `lib/pages/career/career_network_section.dart`, `resume_pick_for_network_sheet.dart`

## 웹에서 확인할 때

- 브라우저 주소: **`/jobs`** → 소탭 **커리어 카드**  
- 캐시 때문에 예전 JS가 남을 수 있음 → 시크릿 창 또는 강력 새로고침

## 모바일에서 최신 코드를 보려면

| 플랫폼 | 명령 (예시) |
|--------|-------------|
| iOS 시뮬레이터 | `flutter run` (또는 Xcode에서 Run) |
| Android 기기/에뮬 | `flutter run` / `flutter build apk` 후 설치 |
| 스토어 배포본 | **새 빌드 제출·심사 후** 사용자 업데이트 필요 |

**Firebase Hosting 배포**(`firebase deploy --only hosting`)은 **웹 정적 파일**만 바꿉니다. **설치형 앱 바이너리는 포함되지 않습니다.**

## 동작에 쓰는 Firestore 필드

- `users/{uid}.lastImportedResumeId` — AI/OCR 이력서 확정 시 클라이언트가 `merge`로 기록  
- 규칙: `firestore.rules`의 `match /users/{uid}` 에서 본인 `write` 허용

## “추출해도 내용이 이상하다”면

UI·동기화는 **이력서 문서의 `experiences` 필드**를 소스로 삼습니다. OCR 표·한 칸에 기간이 두 줄 같은 **원본 구조 문제**는 앱만으로 완전히 고칠 수 없고, 이력서 편집 화면에서 경력을 손보는 것이 필요할 수 있습니다.
