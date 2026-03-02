import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
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

    // Rive 초기화
    // iOS에서 rive 0.13.18+ 의 FFI init 심볼 에러 우회 (rive_text_ffi crash)
    // RiveFile.import()는 정상 동작하므로 애니메이션 재생에는 영향 없음
    if (!kIsWeb && !Platform.isIOS) {
      await RiveFile.initialize();
    }

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
  }
}
