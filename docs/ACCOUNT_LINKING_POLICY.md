# 계정 통합 정책

## 1. 기본 원칙

### **1계정 = 1 Firebase UID = 1 소셜 Provider**
- 하나의 Firebase UID는 하나의 소셜 계정(Provider)에만 연결됩니다
- **계정 병합은 지원하지 않습니다**
- 다른 Provider로 로그인하면 **별도 계정**이 생성됩니다

### **예시**
- ❌ **불가능**: 카카오 로그인 → 네이버 로그인 (다른 계정으로 인식됨)
- ✅ **가능**: 카카오 로그인 → 카카오 재로그인 (같은 계정)
- ❌ **불가능**: 카카오 계정 + 네이버 계정을 하나로 통합

---

## 2. 계정 생성 정책

### **원칙**
- 첫 로그인 시 선택한 Provider가 **주 계정(Primary Account)**이 됩니다
- 주 계정 변경은 **고객센터 문의**를 통해서만 가능합니다
- 다른 Provider로 로그인하면 **완전히 새로운 별도 계정**으로 생성됩니다

### **Firebase UID 구조**
```
카카오: kakao:12345678 (또는 kakao_12345678 - 기존 사용자)
네이버: naver:abcdefgh (또는 naver_abcdefgh - 기존 사용자)
구글: Firebase 자동 생성 UID (28자 영숫자)
애플: Firebase 자동 생성 UID (28자 영숫자)
```

---

## 3. 현재 구현 상태 (2026-02-21 기준)

### ✅ **구현 완료**
- 소셜 로그인 (카카오, 네이버, 구글, 애플, 이메일/비밀번호)
- 1 Provider = 1 Firebase UID
- 하위 호환성 (기존 `kakao_*`, `naver_*` 형식 유지)

### ⚠️ **미구현 (향후 계획)**
- 계정 연결 (Account Linking) 화면
- 다른 Provider로 같은 계정 접근
- 주 계정 변경 기능
- 계정 병합 기능

---

## 4. 사용자 안내 문구 (앱 내 표시)

### **첫 로그인 화면**
```
🔐 치과책방에 로그인

[카카오로 로그인]
[네이버로 로그인]
[구글로 로그인]
[애플로 로그인]
[이메일로 로그인]

ℹ️ 로그인 수단을 선택하면 해당 계정으로 가입됩니다.
   다른 로그인 수단을 사용하면 별도 계정이 생성됩니다.
```

### **설정 화면**
```
[계정 정보]
로그인 방식: 카카오
이메일: user@example.com
UID: kakao:12345678

ℹ️ 계정 병합은 지원하지 않습니다.
   주 로그인 수단을 변경하려면 고객센터로 문의해주세요.
```

---

## 5. 고객 문의 대응 가이드

### **Q: 카카오로 가입했는데, 네이버로 로그인하니 새 계정이 됐어요**
**A**: 
현재 치과책방은 로그인 수단별로 별도 계정을 생성합니다.
- 카카오 계정: `kakao:12345678`
- 네이버 계정: `naver:abcdefgh` (별개 계정)

**해결 방법**:
1. 기존 계정(카카오)으로 로그인
2. 또는 고객센터로 계정 병합 문의

**구매 내역 이전**:
고객센터를 통해 수동으로 구매 내역을 이전할 수 있습니다.

---

### **Q: 계정을 통합할 수 있나요?**
**A**:
현재는 자동 통합 기능이 없습니다.
향후 "계정 연결" 기능을 추가할 예정이며, 그 전까지는 고객센터를 통해 수동 병합을 지원합니다.

**필요 정보**:
- 주로 사용할 로그인 수단
- 통합할 계정의 이메일/UID
- 구매 내역 확인을 위한 본인 인증

---

### **Q: 이메일 주소로 여러 Provider를 연결할 수 없나요?**
**A**:
현재 구조상 이메일 주소는 계정 식별자로 사용되지 않습니다.
- Firebase UID (예: `kakao:12345678`)가 고유 식별자입니다
- 같은 이메일이라도 Provider가 다르면 별개 계정입니다

**향후 개선 계획**:
이메일 기반 계정 통합 기능을 검토 중입니다.

---

## 6. Firestore 데이터 구조

