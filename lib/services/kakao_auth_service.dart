import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

/// 카카오 로그인 서비스
/// Custom Token 방식으로 Firebase Auth 연동
class KakaoAuthService {
  static final _functions = FirebaseFunctions.instance;
  static final _auth = FirebaseAuth.instance;

  /// 카카오 로그인 실행
  static Future<User?> signInWithKakao() async {
    try {
      // 1. 카카오 로그인 (SDK)
      kakao.OAuthToken token;
      if (await kakao.isKakaoTalkInstalled()) {
        // 카카오톡으로 로그인
        try {
          token = await kakao.UserApi.instance.loginWithKakaoTalk();
        } catch (e) {
          debugPrint('카카오톡 로그인 실패, 카카오계정으로 시도: $e');
          // 카카오톡 실패 시 웹 브라우저로 로그인
          token = await kakao.UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        // 카카오톡 미설치 시 웹 브라우저로 로그인
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      // 2. 카카오 사용자 정보 가져오기
      final kakao.User user = await kakao.UserApi.instance.me();
      final String providerId = user.id.toString();
      final String? email = user.kakaoAccount?.email;
      final String? displayName = user.kakaoAccount?.profile?.nickname;

      debugPrint('✅ 카카오 로그인 성공: $providerId ($email)');

      // 3. Firebase Custom Token 발급 요청
      final result = await _functions.httpsCallable('createCustomToken').call({
        'provider': 'kakao',
        'providerId': providerId,
        'email': email,
        'displayName': displayName,
      });

      final String customToken = result.data['customToken'];

      // 4. Firebase Auth에 Custom Token으로 로그인
      final credential = await _auth.signInWithCustomToken(customToken);

      debugPrint('✅ Firebase 로그인 완료: ${credential.user?.uid}');

      return credential.user;
    } catch (e) {
      debugPrint('⚠️ 카카오 로그인 실패: $e');
      return null;
    }
  }

  /// 카카오 로그아웃
  static Future<void> signOut() async {
    try {
      await kakao.UserApi.instance.logout();
      await _auth.signOut();
      debugPrint('✅ 카카오 로그아웃 완료');
    } catch (e) {
      debugPrint('⚠️ 카카오 로그아웃 실패: $e');
    }
  }

  /// 카카오 연결 해제 (회원 탈퇴)
  static Future<void> unlink() async {
    try {
      await kakao.UserApi.instance.unlink();
      await _auth.currentUser?.delete();
      debugPrint('✅ 카카오 연결 해제 완료');
    } catch (e) {
      debugPrint('⚠️ 카카오 연결 해제 실패: $e');
    }
  }
}

