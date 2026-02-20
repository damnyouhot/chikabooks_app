# 소셜 로그인 보안 강화 문서 (최종 버전)

이 문서는 카카오/네이버 로그인의 서버 기반 토큰 검증 및 프로덕션 레벨 보안 강화 구현 상세를 다룹니다.

## 1. 보안 아키텍처 개요

### **기본 원칙**
- 클라이언트(Flutter 앱)는 신뢰할 수 없는 환경
- 모든 토큰 검증은 서버(Cloud Functions)에서 수행
- Access Token은 마스킹하여 로깅
- Firestore 기반 레이트 리미팅으로 남용 방지
- App Check 통합 준비 완료 (개발 환경에서는 경고만)
- 에러 코드 표준화로 정확한 문제 진단

### **흐름도**
```
[앱] 소셜 SDK 로그인
  ↓
[앱] Access Token 획득
  ↓
[앱] → [Cloud Functions] Access Token 전송
  ↓
[Cloud Functions] App Check 검증 (프로덕션 시)
  ↓
[Cloud Functions] 레이트 리미팅 체크 (Firestore)
  ↓
[Cloud Functions] → [소셜 API] 토큰 검증 (서버에서)
  ↓
[Cloud Functions] Firebase Custom Token 발급
  ↓
[Cloud Functions] → [앱] Custom Token + errorCode 반환
  ↓
[앱] Firebase Auth 로그인
```

---

## 2. 구현된 보안 기능

### 2.1 App Check 검증 (준비 완료)

**목적**: 실제 앱에서만 API 호출 가능하도록 제한

```typescript
// 개발 환경: 경고만 출력
if (!context.app) {
  console.warn("⚠️ App Check 미적용: 프로덕션 배포 시 활성화 필요");
}

// 프로덕션 환경: 아래 주석 해제하여 강제
// if (!context.app) {
//   throw new functions.https.HttpsError(
//     "failed-precondition",
//     "App Check 인증이 필요합니다.",
//     {errorCode: SocialLoginError.APP_CHECK_REQUIRED}
//   );
// }
```

**활성화 방법** (프로덕션 배포 시):
1. Firebase Console → App Check → 앱 등록
2. Android: Play Integrity API 설정
3. iOS: DeviceCheck/App Attest 설정
4. Functions 코드에서 주석 해제

### 2.2 입력 검증 (Input Validation)

**목적**: 잘못된 형식의 데이터나 악의적인 입력 차단

```typescript
// 1. 필수값 체크
if (!accessToken) {
  throw new functions.https.HttpsError(
    "invalid-argument",
    "accessToken은 필수입니다.",
    {errorCode: SocialLoginError.INVALID_INPUT}
  );
}

// 2. 타입 검증
if (typeof accessToken !== "string") {
  throw new functions.https.HttpsError(
    "invalid-argument",
    "accessToken은 문자열이어야 합니다.",
    {errorCode: SocialLoginError.INVALID_INPUT}
  );
}

// 3. 길이 검증 (20~2000자)
if (accessToken.length < 20 || accessToken.length > 2000) {
  throw new functions.https.HttpsError(
    "invalid-argument",
    "accessToken 길이가 유효하지 않습니다.",
    {errorCode: SocialLoginError.INVALID_INPUT}
  );
}

// 4. 빈값/공백 검증
if (accessToken.trim().length === 0) {
  throw new functions.https.HttpsError(
    "invalid-argument",
    "accessToken이 비어있습니다.",
    {errorCode: SocialLoginError.INVALID_INPUT}
  );
}
```

### 2.3 Firestore 기반 레이트 리미팅

**목적**: 무차별 대입 공격(Brute Force), DDoS 방지

```typescript
async function checkRateLimitFirestore(
  key: string,
  maxRequests: number,
  windowMs: number
): Promise<void> {
  const now = Date.now();
  const docRef = db.collection("rate_limits").doc(key);

  await db.runTransaction(async (transaction) => {
    const doc = await transaction.get(docRef);

    if (!doc.exists) {
      // 첫 요청
      transaction.set(docRef, {
        count: 1,
        resetAt: now + windowMs,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    const data = doc.data()!;
    if (now < data.resetAt) {
      // 윈도우 내
      if (data.count >= maxRequests) {
        throw new functions.https.HttpsError(
          "resource-exhausted",
          "너무 많은 요청이 발생했습니다. 잠시 후 다시 시도해주세요.",
          {errorCode: SocialLoginError.RATE_LIMIT}
        );
      }
      transaction.update(docRef, {
        count: admin.firestore.FieldValue.increment(1),
      });
    } else {
      // 윈도우 만료, 리셋
      transaction.set(docRef, {
        count: 1,
        resetAt: now + windowMs,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });
}
```

