# 소셜 로그인 설정 가이드

## 📝 개요
이 가이드는 치카북스 앱에 **Google, Apple, Kakao, Naver, Email/Password** 로그인을 설정하는 방법을 안내합니다.

---

## ✅ 1. Firebase Console 설정

### 1-1. Firebase 콘솔 접속
- https://console.firebase.google.com/
- 프로젝트 선택: `chikabooks3rd`

### 1-2. Authentication Provider 활성화
**좌측 메뉴 → Authentication → Sign-in method**

#### ✅ Google (이미 활성화됨)
- 상태: 사용 설정됨

#### ✅ Apple
1. "Apple" 클릭 → "사용 설정" 토글 ON
2. **iOS Bundle ID** 입력: `com.chikabooks.tenth`
3. (선택) Services ID, Team ID 등은 나중에 추가 가능
4. "저장" 클릭

#### ✅ 이메일/비밀번호
1. "이메일/비밀번호" 클릭 → "사용 설정" 토글 ON
2. "이메일 링크(비밀번호가 없는 로그인)" 체크 안 함 (선택)
3. "저장" 클릭

---

## 🍎 2. Apple 로그인 설정 (iOS)

### 2-1. Apple Developer Console
1. https://developer.apple.com/account/
2. **Certificates, Identifiers & Profiles** → **Identifiers**
3. 기존 App ID 선택 또는 새로 생성
   - Bundle ID: `com.chikabooks.tenth`
4. **Capabilities** 섹션에서:
   - ✅ **Sign In with Apple** 체크
5. "Save" 클릭

### 2-2. Xcode 설정
1. `ios/Runner.xcworkspace` 파일을 Xcode로 열기
2. 좌측 Navigator에서 "Runner" 프로젝트 선택
3. **Signing & Capabilities** 탭
4. **+ Capability** 버튼 클릭 → **Sign in with Apple** 추가
5. Team 선택 및 Bundle Identifier 확인: `com.chikabooks.tenth`

### 2-3. Info.plist (선택사항)
`ios/Runner/Info.plist`에 추가 (필요 시):
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.chikabooks.tenth</string>
        </array>
    </dict>
</array>
```

---

## 💬 3. 카카오 로그인 설정

### 3-1. 카카오 개발자 콘솔
1. https://developers.kakao.com/
2. 로그인 → **내 애플리케이션** 클릭
3. **앱 만들기** (또는 기존 앱 선택)

### 3-2. 네이티브 앱 키 발급
1. **앱 설정 → 요약 정보**
2. **네이티브 앱 키** 복사 (예: `a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p`)

### 3-3. Android 설정
1. **플랫폼 → Android 플랫폼 등록**
   - **패키지명**: `com.chikabooks.tenth`
   - **키 해시**: 디버그/릴리스 키 해시 등록
     ```bash
     # 디버그 키 해시 생성 (Windows)
     keytool -exportcert -alias androiddebugkey -keystore %USERPROFILE%\.android\debug.keystore | openssl sha1 -binary | openssl base64
     # 비밀번호: android
     ```
2. **활성화 설정 → 카카오 로그인** 활성화 ON

### 3-4. iOS 설정
1. **플랫폼 → iOS 플랫폼 등록**
   - **번들 ID**: `com.chikabooks.tenth`
2. **iOS 네이티브 앱 키** 복사

### 3-5. Redirect URI 설정
1. **제품 설정 → 카카오 로그인**
2. **Redirect URI** 추가:
   - Android: `kakao{NATIVE_APP_KEY}://oauth`
   - iOS: `kakao{NATIVE_APP_KEY}://oauth`

### 3-6. 코드에 키 입력

#### ✅ lib/core/config/app_initializer.dart
```dart
KakaoSdk.init(
  nativeAppKey: 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p', // 발급받은 네이티브 앱 키
);
```

#### ✅ android/app/src/main/AndroidManifest.xml
```xml
<!-- 카카오 네이티브 앱 키 -->
<meta-data
    android:name="com.kakao.sdk.AppKey"
    android:value="YOUR_KAKAO_NATIVE_APP_KEY"/>

<!-- 리다이렉트 활동 -->
<activity
    android:name="com.kakao.sdk.flutter.AuthCodeCustomTabsActivity"
    android:exported="true">
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        
        <!-- Redirect URI -->
        <data android:host="oauth"
              android:scheme="kakaoYOUR_KAKAO_NATIVE_APP_KEY" />
    </intent-filter>
</activity>
```

**⚠️ 주의:** `YOUR_KAKAO_NATIVE_APP_KEY`를 실제 발급받은 키로 교체하세요!

#### ✅ ios/Runner/Info.plist
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>kakaoYOUR_KAKAO_NATIVE_APP_KEY</string>
        </array>
    </dict>
</array>

<key>KAKAO_APP_KEY</key>
<string>YOUR_KAKAO_NATIVE_APP_KEY</string>

<key>LSApplicationQueriesSchemes</key>
<array>
    <string>kakaokompassauth</string>
    <string>kakaolink</string>
    <string>kakaoplus</string>
