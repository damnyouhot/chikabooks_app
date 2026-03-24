# 관리자 계정 설정

앱(`UserProfileService.isAdmin`)과 Firestore 보안 규칙은 모두 **`users/{uid}.isAdmin == true`** 를 봅니다.  
통계(대시보드 가입자·활성 등)에서 빼려면 **`excludeFromStats: true`** 가 필요합니다.

## 1) 스크립트로 한 번에 설정 (권장)

1. Firebase Console → **프로젝트 설정** → **서비스 계정** → **새 비공개 키** 생성  
2. JSON 파일을 **`functions/serviceAccountKey.json`** 으로 저장 (저장소에 커밋하지 마세요)  
3. 터미널:

```bash
cd functions
npm install
npm run setup-admin -- "여기에_전체_이메일_주소"
```

또는 UID를 알면:

```bash
npm run setup-admin -- YOUR_FIREBASE_UID
```

이메일이 `Yhgjd`로 시작하는 계정이 **한 명뿐**이면:

```bash
npm run setup-admin:yhgjd
```

프로젝트 **루트**에서:

```bash
node tools/setup_admin.js "your@email.com"
node tools/setup_admin.js --by-email-prefix Yhgjd
```

기본 동작: **`isAdmin: true`** + **`excludeFromStats: true`**

### 옵션

| 플래그 | 의미 |
|--------|------|
| `--no-exclude` | 관리자만, 통계에는 포함 |
| `--exclude-only` | 통계만 제외, 관리자 아님 |

### 서비스 계정 경로

`GOOGLE_APPLICATION_CREDENTIALS` 환경 변수에 JSON 절대 경로를 지정하면 `functions/serviceAccountKey.json` 대신 사용합니다.

## 2) 콘솔에서 수동

1. **Authentication**에서 해당 사용자 **UID** 복사  
2. **Firestore** → `users` → 해당 UID 문서에  
   - `isAdmin` = `true`  
   - `excludeFromStats` = `true`  

## 3) 삭제된 예전 관리자 계정

Firebase **Authentication 사용자까지 삭제**된 경우 콘솔/코드로 되살리기는 어렵고, 위 방법으로 **남아 있는 계정**에 관리자를 다시 주면 됩니다.

## 4) 앱에서 반영

`UserProfileService` 캐시 때문에 관리자 메뉴가 바로 안 보이면 **로그아웃 후 재로그인**하세요.
