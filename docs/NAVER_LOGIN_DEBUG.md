# 네이버 로그인 디버깅 가이드

## 🔑 **현재 앱 서명 정보**

### **Debug Keystore**
- **경로**: `C:\Users\douglas\.android\debug.keystore`
- **Alias**: `AndroidDebugKey`
- **MD5**: `C7:68:B9:28:94:01:46:91:CF:E6:56:2F:C4:04:7E:C6`
- **SHA1**: `62:A8:FC:42:7B:E2:EB:6B:3D:01:35:B6:FD:A6:52:8F:A7:DF:E3:AE`
- **SHA-256**: `00:E9:BE:86:A1:C6:3A:0A:B1:41:88:B1:5D:6C:B3:1C:09:83:A0:1E:09:E8:07:DA:AD:C7:2F:D9:66:31:A0:58`

---

## ✅ **네이버 개발자 콘솔 설정 체크리스트**

### **1. 네이버 개발자 센터 접속**
https://developers.naver.com/apps/#/myapps

### **2. Android 환경 설정 확인**

#### ✅ **패키지명**
```
com.chikabooks.tenth
```
**⚠️ 주의**: 대소문자, 점(.) 위치까지 정확히 일치해야 합니다!

#### ✅ **Hash Key (MD5)**

네이버가 요구하는 형식은 **콜론(:) 없는 MD5**입니다:

```
C768B9289401469 1CFE6562FC4047EC6
```

**또는 콜론 포함:**
```
C7:68:B9:28:94:01:46:91:CF:E6:56:2F:C4:04:7E:C6
```

**⚠️ 둘 다 시도해보세요!**

---

### **3. 네이버 로그인 API 활성화 확인**

1. **내 애플리케이션** 선택
2. **API 설정** 탭
3. **사용 API** 섹션에서:
   - ✅ **네아로(네이버 아이디로 로그인)** 체크
   - 상태: **사용 중**

---

### **4. 서비스 환경 확인**

**로그인 오픈 API 서비스 환경 → Android**

- **패키지명**: `com.chikabooks.tenth`
- **Hash Key**: 위에서 확인한 MD5 값
- **상태**: **등록됨**

---

## 🔧 **AndroidManifest.xml 재검증**

### **현재 설정:**

```xml
<!-- 네이버 로그인 클라이언트 ID/Secret (local.properties에서 주입됨) -->
<meta-data
    android:name="com.naver.nid.client_id"
    android:value="${naverClientId}"/>
<meta-data
    android:name="com.naver.nid.client_secret"
    android:value="${naverClientSecret}"/>
<meta-data
    android:name="com.naver.nid.client_name"
    android:value="@string/app_name"/>
```

### **플러그인 공식 문서 비교:**

`flutter_naver_login` 패키지는 **meta-data만 필요**하고, 별도의 Activity나 intent-filter는 필요하지 않습니다.

---

## 📱 **iOS 설정 (참고)**

`ios/Runner/Info.plist`에 이미 설정되어 있음:

```xml
<!-- 네이버 로그인 Consumer Key/Secret -->
<key>NaverConsumerKey</key>
<string>EKvvbgJMV6rAx5L6Rybn</string>
<key>NaverConsumerSecret</key>
<string>ZQ9vUktdbW</string>
<key>NaverServiceAppName</key>
<string>치과책방</string>
<key>NaverServiceUrlScheme</key>
<string>com.chikabooks.tenth</string>

<!-- URL Scheme -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.chikabooks.tenth</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.chikabooks.tenth</string>
        </array>
    </dict>
</array>
```

---

## 🔐 **Client Secret 보안 처리**

### **현재 상태:**
✅ **Android**: `local.properties`에서 주입 (안전, `.gitignore`에 포함)
✅ **iOS**: `Info.plist`에 하드코딩 (⚠️ Git에 포함됨)

### **권장 사항:**
네이버 로그인은 클라이언트 측에서 Client ID/Secret을 사용하는 방식이므로, 현재 구조는 플러그인의 표준 방식입니다.

**더 안전한 방식 (선택사항):**
- Cloud Functions에서 Custom Token 발급 시 네이버 API 검증 추가
- 클라이언트는 네이버 access token만 전달
- 서버에서 네이버 API로 사용자 정보 재검증

---

## 🧪 **테스트 순서:**

1. ✅ 네이버 개발자 콘솔에서 **Android 환경 Hash Key 등록**
2. ✅ 앱 재빌드: `flutter run -d R5CT339PHAA`
3. ✅ 네이버 로그인 시도
4. ✅ 터미널 로그 확인

---

## 📝 **예상되는 로그 (성공 시):**

```
I/flutter: 🔑 네이버 로그인 시작
I/flutter: 🧩 result.status: NaverLoginStatus.loggedIn
I/flutter: 🧩 result.account: NaverAccountResult(...)
I/flutter: 네이버 사용자 정보: ID=xxx, email=xxx, name=xxx
I/flutter: ✅ Firebase Auth 로그인 완료
```

---

## ❌ **현재 에러 (Hash Key 불일치):**

```
I/flutter: 🧩 result.status: NaverLoginStatus.error
I/flutter: 🧩 result.account: null
```

**원인**: 네이버 개발자 콘솔에 등록된 Hash Key와 실제 앱의 서명이 일치하지 않음

---

## 🚀 **다음 단계:**

1. 위의 MD5 Hash Key를 네이버 개발자 콘솔에 등록
2. 앱 재빌드 및 테스트
3. 여전히 에러 발생 시 로그 전체 공유