</array>
```

---

## 🟢 4. 네이버 로그인 설정

### 4-1. 네이버 개발자 센터
1. https://developers.naver.com/
2. 로그인 → **Application → 애플리케이션 등록**

### 4-2. 애플리케이션 등록
1. **애플리케이션 이름**: 치카북스
2. **사용 API**: "네아로(네이버 아이디로 로그인)" 선택
3. **제공 정보**: 이메일, 닉네임, 프로필 이미지 선택
4. **환경 추가**:
   - ✅ **Android**: 패키지명 `com.chikabooks.tenth`
   - ✅ **iOS**: URL Scheme `com.chikabooks.tenth`

### 4-3. Client ID / Client Secret 복사
- **Client ID**: 예) `ljqo60a7xp`
- **Client Secret**: 예) `AbCdEfGhIj`

### 4-4. 코드에 키 입력

#### ✅ android/local.properties (보안 저장)
```properties
NAVER_CLIENT_ID=ljqo60a7xp
NAVER_CLIENT_SECRET=AbCdEfGhIj
```

#### ✅ iOS 설정
`ios/Runner/Info.plist`:
```xml
<key>NAVER_CLIENT_ID</key>
<string>ljqo60a7xp</string>

<key>NAVER_CLIENT_SECRET</key>
<string>AbCdEfGhIj</string>

<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>naverljqo60a7xp</string> <!-- naver{CLIENT_ID} -->
        </array>
    </dict>
</array>

<key>LSApplicationQueriesSchemes</key>
<array>
    <string>naversearchapp</string>
    <string>naversearchthirdlogin</string>
</array>
```

---

## 🔐 5. API 키 보안 관리

### 5-1. android/local.properties
```properties
# Google Maps API Key
MAPS_API_KEY=AIzaSyDOR--KBXRDGoCC4ifxJRhIOT4aqIYuZ30

# 카카오 (선택사항, AndroidManifest에 직접 입력 가능)
KAKAO_NATIVE_APP_KEY=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p

# 네이버
NAVER_CLIENT_ID=ljqo60a7xp
NAVER_CLIENT_SECRET=AbCdEfGhIj
```

### 5-2. .gitignore 확인
`local.properties`가 `.gitignore`에 포함되어 있는지 확인:
```
# android/local.properties
**/android/local.properties
```

---

## 📱 6. Cloud Functions 배포

### 6-1. createCustomToken 함수 배포
```bash
cd functions
npm install
firebase deploy --only functions:createCustomToken
```

### 6-2. 배포 확인
Firebase Console → Functions → `createCustomToken` 함수 확인

---

## ▶️ 7. 테스트 실행

### 7-1. 패키지 설치
```bash
flutter pub get
```

### 7-2. Android 빌드 & 실행
```bash
flutter run
```

### 7-3. iOS 빌드 & 실행
```bash
cd ios
pod install
cd ..
flutter run
```

---

## 🐛 8. 문제 해결

### ❌ 카카오: KOE006 (Redirect URI 오류)
- **원인**: Redirect URI가 카카오 콘솔에 등록되지 않음
- **해결**: `kakao{NATIVE_APP_KEY}://oauth` 정확히 등록

### ❌ 네이버: 401 Unauthorized
- **원인**: Client ID/Secret 불일치 또는 패키지명 불일치
- **해결**: 네이버 개발자 센터에서 패키지명 재확인

### ❌ Apple: Invalid Client
- **원인**: Bundle ID 불일치 또는 Sign in with Apple Capability 미활성화
- **해결**: Xcode에서 Capability 추가 후 재빌드

### ❌ Firebase: Custom Token 실패
- **원인**: Cloud Function이 배포되지 않음
- **해결**: `firebase deploy --only functions:createCustomToken` 실행

---

## 📚 참고 문서

- 카카오: https://developers.kakao.com/docs/latest/ko/kakaologin/flutter
- 네이버: https://developers.naver.com/docs/login/api/
- Apple: https://developer.apple.com/sign-in-with-apple/
- Firebase: https://firebase.google.com/docs/auth

---

## ✅ 최종 체크리스트

- [ ] Firebase Console에서 Google/Apple/Email Provider 활성화
- [ ] 카카오 개발자 콘솔에서 앱 등록 및 네이티브 앱 키 발급
- [ ] 네이버 개발자 센터에서 앱 등록 및 Client ID/Secret 발급
- [ ] `lib/core/config/app_initializer.dart`에 카카오 키 입력
- [ ] `android/app/src/main/AndroidManifest.xml`에 카카오 설정 추가
- [ ] `android/local.properties`에 API 키 저장
- [ ] iOS Xcode에서 Sign in with Apple Capability 추가
- [ ] `ios/Runner/Info.plist`에 카카오/네이버 URL Scheme 추가
- [ ] Cloud Functions `createCustomToken` 배포
- [ ] `flutter pub get` 실행
- [ ] Android/iOS 각각 테스트

---

**문제가 발생하면 위 "문제 해결" 섹션을 참고하세요!** 🚀

