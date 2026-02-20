# 카카오 로그인 보안 및 구현 상세

이 문서는 카카오 로그인 구현 시 서버 기반 토큰 검증 및 전반적인 보안 구조에 대한 상세 내용을 다룹니다.

## 1. 서버 기반 Access Token 검증 (핵심 보안 강화)

카카오 로그인 과정에서 획득한 Access Token은 앱에서 직접 검증하지 않고, Cloud Functions (`verifyKakaoToken`)를 통해 서버에서 검증합니다.

**흐름:**
1. **[앱] 카카오 SDK 로그인:** `UserApi.instance.loginWithKakaoTalk()` 또는 `loginWithKakaoAccount()`를 통해 카카오 로그인 진행.
2. **[앱] Access Token 획득:** 로그인 후 `OAuthToken.accessToken`을 획득합니다.
3. **[앱] → [Cloud Functions] Access Token 전송:** 획득한 Access Token을 `verifyKakaoToken` Cloud Function으로 전송합니다.
4. **[Cloud Functions] → [카카오 API] 토큰 재검증:** `verifyKakaoToken` 함수는 서버 환경에서 카카오 API(`https://kapi.kakao.com/v2/user/me`)를 호출하여 Access Token의 유효성을 검증하고, 사용자 정보를 가져옵니다.
5. **[Cloud Functions] → [앱] Firebase Custom Token 발급:** 검증이 성공하면, 함수는 Firebase Custom Token을 발급하고 앱으로 반환합니다.
6. **[앱] Firebase Auth 로그인:** 앱은 이 Custom Token을 사용하여 Firebase Authentication에 로그인합니다.

**보안 이점:**
- **위조된 Access Token 차단:** 앱에서 위조된 Access Token을 보내더라도, 서버에서 카카오 API를 통해 재검증하므로 무효화됩니다.
- **Custom Token 발급 권한 제한:** Firebase Custom Token 발급은 신뢰할 수 있는 서버(Cloud Functions)에서만 가능합니다.
- **클라이언트 코드 노출 방지:** 앱에서는 카카오 SDK를 통해 얻은 토큰을 서버로 전달하기만 하므로, 민감한 로직이 클라이언트에 노출되지 않습니다.

## 2. Android Release 빌드 KeyHash 등록

- **현재 상태:** `build.gradle.kts` 설정에 따라 Debug와 Release 빌드가 동일한 `debug.keystore`를 사용하고 있습니다.
- **KeyHash:** `62:A8:FC:42:7B:E2:EB:6B:3D:01:35:B6:FD:A6:52:8F:A7:DF:E3:AE` (Base64: `Yqj8Qnvi62s9ATW2/aZSj6ff464=`)
- **조치:** 이 KeyHash는 카카오 개발자센터에 이미 등록되어 있어야 합니다. 만약 Google Play Store에 앱을 업로드할 경우, Google Play App Signing에 의해 새로운 서명키가 생성될 수 있으므로, **Google Play Console에서 제공하는 App Signing Key의 SHA1 Hash Key를 추가로 등록**해야 합니다.

## 3. iOS URL Scheme 등록

- `Info.plist`에 카카오 URL Scheme (`kakao683c7dcddbf93a77a45f0e1fe771c0ce`)이 올바르게 설정되어 있습니다.
- `LSApplicationQueriesSchemes`에 `kakaokompassauth`, `storykompassauth`, `kakaolink`가 추가되어 있어 카카오톡 앱 호출이 가능합니다.

## 4. Cloud Functions 구조

### verifyKakaoToken 함수

```typescript
export const verifyKakaoToken = functions.https.onCall(
  async (data, context) => {
    const {accessToken} = data;

    if (!accessToken) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "accessToken은 필수입니다."
      );
    }

    try {
      // 1. 카카오 API로 사용자 정보 조회 (서버에서 토큰 검증)
      const response = await axios.get(
        "https://kapi.kakao.com/v2/user/me",
        {
          headers: {
            Authorization: `Bearer ${accessToken}`,
          },
        }
      );

      const kakaoUser = response.data;

      if (!kakaoUser.id) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "카카오 토큰 검증 실패"
        );
      }

      const providerId = kakaoUser.id.toString();
      const email = kakaoUser.kakao_account?.email || null;
      const displayName = kakaoUser.kakao_account?.profile?.nickname || null;

      // 2. Firebase UID 생성
      const uid = `kakao_${providerId}`;

      // 3. Firebase Auth 사용자 생성/업데이트
      // ...

      // 4. Custom Token 발급
      const customToken = await admin.auth().createCustomToken(uid);

      return {
        success: true,
        customToken,
        uid,
      };
    } catch (error: any) {
      console.error("⚠️ verifyKakaoToken error:", error);
      throw new functions.https.HttpsError(
        "internal",
        `카카오 로그인 실패: ${error.message || error}`
      );
    }
  }
);
```

## 5. Flutter 앱 구조

### KakaoAuthService

```dart
class KakaoAuthService {
  static final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  static final _auth = FirebaseAuth.instance;

  static Future<User?> signInWithKakao() async {
    try {
      // 1. 카카오 SDK로 로그인
      final token = await UserApi.instance.loginWithKakaoTalk();

      // 2. 서버로 Access Token 전송하여 검증
      final callable = _functions.httpsCallable('verifyKakaoToken');
      final response = await callable.call({
        'accessToken': token.accessToken,
      });

      final String customToken = response.data['customToken'];

      // 3. Firebase Auth 로그인
      await _auth.signInWithCustomToken(customToken);
      
      // 4. 200ms 대기 (타이밍 이슈 해결)
      await Future.delayed(const Duration(milliseconds: 200));

      return _auth.currentUser;
    } catch (e) {
      debugPrint('❌ 카카오 로그인 실패: $e');
      return null;
    }
  }
}
```

## 결론

카카오 로그인은 **서버 기반 토큰 검증**을 통해 보안을 강화하였습니다. 앱에서는 카카오 SDK를 통해 얻은 Access Token을 Cloud Functions로 전달하고, 서버에서 카카오 API를 통해 토큰을 재검증한 후 Firebase Custom Token을 발급하는 다층 보안 구조로 구현되었습니다. Release 빌드 시 Google Play App Signing Key에 대한 KeyHash 등록만 추가로 확인하면 됩니다.