**제한:**
- **IP 기준**: 1분당 10회
- **저장 방식**: Firestore 트랜잭션 (함수 재시작해도 유지)
- **초과 시**: `RATE_LIMIT` 에러 코드 반환

**Firestore 구조:**
```
rate_limits/{provider}_ip_{ip}
{
  count: 5,
  resetAt: 1708521600000,  // Unix timestamp (ms)
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### 2.4 토큰 마스킹 (Token Masking)

**목적**: 로그에 민감한 Access Token 원문 노출 방지

```typescript
function maskToken(token: string): string {
  if (token.length <= 20) return "***";
  return `${token.substring(0, 10)}...${token.substring(token.length - 10)}`;
}

// 로그 출력 예시
console.log(`🔐 카카오 토큰 검증 시작 (토큰: abcdefghij...xyz1234567, IP: 192.168.1.1)`);
```

### 2.5 에러 코드 표준화

**목적**: 클라이언트가 에러 원인을 정확히 알고 적절한 조치를 취할 수 있도록 함

```typescript
enum SocialLoginError {
  RATE_LIMIT = "RATE_LIMIT",           // 레이트 리밋 초과
  TOKEN_EXPIRED = "TOKEN_EXPIRED",     // 만료된 토큰
  TOKEN_INVALID = "TOKEN_INVALID",     // 잘못된 토큰
  PROVIDER_DOWN = "PROVIDER_DOWN",     // Provider 서버 장애
  APP_CHECK_REQUIRED = "APP_CHECK_REQUIRED",  // App Check 미적용
  INVALID_INPUT = "INVALID_INPUT",     // 입력값 오류
  INTERNAL_ERROR = "INTERNAL_ERROR"    // 내부 서버 오류
}
```

**에러 반환 예시:**
```typescript
throw new functions.https.HttpsError(
  "unauthenticated",
  "유효하지 않거나 만료된 Access Token입니다. 다시 로그인해주세요.",
  {errorCode: SocialLoginError.TOKEN_EXPIRED}
);
```

**에러 코드 매핑:**
| HTTP Status | errorCode | 사용자 메시지 |
|-------------|-----------|---------------|
| 401 | `TOKEN_EXPIRED` | 만료된 토큰, 재로그인 필요 |
| 400 | `TOKEN_INVALID` | 잘못된 요청 |
| 500+ | `PROVIDER_DOWN` | 서버 장애, 잠시 후 재시도 |
| Timeout | `PROVIDER_DOWN` | 네트워크 확인 필요 |
| - | `RATE_LIMIT` | 너무 많은 요청 |
| - | `INVALID_INPUT` | 입력값 오류 |
| - | `APP_CHECK_REQUIRED` | App Check 필요 |

### 2.6 Firebase UID 충돌 방지

**목적**: 다른 Provider의 동일 ID와 충돌 방지

**UID 형식:**
- **카카오**: `kakao:12345678`
- **네이버**: `naver:abcdefgh`
- **구글**: Firebase 자동 생성 (표준 Provider)
- **애플**: Firebase 자동 생성 (표준 Provider)

**하위 호환성 (Legacy Migration):**
기존 `kakao_12345678`, `naver_abcdefgh` 형식의 사용자는 자동으로 기존 UID를 유지합니다.

```typescript
// 기존 사용자 체크
const legacyUid = `kakao_${kakaoId}`;
try {
  const legacyUser = await admin.auth().getUser(legacyUid);
  if (legacyUser) {
    console.log(`⚠️ 기존 사용자 발견 (${legacyUid}), 하위 호환 유지`);
    // 기존 UID로 계속 사용
    return customToken;
  }
} catch {
  // 신규 사용자는 새 형식 사용
  const uid = `kakao:${kakaoId}`;
}
```

---

## 3. 함수별 상세

### 3.1 verifyKakaoToken

**엔드포인트**: `https://us-central1-chikabooks3rd.cloudfunctions.net/verifyKakaoToken`

