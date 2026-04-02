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
    }
  }
}