### **users 컬렉션**
```typescript
users/{uid}
{
  email: string | null,
  displayName: string | null,
  provider: 'kakao' | 'naver' | 'google' | 'apple' | 'email',
  providerId: string,  // 소셜 Provider의 사용자 ID
  lastLoginAt: Timestamp,
  createdAt: Timestamp,
  
  // 향후 추가 예정
  linkedProviders?: {
    kakao?: string,
    naver?: string,
    google?: string,
    apple?: string
  }
}
```

### **rate_limits 컬렉션** (레이트 리미팅)
```typescript
rate_limits/{provider}_ip_{ip}
{
  count: number,
  resetAt: number,  // Unix timestamp (ms)
  createdAt: Timestamp,
  updatedAt?: Timestamp
}
```

---

## 7. Firebase Security Rules

```javascript
service cloud.firestore {
  match /databases/{database}/documents {
    // 사용자 정보
    match /users/{uid} {
      allow read: if request.auth != null && request.auth.uid == uid;
      
      // 일반 필드는 본인만 수정 가능
      allow update: if request.auth != null 
                    && request.auth.uid == uid
                    && !request.resource.data.diff(resource.data).affectedKeys().hasAny(['linkedProviders']);
      
      // linkedProviders 필드는 서버(Cloud Functions)에서만 수정 가능
      // (향후 계정 연결 기능 구현 시 사용)
    }
    
    // 레이트 리미팅 문서는 서버만 접근 가능
    match /rate_limits/{limitId} {
      allow read, write: if false;
    }
  }
}
```

---

## 8. 향후 계정 연결(Linking) 기능 계획

### **설계 방향**
```
[설정] → [계정 관리] → [다른 로그인 수단 추가]

현재 로그인: 카카오 (kakao:12345678)

추가 가능한 로그인 수단:
- [ ] 네이버
- [ ] 구글
- [ ] 애플

⚠️ 주의: 추가된 로그인 수단으로도 같은 계정에 접근할 수 있습니다.
```

### **구현 방식 (예정)**
```typescript
// Firestore: users/{uid}
{
  primaryProvider: "kakao",  // 최초 가입 Provider
  linkedProviders: {
    kakao: "12345678",       // 카카오 ID
    naver: "abcdefgh",       // 연결된 네이버 ID (옵션)
    google: "xyz@gmail.com"  // 연결된 구글 이메일 (옵션)
  }
}
```

### **보안 고려사항**
1. **인증 필수**: 새 Provider 연결 시 해당 Provider로 로그인 필수
2. **중복 방지**: 이미 다른 계정에 연결된 Provider는 연결 불가
3. **주 계정 보호**: `primaryProvider`는 변경 불가 (고객센터 통해서만)
4. **서버 검증**: 모든 연결/해제는 Cloud Functions에서 처리

---

## 9. 보안 및 개인정보 정책

### **UID 노출**
- UID는 민감 정보가 아니지만, 불필요하게 노출하지 않습니다
- 고객센터 문의 시에만 UID 제공을 요청합니다

### **Provider ID 보호**
- `providerId` (카카오/네이버 사용자 ID)는 외부에 노출하지 않습니다
- Firestore Security Rules로 본인만 읽기 가능하게 제한합니다

### **이메일 수집 정책**
- 소셜 로그인 시 Provider가 제공하는 이메일만 저장합니다
- 이메일이 없는 경우 `null`로 저장하며, 강제하지 않습니다
- 이메일은 고객 서비스 및 구매 확인 용도로만 사용합니다

---

## 10. 에러 코드 및 처리

### **소셜 로그인 에러 코드**
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

### **Flutter 에러 처리 예시**
```dart
try {
  final user = await KakaoAuthService.signInWithKakao();
  // 로그인 성공
} on FirebaseFunctionsException catch (e) {
  final errorCode = e.details?['errorCode'];
  
  switch (errorCode) {
    case 'RATE_LIMIT':
      showSnackBar('너무 많은 요청입니다. 잠시 후 다시 시도해주세요.');
      break;
    case 'TOKEN_EXPIRED':
      showSnackBar('로그인이 만료되었습니다. 다시 로그인해주세요.');
      break;
    // ... 기타 에러 처리
  }
}
```

---

## 11. 참고 자료

- [Firebase Authentication 공식 문서](https://firebase.google.com/docs/auth)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
- [카카오 로그인 API](https://developers.kakao.com/docs/latest/ko/kakaologin/rest-api)
- [네이버 로그인 API](https://developers.naver.com/docs/login/api/api.md)


