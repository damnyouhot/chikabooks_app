import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:rive/rive.dart';
import '../../firebase_options.dart';

/// 앱 초기화 (Firebase + Rive + Kakao)
class AppInitializer {
  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Rive 초기화
    await RiveFile.initialize();

    // 카카오 SDK 초기화 (네이티브 앱 키 필요)
    // TODO: 카카오 개발자 콘솔에서 네이티브 앱 키를 발급받아 여기에 입력하세요
    KakaoSdk.init(
      nativeAppKey: 'YOUR_KAKAO_NATIVE_APP_KEY',
      // javaScriptAppKey: 'YOUR_KAKAO_JAVASCRIPT_APP_KEY', // 웹용 (선택)
    );

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







