import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';

/// 네이버 로그인 서비스
/// Custom Token 방식으로 Firebase Auth 연동
class NaverAuthService {
  static final _functions = FirebaseFunctions.instance;
  static final _auth = FirebaseAuth.instance;

  /// 네이버 로그인 실행
  static Future<User?> signInWithNaver() async {
    try {
      // 1. 네이버 로그인 (SDK)
      final NaverLoginResult result = await FlutterNaverLogin.logIn();

      if (result.status != NaverLoginStatus.loggedIn) {
        debugPrint('⚠️ 네이버 로그인 실패: ${result.status}');
        return null;
      }

      // 2. 네이버 사용자 정보 가져오기
      final NaverAccountResult account = await FlutterNaverLogin.currentAccount();
      final String? providerId = account.id;
      final String? email = account.email;
      final String? displayName = account.name;

      if (providerId == null) {
        debugPrint('⚠️ 네이버 사용자 ID를 가져올 수 없습니다');
        return null;
      }

      debugPrint('✅ 네이버 로그인 성공: $providerId ($email)');

      // 3. Firebase Custom Token 발급 요청
      final customTokenResult =
          await _functions.httpsCallable('createCustomToken').call({
        'provider': 'naver',
        'providerId': providerId,
        'email': email,
        'displayName': displayName,
      });

      final String customToken = customTokenResult.data['customToken'];

      // 4. Firebase Auth에 Custom Token으로 로그인
      final credential = await _auth.signInWithCustomToken(customToken);

      debugPrint('✅ Firebase 로그인 완료: ${credential.user?.uid}');

      return credential.user;
    } catch (e) {
      debugPrint('⚠️ 네이버 로그인 실패: $e');
      return null;
    }
  }

  /// 네이버 로그아웃
  static Future<void> signOut() async {
    try {
      await FlutterNaverLogin.logOut();
      await _auth.signOut();
      debugPrint('✅ 네이버 로그아웃 완료');
    } catch (e) {
      debugPrint('⚠️ 네이버 로그아웃 실패: $e');
    }
  }

  /// 네이버 연결 해제 (회원 탈퇴)
  static Future<void> unlink() async {
    try {
      await FlutterNaverLogin.logOutAndDeleteToken();
      await _auth.currentUser?.delete();
      debugPrint('✅ 네이버 연결 해제 완료');
    } catch (e) {
      debugPrint('⚠️ 네이버 연결 해제 실패: $e');
    }
  }
}