**입력:**
```json
{
  "accessToken": "카카오 Access Token"
}
```

**출력 (성공):**
```json
{
  "success": true,
  "customToken": "Firebase Custom Token",
  "uid": "kakao:12345678"
}
```

**출력 (실패):**
```json
{
  "code": "unauthenticated",
  "message": "유효하지 않거나 만료된 Access Token입니다.",
  "details": {
    "errorCode": "TOKEN_EXPIRED"
  }
}
```

**카카오 API 호출:**
- URL: `https://kapi.kakao.com/v2/user/me`
- Header: `Authorization: Bearer {accessToken}`
- Timeout: 10초

### 3.2 verifyNaverToken

**엔드포인트**: `https://us-central1-chikabooks3rd.cloudfunctions.net/verifyNaverToken`

**입력:**
```json
{
  "accessToken": "네이버 Access Token"
}
```

**출력 (성공):**
```json
{
  "success": true,
  "customToken": "Firebase Custom Token",
  "uid": "naver:abcdefgh"
}
```

**네이버 API 호출:**
- URL: `https://openapi.naver.com/v1/nid/me`
- Header: `Authorization: Bearer {accessToken}`
- Timeout: 10초

---

## 4. 보안 체크리스트

### ✅ 구현 완료
- [x] 입력 검증 (타입, 길이, 빈값)
- [x] Firestore 기반 레이트 리미팅 (IP 기준, 1분당 10회, 트랜잭션 사용)
- [x] 토큰 마스킹 (로그 보안)
- [x] 에러 코드 표준화 (`errorCode` 필드)
- [x] UID prefix 충돌 방지 (`kakao:`, `naver:`)
- [x] 서버 기반 토큰 검증
- [x] Timeout 설정 (10초)
- [x] Firestore users 컬렉션 자동 생성/업데이트
- [x] 하위 호환성 (Legacy UID 유지)
- [x] App Check 통합 준비 (개발 환경에서는 경고만)

### ⚠️ 추가 권장 사항 (프로덕션 배포 전)
- [ ] **App Check 활성화** (Firebase Console에서 설정 후 코드 주석 해제)
- [ ] Firestore Security Rules 강화 (`rate_limits` 컬렉션 접근 제한)
- [ ] UID 기준 레이트 리미팅 추가 (로그인 후 반복 호출 방지)
- [ ] Cloud Armor 연동 (IP 차단, 지역 제한) - 선택사항

---

## 5. Firestore 구조

### **rate_limits 컬렉션** (레이트 리미팅)
```
rate_limits/{provider}_ip_{ip}
{
  count: number,
  resetAt: number,  // Unix timestamp (ms)
  createdAt: Timestamp,
  updatedAt?: Timestamp
}
```

**예시:**
- `kakao_ip_192.168.1.1`: 192.168.1.1 IP의 카카오 로그인 시도 횟수
- `naver_ip_203.0.113.42`: 203.0.113.42 IP의 네이버 로그인 시도 횟수

### **users 컬렉션**
```
users/{uid}
{
  email: string | null,
  displayName: string | null,
  provider: 'kakao' | 'naver' | 'google' | 'apple' | 'email',
  providerId: string,
  lastLoginAt: Timestamp
}
```

---

## 6. Flutter 에러 처리 예시

```dart
try {
  final callable = _functions.httpsCallable('verifyKakaoToken');
  final response = await callable.call({'accessToken': token});
  
  // 성공
  return response.data;
} on FirebaseFunctionsException catch (e) {
  // details에 errorCode가 포함됨
  final errorCode = e.details?['errorCode'];
  
  switch (errorCode) {
    case 'RATE_LIMIT':
      showSnackBar('너무 많은 요청입니다. 잠시 후 다시 시도해주세요.');
      break;
    case 'TOKEN_EXPIRED':
      showSnackBar('로그인이 만료되었습니다. 다시 로그인해주세요.');
      // 재로그인 유도
      break;
    case 'TOKEN_INVALID':
      showSnackBar('잘못된 로그인 정보입니다.');
      break;
    case 'PROVIDER_DOWN':
      showSnackBar('일시적인 오류가 발생했습니다. 잠시 후 다시 시도해주세요.');
      break;
    case 'APP_CHECK_REQUIRED':
      showSnackBar('앱을 최신 버전으로 업데이트해주세요.');
      break;
    case 'INVALID_INPUT':
      showSnackBar('잘못된 요청입니다.');
      break;
    default:
      showSnackBar('로그인 중 오류가 발생했습니다: ${e.message}');
  }
  return null;
}
```

