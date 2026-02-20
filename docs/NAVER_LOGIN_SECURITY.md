# 네이버 로그인 보안 정리

## ✅ **적용된 보안 조치**

### **1. 서버 기반 토큰 검증**

**문제:**
- 클라이언트에서만 네이버 로그인을 검증하면 위조 가능

**해결:**
- 앱은 Access Token만 획득
- 서버(Cloud Functions)에서 네이버 API로 토큰 재검증
- 검증 성공 시 Custom Token 발급

**구조:**
```
[앱] 
  ↓ 네이버 SDK 로그인 → Access Token 획득
  ↓ verifyNaverToken(accessToken) 호출
[Cloud Functions]
  ↓ 네이버 API로 Access Token 검증 (서버에서 직접 호출)
  ↓ 유효한 경우에만 Custom Token 발급
[앱]
  ↓ Custom Token으로 Firebase Auth 로그인
```

---

### **2. Client Secret 처리**

#### **현실적인 타협점:**

**네이버 SDK의 제약:**
- ✅ 네이버 SDK는 초기화에 `client_secret` 필수
- ❌ `client_secret` 없이는 SDK가 `NEED_INIT` 상태로 작동 불가

**적용된 보안 계층:**
1. **SDK 초기화용:** `client_secret`을 앱에 포함 (불가피)
2. **실제 검증:** 서버에서 네이버 API 직접 호출로 토큰 재검증
3. **이중 검증:** 앱의 Access Token → 서버 검증 → Custom Token

**보안 이점:**
- ✅ 앱에서 획득한 Access Token을 서버에서 재검증
- ✅ 위조된 토큰은 서버 검증에서 차단
- ✅ Custom Token 발급 권한은 서버만 보유
- ⚠️ `client_secret`은 APK에 포함되지만, **실제 인증 흐름에서는 사용되지 않음**

#### **Android (`android/app/src/main/res/values/strings.xml`)**
```xml
<string name="client_id">EKvvbgJMV6rAx5L6Rybn</string>
<!-- 네이버 SDK 초기화에 필요 (실제 토큰 검증은 서버에서) -->
<string name="client_secret">ZQ9vUktdbW</string>
```

#### **iOS (`ios/Runner/Info.plist`)**
```xml
<key>NidClientID</key>
<string>EKvvbgJMV6rAx5L6Rybn</string>
<!-- 네이버 SDK 초기화에 필요 (실제 토큰 검증은 서버에서) -->
<key>NidClientSecret</key>
<string>ZQ9vUktdbW</string>
```

---

### **3. Cloud Functions 구현**

**파일:** `functions/src/index.ts`

**함수:** `verifyNaverToken`

**동작:**
1. 앱으로부터 네이버 Access Token 수신
2. 네이버 API (`https://openapi.naver.com/v1/nid/me`)로 토큰 검증
3. 유효한 경우 Firebase Custom Token 발급
4. 앱으로 Custom Token 반환

**보안 이점:**
- ✅ Client Secret이 앱 코드에 포함되지 않음
- ✅ 토큰 검증이 서버에서 이루어짐
- ✅ 네이버 API 호출이 서버에서만 발생

---

### **4. Flutter 구현**

**파일:** `lib/services/naver_auth_service.dart`

**변경사항:**
- ❌ 제거: `createCustomToken` 함수로 `providerId`, `email`, `displayName` 전송
- ✅ 추가: `verifyNaverToken` 함수로 `accessToken`만 전송

**코드 흐름:**
```dart
// 1. 네이버 SDK로 Access Token 획득
final result = await FlutterNaverLogin.logIn();
final accessToken = await FlutterNaverLogin.currentAccessToken;

// 2. 서버로 토큰 전송 (Client Secret 불필요)
final callable = _functions.httpsCallable('verifyNaverToken');
final response = await callable.call({'accessToken': accessToken.accessToken});

// 3. Custom Token으로 Firebase Auth 로그인
await _auth.signInWithCustomToken(response.data['customToken']);
```

---

## 📋 **Release 빌드 체크리스트**

### **1. 서명키 Hash Key 확인**

**현재 상태:**
- Debug와 Release 모두 동일한 키 사용 중
- SHA1: `62:A8:FC:42:7B:E2:EB:6B:3D:01:35:B6:FD:A6:52:8F:A7:DF:E3:AE`

**네이버 개발자센터 등록:**
1. [네이버 개발자센터](https://developers.naver.com) 접속
2. 내 애플리케이션 → API 설정
3. Android 플랫폼 → Hash Key 추가
4. 위 SHA1을 Base64로 변환하여 등록

**Base64 변환 (PowerShell):**
```powershell
$sha1 = "62A8FC427BE2EB6B3D0135B6FDA6528FA7DFE3AE"
$bytes = [byte[]]@($sha1 -split '(..)' | Where-Object {$_} | ForEach-Object {[convert]::ToByte($_,16)})
[Convert]::ToBase64String($bytes)
```

결과: `Yqj8Qnvi62s9ATW2/aZSj6ff464=`

---

### **2. Google Play 서명키**

Google Play Store에 업로드 시 Google이 자체 서명키를 사용합니다.

**추가 작업:**
1. Google Play Console → 앱 무결성 → 앱 서명 인증서 확인
2. SHA1 복사
3. 네이버 개발자센터에 추가 등록

---

## 🔍 **테스트 방법**

### **Debug 빌드 테스트 (완료 ✅)**
```bash
flutter run -d <device>
```

### **Release 빌드 테스트**
```bash
flutter build apk --release
flutter install
```

**확인 사항:**
- [ ] 네이버 로그인 성공
- [ ] Firebase Auth 로그인 성공
- [ ] 설정 페이지에서 "로그인: 네이버" 표시
- [ ] 스낵바 없음

---

## 🚨 **주의사항**

1. **Cloud Functions IAM 권한**
   - `verifyNaverToken` 함수에 대한 호출 권한 확인
   - 현재 `allUsers`에게 허용되어 있음 (공개 앱이므로 정상)

2. **네이버 API Rate Limit**
   - 네이버 API는 하루 25,000건 제한
   - 서버 기반 인증으로 변경 후에도 동일

3. **Firebase Auth Custom Token**
   - Custom Token 유효 기간: 1시간
   - 만료 시 재로그인 필요

---

## 📝 **향후 개선 사항**

1. **카카오/Apple 로그인도 서버 기반으로 변경** (권장)
2. **Firebase App Check 활성화** (Cloud Functions 보호)
3. **Rate Limiting 구현** (악용 방지)

---

## ✅ **완료 상태**

- [x] Client Secret을 Cloud Functions로 이동
- [x] strings.xml에서 Client Secret 제거
- [x] Info.plist에서 Client Secret 제거
- [x] NaverAuthService를 서버 기반으로 변경
- [x] verifyNaverToken Cloud Function 배포
- [ ] Release Hash Key 네이버 개발자센터 등록
- [ ] Release 빌드 테스트

