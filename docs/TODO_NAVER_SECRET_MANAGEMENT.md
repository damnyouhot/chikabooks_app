# TODO: 네이버 Client Secret 보안 관리

## 🔐 **현재 상태 (임시)**

네이버 SDK 초기화 시 Client Secret이 `lib/core/config/app_initializer.dart`에 하드코딩되어 있습니다:

```dart
await FlutterNaverLogin.initSdk(
  clientId: 'EKvvbgJMV6rAx5L6Rybn',
  clientSecret: 'ZQ9vUktdbW',  // ⚠️ 하드코딩됨
  clientName: '치과책방',
);
```

**⚠️ 주의**: 이 값이 Git에 커밋되어 공개 저장소에 노출될 수 있습니다.

---

## 📋 **릴리즈 전 검토 필요 사항**

### **옵션 1: 환경 변수 또는 플랫폼별 설정 파일 활용 (권장)**

#### **Android**
1. `android/local.properties`에 키 저장 (이미 사용 중)
2. Dart에서 `MethodChannel`로 네이티브에서 읽어오기
3. 또는 `--dart-define` 빌드 옵션 사용

#### **iOS**
1. `ios/Runner/Info.plist`에 키 저장 (이미 사용 중)
2. Dart에서 `MethodChannel`로 네이티브에서 읽어오기

#### **장점:**
- Git에 키가 노출되지 않음
- 플랫폼별로 다른 키 사용 가능

#### **단점:**
- 추가 코드 작성 필요 (MethodChannel 구현)
- 앱 디컴파일 시 여전히 노출 가능

---

### **옵션 2: 서버(Cloud Functions)에서 네이버 API 호출 (가장 안전)**

#### **Flow:**
1. 클라이언트: 네이버 로그인 → Access Token 획득
2. 클라이언트: Access Token을 Cloud Functions로 전달
3. Cloud Functions: 네이버 API로 사용자 정보 재검증 (Client Secret 사용)
4. Cloud Functions: Firebase Custom Token 발급
5. 클라이언트: Custom Token으로 Firebase Auth 로그인

#### **장점:**
- Client Secret이 서버에만 존재 (최고 보안)
- 네이버 사용자 정보 재검증 가능

#### **단점:**
- 서버 로직 추가 필요
- `flutter_naver_login` 패키지의 표준 사용 방식이 아님
- 추가 네트워크 요청 (약간의 지연)

---

### **옵션 3: 현재 상태 유지 (간편하지만 권장하지 않음)**

#### **근거:**
- 많은 네이버 로그인 앱들이 클라이언트에 Secret을 포함
- 네이버 OAuth는 Redirect URI, 패키지명 등으로 추가 검증
- 앱 디컴파일 난이도가 높음

#### **⚠️ 위험:**
- Git 공개 저장소에 올리면 즉시 노출
- 악의적 사용자가 앱을 디컴파일하면 Secret 추출 가능
- Secret 노출 시 네이버 개발자 콘솔에서 재발급 필요

---

## ✅ **권장 액션 플랜**

### **Phase 1: 개발/테스트 (현재)**
- ✅ 하드코딩으로 빠른 테스트 진행
- ✅ `.gitignore`에 민감 정보 파일 확인

### **Phase 2: 베타/프리릴리즈**
- [ ] `--dart-define`으로 빌드 시점에 주입
- [ ] 또는 `MethodChannel`로 네이티브 설정 파일에서 읽기
- [ ] Git에서 Secret 제거 (history 포함)

### **Phase 3: 프로덕션 (최종)**
- [ ] 서버 기반 네이버 API 검증 검토
- [ ] 또는 최소한 난독화 + ProGuard 적용 (Android)
- [ ] 정기적인 Secret 로테이션 정책 수립

---

## 📚 **참고 자료**

- [Flutter Environment Variables](https://docs.flutter.dev/deployment/flavors)
- [Platform Channels (MethodChannel)](https://docs.flutter.dev/platform-integration/platform-channels)
- [네이버 로그인 API 문서](https://developers.naver.com/docs/login/api/)

---

**담당자**: 개발팀
**우선순위**: Medium (릴리즈 전 필수)
**예상 소요 시간**: 2-4시간

