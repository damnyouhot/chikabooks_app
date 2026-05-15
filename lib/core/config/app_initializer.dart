import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:rive/rive.dart';
import '../../firebase_options.dart';

/// 앱 초기화 (Firebase + Rive + Kakao)
class AppInitializer {
  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 웹에서 # 없는 경로 URL 사용
    if (kIsWeb) usePathUrlStrategy();

    // 모바일: 세로 모드 고정 (가로 회전 방지)
    if (!kIsWeb) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    // Rive 초기화 (0.14.x: rive_native 기반, iOS FFI 문제 해결)
    await RiveNative.init();

    // 카카오 SDK 초기화
    // javaScriptAppKey: 카카오 콘솔 → 앱 키 → JavaScript 키
    KakaoSdk.init(
      nativeAppKey: '683c7dcddbf93a77a45f0e1fe771c0ce',
      javaScriptAppKey: '440fdf09100d899d4f274b5287d3c4c6',
    );

    // ✅ 네이버 SDK는 AndroidManifest.xml과 Info.plist 설정으로 자동 초기화됨
    // flutter_naver_login 패키지는 별도의 initSdk() 호출이 필요 없음
    debugPrint('✅ 네이버 SDK: AndroidManifest.xml/Info.plist 설정 기반 자동 초기화');

    // Firebase 초기화 (중복 에러 무시)
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') {
        rethrow;
      }
    }

    // 웹: 로그인 상태를 브라우저에 명시적으로 유지 (탭·주소 재입력 후에도 세션 복원)
    if (kIsWeb) {
      try {
        await FirebaseAuth.instance.setPersistence(Persistence.INDEXED_DB);
      } catch (e) {
        debugPrint('⚠️ FirebaseAuth.setPersistence: $e');
      }
      // ── [CHIKA_WEB_AUTO_LOGIN: BEGIN] ────────────────────────────
      // 임시 기능 — 개발 끝나면 이 줄과 아래 함수, 그리고
      // tools/build_web_hosting_with_auto_login.sh,
      // tools/chika_web_login.env.example, .gitignore 의
      // ".chika_web_login.env" 항목을 함께 제거하면 원복.
      // (검색 키워드: CHIKA_WEB_AUTO_LOGIN)
      await _maybeWebHostingAutoEmailSignIn();
      // ── [CHIKA_WEB_AUTO_LOGIN: END] ──────────────────────────────
    }
  }
}

// ── [CHIKA_WEB_AUTO_LOGIN: BEGIN] ──────────────────────────────────
// 아래 함수 전체는 임시 기능 (배포 웹에서 특정 계정 자동 로그인).
// 원복 시: 이 BEGIN ~ END 사이를 통째로 삭제하면 됨.
// (검색 키워드: CHIKA_WEB_AUTO_LOGIN)

/// 웹 전용: 빌드 시 `--dart-define` 으로만 활성화되는 이메일 자동 로그인.
///
/// - 로그인 UI·라우터는 건드리지 않음. 플래그가 꺼져 있으면 **완전 no-op**.
/// - `CHIKA_WEB_AUTO_LOGIN` 권장. 기존 `DEV_WEB_AUTO_SIGN_IN` 도 동일 동작으로 인식.
/// - **공개 호스팅에 define 을 넣어 배포하면** 번들에 자격 증명이 포함되므로
///   누구나 `main.dart.js` 등에서 추출할 수 있다. 내부·임시 스테이징용으로만 사용.
Future<void> _maybeWebHostingAutoEmailSignIn() async {
  if (!kIsWeb) return;

  const chikaOn =
      bool.fromEnvironment('CHIKA_WEB_AUTO_LOGIN', defaultValue: false);
  const legacyOn =
      bool.fromEnvironment('DEV_WEB_AUTO_SIGN_IN', defaultValue: false);
  if (!chikaOn && !legacyOn) return;

  // /login 페이지 노출/테스트 목적으로 부팅 시 자동 sign-in 만 임시로 끄고
  // 자격 증명은 그대로 번들에 둘 때 사용 (/login 의 1-click 입장 버튼은 살림).
  // 기본값 true → 다른 환경/CI 에서 변수를 안 줘도 기존 동작은 유지.
  const bootOn = bool.fromEnvironment(
    'CHIKA_WEB_AUTO_LOGIN_ON_BOOT',
    defaultValue: true,
  );
  if (!bootOn) {
    debugPrint(
      '웹 자동 로그인: ON_BOOT=false → 부팅 sign-in 스킵 (/login 노출 모드)',
    );
    return;
  }

  const chikaEmail =
      String.fromEnvironment('CHIKA_WEB_AUTO_EMAIL', defaultValue: '');
  const legacyEmail =
      String.fromEnvironment('DEV_WEB_AUTO_EMAIL', defaultValue: '');
  final trimmedEmail =
      (chikaEmail.trim().isNotEmpty ? chikaEmail : legacyEmail).trim();

  const chikaPw =
      String.fromEnvironment('CHIKA_WEB_AUTO_PASSWORD', defaultValue: '');
  const legacyPw =
      String.fromEnvironment('DEV_WEB_AUTO_PASSWORD', defaultValue: '');
  final password = chikaPw.isNotEmpty ? chikaPw : legacyPw;

  const replaceChika = bool.fromEnvironment(
    'CHIKA_WEB_AUTO_REPLACE_SESSION',
    defaultValue: false,
  );
  const replaceLegacy = bool.fromEnvironment(
    'DEV_WEB_AUTO_REPLACE_SESSION',
    defaultValue: false,
  );
  final replaceSession = chikaOn ? replaceChika : replaceLegacy;

  if (trimmedEmail.isEmpty || password.isEmpty) {
    debugPrint(
      '⚠️ 웹 자동 로그인: 플래그는 켜졌으나 이메일/비밀번호 define 이 비어 있음 — 스킵',
    );
    return;
  }

  final auth = FirebaseAuth.instance;
  final targetLower = trimmedEmail.toLowerCase();
  final current = auth.currentUser;

  if (current != null) {
    final same = current.email?.trim().toLowerCase() == targetLower;
    if (same) return;
    if (!replaceSession) {
      debugPrint(
        '웹 자동 로그인: 이미 다른 계정(${current.email}) — '
        '전환하려면 CHIKA_WEB_AUTO_REPLACE_SESSION=true '
        '(또는 DEV_WEB_AUTO_REPLACE_SESSION=true)',
      );
      return;
    }
    try {
      await auth.signOut();
    } catch (e) {
      debugPrint('⚠️ 웹 자동 로그인 signOut: $e');
      return;
    }
  }

  try {
    await auth.signInWithEmailAndPassword(
      email: trimmedEmail,
      password: password,
    );
    debugPrint('✅ 웹 자동 로그인: $targetLower');
  } on FirebaseAuthException catch (e) {
    debugPrint('⚠️ 웹 자동 로그인 FirebaseAuth: ${e.code}');
  } catch (e) {
    debugPrint('⚠️ 웹 자동 로그인: $e');
  }
}
// ── [CHIKA_WEB_AUTO_LOGIN: END] ────────────────────────────────────
