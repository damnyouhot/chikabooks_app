# 카카오 로그인 최종 분석 (2026-02-21)

## 🎯 **현재 상황 (거의 성공!)**

### ✅ **성공한 부분**
1. 카카오 SDK 로그인: **성공** ✅
   ```
   I/flutter: 🔑 현재 앱의 Kakao KeyHash: Yqj8Qnvi62s9ATW2/aZSj6ff464=
   I/flutter: ✅ 카카오 SDK 로그인 성공: 4759907051 (null)
   ```

2. Custom Token 발급: **성공** ✅
   ```
   I/flutter: ✅ Custom Token 생성 성공: {uid: kakao_4759907051, success: true, customToken: eyJhbGci...}
   ```

3. Firebase Auth 로그인: **성공** ✅
   ```
   D/FirebaseAuth: Notifying id token listeners about user ( kakao_4759907051 ).
   D/FirebaseAuth: Notifying auth state listeners about user ( kakao_4759907051 ).
   ```

### ❌ **실패한 부분 (마지막 1%)**

```
I/flutter: ⚠️ 카카오 로그인 실패: type 'List<Object?>' is not a subtype of type 'PigeonUserDetails?' in type cast
```

**문제:**
- Firebase Auth는 성공적으로 로그인됨
- 하지만 Dart 코드에서 `credential.user`를 반환할 때 **type cast 에러** 발생
- 이는 `firebase_auth` Flutter 플러그인의 내부 serialization 문제

---

## 🔍 **에러 원인**

`firebase_auth` 패키지는 내부적으로 **Pigeon** (Flutter ↔ Native 통신 코드 생성기)을 사용합니다.

`signInWithCustomToken`의 반환값을 처리할 때:
1. Native Android에서 `UserCredential` 객체를 생성
2. Pigeon을 통해 Dart로 직렬화
3. **여기서 `PigeonUserDetails` 타입 변환 실패**

이는 `firebase_auth` 플러그인 자체의 버그이거나, Flutter/Firebase SDK 버전 불일치 때문입니다.

---

## ✅ **해결 방법 (2가지)**

### **방법 1: credential 대신 currentUser 직접 반환 (권장)**

`signInWithCustomToken` 후 `credential.user`를 반환하지 말고, `FirebaseAuth.instance.currentUser`를 반환:

```dart
// 4. Firebase Auth에 Custom Token으로 로그인
await _auth.signInWithCustomToken(customToken);

// credential.user를 사용하지 말고, currentUser를 직접 가져오기
final currentUser = _auth.currentUser;
if (currentUser == null) {
  debugPrint('❌ Firebase Auth currentUser가 null (비정상)');
  return null;
}

debugPrint('✅ Firebase Auth 로그인 완료: ${currentUser.uid}');
debugPrint('✅ Provider data: ${currentUser.providerData.map((e) => e.providerId).toList()}');

return currentUser;
```

### **방법 2: try-catch로 credential.user 에러 무시**

```dart
try {
  final credential = await _auth.signInWithCustomToken(customToken);
  return credential.user ?? _auth.currentUser;
} catch (e) {
  debugPrint('⚠️ credential.user 접근 실패, currentUser 사용: $e');
  return _auth.currentUser;
}
```

---

## 📝 **수정할 파일**

### **`lib/services/kakao_auth_service.dart`**

현재 코드 (line 94-111):

```dart
// 4. Firebase Auth에 Custom Token으로 로그인
final credential = await _auth.signInWithCustomToken(customToken);

// 🧩 디버그: signInWithCustomToken 결과 확인
debugPrint('🧩 signInWithCustomToken user = ${credential.user?.uid}');
debugPrint('🧩 signInWithCustomToken email = ${credential.user?.email}');
debugPrint('🧩 signInWithCustomToken providerData = ${credential.user?.providerData.map((e) => e.providerId).toList()}');

if (credential.user == null) {
  debugPrint('❌ signInWithCustomToken 성공했지만 user가 null');
  return null;
}

debugPrint('✅ Firebase Auth 로그인 완료: ${credential.user!.uid}');
debugPrint('✅ Provider data: ${credential.user!.providerData.map((e) => e.providerId).toList()}');

// ✅ 성공 기준: FirebaseAuth.currentUser가 실제로 존재해야 함
final currentUser = _auth.currentUser;
if (currentUser == null) {
  debugPrint('❌ Firebase Auth currentUser가 null (비정상)');
  return null;
}

debugPrint('🧩 최종 확인 - currentUser.uid = ${currentUser.uid}');
debugPrint('🧩 최종 확인 - currentUser.providerData = ${currentUser.providerData.map((e) => e.providerId).toList()}');

return currentUser;
```

