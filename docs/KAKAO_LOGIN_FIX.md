# 카카오 로그인 수정 완료 (2026-02-21)

## 🐛 **발견된 문제**

### 1. **UX/상태관리 버그**
**증상:**
- 카카오 로그인 버튼 클릭 → "로그인 실패" 스낵바 표시 → 하지만 앱에는 진입함
- 설정 페이지에서 "로그인: 알 수 없음" 표시

**원인:**
```dart
// ❌ 이전 코드 (lib/pages/auth/sign_in_page.dart)
Future<void> _signInWithKakao() async {
  try {
    final user = await KakaoAuthService.signInWithKakao();
    if (user == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카카오 로그인 실패')),
      );
    } else {
      debugPrint('✅ 카카오 로그인 성공: ${user?.email}');
    }
  } catch (e) {
    // 에러 처리
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
  // ❌ 문제: user == null일 때도 return하지 않아서
  //    AuthGate가 작동하면 앱에 진입 가능
}
```

### 2. **성공 기준 불명확**
**문제:**
- `KakaoAuthService.signInWithKakao()`가 단순히 `credential.user`를 반환
- `FirebaseAuth.currentUser`가 실제로 설정되었는지 확인 안 함
- `providerData`가 비어있어 설정 페이지에서 provider를 인식 못함

---

## ✅ **적용된 수정사항**

### 1. **`lib/pages/auth/sign_in_page.dart`**

**변경 내용:**
- `user == null`일 때 **명시적으로 `return`** 추가
- 에러 발생 시에도 **`return`**으로 함수 종료
- 성공 시에만 로그 출력 및 AuthGate가 자동 처리하도록 변경