---

## 7. Firestore Security Rules

```javascript
service cloud.firestore {
  match /databases/{database}/documents {
    // 레이트 리미팅 문서는 서버만 접근 가능
    match /rate_limits/{limitId} {
      allow read, write: if false;  // 클라이언트 접근 금지
    }
    
    // 사용자 정보
    match /users/{uid} {
      allow read: if request.auth != null && request.auth.uid == uid;
      allow write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

---

## 8. 테스트 시나리오

### 8.1 정상 로그인
1. 앱에서 카카오/네이버 로그인
2. Access Token 획득
3. `verifyKakaoToken` / `verifyNaverToken` 호출
4. Custom Token 수신
5. Firebase Auth 로그인 성공

### 8.2 만료된 토큰
1. 만료된 Access Token으로 함수 호출
2. 카카오/네이버 API가 401 반환
3. 함수가 `errorCode: TOKEN_EXPIRED` 반환
4. 앱에서 "재로그인 필요" 메시지 표시

### 8.3 레이트 리미팅
1. 같은 IP에서 1분간 11번 호출
2. 11번째 호출에서 `errorCode: RATE_LIMIT` 반환
3. 1분 후 다시 가능

### 8.4 기존 사용자 (Legacy UID)
1. 기존 `kakao_12345678` UID 사용자 로그인
2. 함수가 기존 UID 감지
3. 기존 UID로 Custom Token 발급
4. 데이터 유지됨

### 8.5 신규 사용자
1. 처음 로그인하는 사용자
2. 새 UID 형식 (`kakao:12345678`) 생성
3. Firebase Auth 및 Firestore에 사용자 생성

---

## 9. 모니터링 및 로그

### Firebase Console에서 확인할 로그

**성공 케이스:**
```
🔐 카카오 토큰 검증 시작 (토큰: abcdefghij...xyz1234567, IP: 192.168.1.1)
✅ 카카오 토큰 검증 성공 (카카오ID: 12345678)
✅ 신규 사용자, 새 UID 형식 사용: kakao:12345678
✅ 카카오 Custom Token 발급 완료 (UID: kakao:12345678)
```

**기존 사용자 케이스:**
```
⚠️ 기존 사용자 발견 (kakao_12345678), 하위 호환 유지
✅ 기존 사용자 로그인 완료 (UID: kakao_12345678)
```

**에러 케이스:**
```
⚠️ verifyKakaoToken error: 유효하지 않거나 만료된 Access Token입니다.
카카오 API 에러 (status: 401): {...}
```

**레이트 리밋 케이스:**
```
⚠️ verifyKakaoToken error: 너무 많은 요청이 발생했습니다.
```

---

## 10. Release 빌드 주의사항

### Android
- **KeyHash 등록**: Google Play App Signing Key의 SHA1을 카카오/네이버 개발자센터에 등록
- **ProGuard**: `firebase-auth`, `kakao-sdk`, `flutter-naver-login` 패키지 유지 규칙 확인
- **App Check**: Play Integrity API 설정

### iOS
- **URL Scheme**: `Info.plist`에 정확한 URL Scheme 등록 확인
- **App Transport Security**: HTTPS 통신 허용 확인
- **App Check**: DeviceCheck 또는 App Attest 설정

---

## 11. 참고 문서

- **계정 통합 정책**: `docs/ACCOUNT_LINKING_POLICY.md`
- [Firebase Custom Token 공식 문서](https://firebase.google.com/docs/auth/admin/create-custom-tokens)
- [카카오 로그인 API 문서](https://developers.kakao.com/docs/latest/ko/kakaologin/rest-api)
- [네이버 로그인 API 문서](https://developers.naver.com/docs/login/api/api.md)
- [Firebase Functions 보안 가이드](https://firebase.google.com/docs/functions/security)
- [Firebase App Check 문서](https://firebase.google.com/docs/app-check)