**수정 후 (간단하게):**

```dart
// 4. Firebase Auth에 Custom Token으로 로그인
await _auth.signInWithCustomToken(customToken);

// ✅ credential.user 대신 currentUser 직접 사용 (Pigeon 에러 회피)
final currentUser = _auth.currentUser;
if (currentUser == null) {
  debugPrint('❌ Firebase Auth currentUser가 null (비정상)');
  return null;
}

debugPrint('✅ Firebase Auth 로그인 완료: ${currentUser.uid}');
debugPrint('✅ Provider data: ${currentUser.providerData.map((e) => e.providerId).toList()}');

return currentUser;
```

---

## 🎯 **예상 결과**

수정 후 카카오 로그인 시:

```
I/flutter: 🔑 카카오 로그인 시작
I/flutter: 🔑 현재 앱의 Kakao KeyHash: Yqj8Qnvi62s9ATW2/aZSj6ff464=
I/flutter: ✅ 카카오 SDK 로그인 성공: 4759907051 (null)
I/flutter: 🧩 createCustomToken response = {uid: kakao_4759907051, ...}
I/flutter: ✅ Custom Token 생성 성공: ...
I/flutter: ✅ Firebase Auth 로그인 완료: kakao_4759907051
I/flutter: ✅ Provider data: [firebase]
I/flutter: ✅ 카카오 로그인 성공: kakao_4759907051 (null)
```

**→ AuthGate가 자동으로 홈으로 이동**

**→ 설정 페이지에서 "로그인: 카카오" 표시 (Firestore 기반)**

---

## 📌 **설정 페이지에서 Provider 표시**

Firestore의 `users/kakao_4759907051` 문서:

```json
{
  "provider": "kakao",
  "providerId": "4759907051",
  "email": null,
  "displayName": null,
  "lastLoginAt": "2026-02-21T..."
}
```

설정 페이지의 `FutureBuilder`가 이 문서를 읽어서:
- `provider: 'kakao'` → "로그인: 카카오" ✅

---

## ✅ **다음 단계**

1. **Agent 모드에서 `kakao_auth_service.dart` 수정**
2. **앱 재빌드 및 테스트**
3. **설정 페이지에서 "로그인: 카카오" 확인**

---

## 🔧 **추가 개선 사항 (선택)**

### 1. **설정 페이지 디버그 로그 확인**

설정 페이지에 들어갈 때 터미널에서 아래 로그 확인:

```
I/flutter: 🧩 SETTINGS currentUser = kakao_4759907051
I/flutter: 🧩 SETTINGS email = null
I/flutter: 🧩 SETTINGS providerData = [firebase]
```

- `currentUser != null` → 로그인 성공
- `providerData = [firebase]` → Custom Token 로그인 특성 (정상)

### 2. **Firestore 읽기 확인**

`FutureBuilder`가 Firestore `users/kakao_4759907051` 문서를 성공적으로 읽으면:
- Loading indicator → Account card with "로그인: 카카오"

---

## 📊 **전체 흐름 요약**

```
1. 사용자: 카카오 로그인 버튼 클릭
   ↓
2. KakaoSDK: 카카오톡/카카오계정 인증
   ↓
3. KakaoAuthService: providerId, email, displayName 추출
   ↓
4. Cloud Functions: createCustomToken(provider='kakao', ...)
   ↓
5. Firestore: users/kakao_4759907051 문서 생성/업데이트
   ↓
6. Firebase Auth: signInWithCustomToken(customToken)
   ✅ 성공! (FirebaseAuth.currentUser = kakao_4759907051)
   ↓
7. ⚠️ credential.user 접근 시 Pigeon 에러
   → 해결: credential 대신 currentUser 직접 사용
   ↓
8. AuthGate: currentUser != null → 홈으로 이동
   ↓
9. SettingsPage: Firestore users/kakao_4759907051 읽기 → "로그인: 카카오" 표시
```

---

## 🎉 **거의 완료!**

마지막 1% (`credential.user` 타입 에러)만 수정하면 완벽하게 작동합니다!