```dart
/// 카카오 로그인
Future<void> _signInWithKakao() async {
  setState(() => _isLoading = true);
  try {
    debugPrint('🔑 카카오 로그인 시작');
    final user = await KakaoAuthService.signInWithKakao();
    
    if (user == null) {
      // ✅ 실패 시 명시적으로 return (절대 홈으로 이동하지 않음)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카카오 로그인 실패. 다시 시도해주세요.')),
        );
      }
      return; // ← 여기서 종료!
    }
    
    // ✅ 성공 시에만 이 줄까지 도달
    debugPrint('✅ 카카오 로그인 성공: ${user.uid} (${user.email})');
    
    // AuthGate가 자동으로 홈으로 보내므로 추가 라우팅 불필요
    
  } catch (e) {
    debugPrint('❌ 카카오 로그인 에러: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카카오 로그인 오류: $e')),
      );
    }
    return; // ← 에러 시 종료!
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

### 2. **`lib/services/kakao_auth_service.dart`**

**변경 내용:**
- 각 단계별 상세한 디버그 로그 추가
- `credential.user`가 `null`인지 명시적 확인
- **`FirebaseAuth.currentUser`를 최종 확인하여 실제 로그인 상태 검증**
- `providerData` 출력으로 설정 페이지 디버깅 가능

```dart
/// 카카오 로그인 실행
static Future<User?> signInWithKakao() async {
  try {
    // 1. 카카오 SDK 로그인
    kakao.OAuthToken token;
    if (await kakao.isKakaoTalkInstalled()) {
      try {
        token = await kakao.UserApi.instance.loginWithKakaoTalk();
      } catch (e) {
        debugPrint('카카오톡 로그인 실패, 카카오계정으로 시도: $e');
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
      }
    } else {
      token = await kakao.UserApi.instance.loginWithKakaoAccount();
    }

    // 2. 카카오 사용자 정보 가져오기
    final kakao.User user = await kakao.UserApi.instance.me();
    final String providerId = user.id.toString();
    final String? email = user.kakaoAccount?.email;
    final String? displayName = user.kakaoAccount?.profile?.nickname;

    debugPrint('✅ 카카오 SDK 로그인 성공: $providerId ($email)');

    // 3. Firebase Custom Token 발급 요청
    final callable = _functions.httpsCallable('createCustomToken');
    final result = await callable.call({
      'provider': 'kakao',
      'providerId': providerId,
      'email': email,
      'displayName': displayName,
    });

    debugPrint('✅ Custom Token 생성 성공: ${result.data}');

    final String customToken = result.data['customToken'];

    // 4. Firebase Auth에 Custom Token으로 로그인
    final credential = await _auth.signInWithCustomToken(customToken);

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

    return currentUser;
  } catch (e) {
    debugPrint('⚠️ 카카오 로그인 실패: $e');
    return null;
  }
}
```

---

## 🧪 **테스트 시 확인할 로그**

카카오 로그인 버튼을 누른 후 아래 로그가 **순서대로** 나타나야 정상입니다:

```
I/flutter: 🔑 카카오 로그인 시작
I/flutter: 🔑 현재 앱의 Kakao KeyHash: Yqj8Qnvi62s9ATW2/aZSj6ff464=
I/flutter: ✅ 카카오 SDK 로그인 성공: 4759907051 (null)
I/flutter: ✅ Custom Token 생성 성공: {success: true, customToken: eyJh..., uid: kakao_4759907051}
I/flutter: ✅ Firebase Auth 로그인 완료: kakao_4759907051
I/flutter: ✅ Provider data: [firebase]
I/flutter: ✅ 카카오 로그인 성공: kakao_4759907051 (null)
```

### **예상되는 시나리오**

#### ✅ **성공 케이스**
1. 카카오톡/카카오계정 인증 완료
2. Custom Token 발급 성공
3. Firebase Auth 로그인 성공
4. `AuthGate`가 자동으로 홈 화면으로 이동
5. 설정 페이지에서 "로그인: 카카오" (또는 "로그인: 기타(firebase)") 표시

#### ❌ **실패 케이스 (올바른 동작)**
1. 카카오 로그인 중 에러 발생
2. "카카오 로그인 실패. 다시 시도해주세요." 스낵바 표시
3. **로그인 화면에 그대로 머물러 있음** (앱에 진입하지 않음)

---

## 🔧 **설정 페이지의 Provider 표시 로직**

```dart
// lib/pages/settings/settings_page.dart:34-52
String _providerLabel(User user) {
  final providers = user.providerData.map((e) => e.providerId).toSet();
  
  if (providers.contains('password')) return '이메일';
  if (providers.contains('google.com')) return 'Google';
  if (providers.contains('apple.com')) return 'Apple';
  
  if (providers.isNotEmpty) {
    final first = providers.first;
    if (first.contains('kakao')) return '카카오';
    if (first.contains('naver')) return '네이버';
    return '기타($first)';  // ← Custom Token 로그인은 보통 'firebase'로 표시됨
  }
  return '알 수 없음';  // ← providerData가 비어있을 때만 표시
}
```

**참고:**
- Custom Token으로 로그인하면 `providerData`에 `'firebase'`가 들어가는 경우가 많습니다.
- 이 경우 "로그인: 기타(firebase)"로 표시될 수 있습니다.
- 필요하다면 `_providerLabel` 함수에서 `uid`를 확인하여 `uid.startsWith('kakao_')`이면 "카카오"로 표시하도록 수정 가능합니다.

---

## 📝 **향후 개선 사항 (선택)**

### 1. **Provider 표시 개선**
`uid` 기반으로 정확한 provider 표시:

```dart
String _providerLabel(User user) {
  // UID로 먼저 확인
  if (user.uid.startsWith('kakao_')) return '카카오';
  if (user.uid.startsWith('naver_')) return '네이버';
  if (user.uid.startsWith('apple_')) return 'Apple';
  
  // 기존 providerData 확인 로직
  final providers = user.providerData.map((e) => e.providerId).toSet();
  if (providers.contains('password')) return '이메일';
  if (providers.contains('google.com')) return 'Google';
  if (providers.contains('apple.com')) return 'Apple';
  
  if (providers.isNotEmpty) return '기타(${providers.first})';
  return '알 수 없음';
}
```

### 2. **Firestore에 Provider 정보 저장**
Cloud Functions의 `createCustomToken`에서 이미 Firestore에 provider 정보를 저장하고 있으므로, 설정 페이지에서 Firestore를 읽어와서 정확한 provider를 표시할 수 있습니다.

---

## ✅ **수정 완료**

- [x] `sign_in_page.dart`: 실패 시 명시적 return 추가
- [x] `kakao_auth_service.dart`: 성공 기준 명확화 및 상세 로그 추가
- [x] 문서화 완료

**다음 단계:**
1. 앱 재빌드 및 실행
2. 카카오 로그인 테스트
3. 로그 확인하여 각 단계 성공 여부 검증
4. 설정 페이지에서 올바른 provider 표시 확인







