# 카카오 로그인 키 해시 오류 해결 가이드

## 🔴 문제 증상
```
Android keyHash validation failed.
```

카카오 로그인 시 위 오류가 발생하면서 로그인이 실패합니다.

---

## 🔍 원인
카카오 개발자 콘솔에 등록된 **키 해시**와 실제 앱에서 사용하는 **서명 키의 해시값**이 다르기 때문입니다.

### 키 해시가 다른 이유:
1. **디버그 빌드 vs 릴리스 빌드**: 서로 다른 키스토어 사용
2. **로컬 개발 vs CI/CD**: 서명 키가 다를 수 있음
3. **여러 개발자**: 각자 다른 디버그 키스토어 사용

---

## 🔧 해결 방법

### 1단계: 실제 앱의 키 해시 확인

#### 방법 1: 앱 로그에서 확인 (가장 쉬움) ⭐

앱을 실행하고 카카오 로그인을 시도하면, 터미널/로그캣에서 다음과 같은 로그를 확인할 수 있습니다:

```
I/flutter: 🔑 현재 앱의 Kakao KeyHash: Aa1Bb2Cc3Dd4Ee5Ff6Gg7Hh8=
```

이 값을 복사하세요!

#### 방법 2: keytool로 직접 계산

##### 디버그 키 해시 (개발용)
```bash
# Windows (PowerShell)
keytool -exportcert -alias androiddebugkey -keystore C:\Users\[사용자명]\.android\debug.keystore | openssl sha1 -binary | openssl base64

# 비밀번호: android
```

##### 릴리스 키 해시 (배포용)
```bash
# Windows (PowerShell)
keytool -exportcert -alias [alias_name] -keystore [keystore_path] | openssl sha1 -binary | openssl base64

# 비밀번호: 실제 키스토어 비밀번호
```

---

### 2단계: 카카오 개발자 콘솔에 키 해시 등록

1. **카카오 개발자 콘솔 접속**
   - https://developers.kakao.com/

2. **내 애플리케이션 > 앱 선택**

3. **플랫폼 > Android > 키 해시 추가**
   - 1단계에서 확인한 키 해시를 입력
   - "추가" 버튼 클릭

4. **여러 키 해시 등록 가능**
   - 디버그 키 해시 (개발용)
   - 릴리스 키 해시 (배포용)
   - 팀원들의 키 해시 (여러 명이 개발 시)

---

### 3단계: 앱 재실행 및 확인

1. 앱을 완전히 종료 (백그라운드에서도 제거)
2. 앱 재실행
3. 카카오 로그인 시도

---

## 📱 프로젝트별 키 해시 관리

### Chikabooks 프로젝트

#### 현재 사용 중인 Native App Key
```
683c7dcddbf93a77a45f0e1fe771c0ce
```

#### 등록된 키 해시 목록 (카카오 콘솔에서 확인 필요)
- **개발용 (디버그)**: `[앱 실행 후 로그에서 확인]`
- **배포용 (릴리스)**: `[릴리스 키스토어로 계산 필요]`

---

## 🚨 주의사항

### 1. Play Console 자동 서명 사용 시
Google Play Console의 "앱 서명" 기능을 사용하면, **업로드 키**와 **앱 서명 키**가 다릅니다.

실제 배포된 앱은 Google이 자동으로 서명하므로, Play Console에서 **앱 서명 인증서(SHA-1)** 를 확인하여 키 해시를 계산해야 합니다.

```bash
# SHA-1을 Base64 키 해시로 변환
echo [SHA-1] | xxd -r -p | openssl base64
```

### 2. 여러 키 해시 등록 권장
- 개발 환경별로 다를 수 있으므로, 여러 키 해시를 등록하는 것이 안전합니다.
- 카카오는 최대 **10개**까지 등록 가능합니다.

### 3. 키 해시는 대소문자 구분
- 정확히 복사하여 입력하세요.
- 마지막 `=` 기호도 포함해야 합니다.

---

## 🧪 테스트 체크리스트

- [ ] 디버그 빌드에서 카카오 로그인 성공
- [ ] 릴리스 빌드에서 카카오 로그인 성공
- [ ] Play Store 배포 후 실제 앱에서 카카오 로그인 성공

---

## 📞 추가 지원

### 카카오 개발자 포럼
- https://devtalk.kakao.com/

### Firebase Custom Token 관련
- Firebase Auth와 연동하기 위해 Custom Token을 사용합니다.
- Cloud Functions의 `createCustomToken` 함수가 정상 배포되어 있어야 합니다.

```bash
# Cloud Functions 배포 확인
firebase functions:list
```

---

**마지막 업데이트**: 2026-02-21


