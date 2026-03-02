import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

/// 카카오 로그인 서비스
/// 서버 기반 토큰 검증 방식으로 Firebase Auth 연동
class KakaoAuthService {
  static final _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );
  static final _auth = FirebaseAuth.instance;

  /// 카카오 로그인 실행 (서버 검증)
  static Future<User?> signInWithKakao() async {
    try {
      debugPrint('🔑 카카오 로그인 시작');

      // 🔐 디버그: 현재 앱의 키 해시 출력
      try {
        final keyHash = await kakao.KakaoSdk.origin;
        debugPrint('🔑 현재 앱의 Kakao KeyHash: $keyHash');
      } catch (e) {
        debugPrint('⚠️ KeyHash 확인 실패: $e');
      }

      // 1. 카카오 SDK로 로그인
      kakao.OAuthToken token;
      if (kIsWeb) {
        // 웹: 카카오톡 앱 로그인 불가 → 항상 카카오계정(브라우저) 로그인
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
      } else if (await kakao.isKakaoTalkInstalled()) {
        // 모바일: 카카오톡으로 로그인
        try {
          token = await kakao.UserApi.instance.loginWithKakaoTalk();
        } catch (e) {
          debugPrint('카카오톡 로그인 실패, 카카오계정으로 시도: $e');
          token = await kakao.UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        // 모바일: 카카오톡 미설치 시 카카오계정으로 로그인
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      debugPrint('✅ 카카오 SDK 로그인 성공');
      debugPrint('✅ Access Token: ${token.accessToken.substring(0, 20)}...');

      // 2. 서버로 Access Token 전송하여 검증 및 Custom Token 발급
      debugPrint('🔧 서버로 토큰 검증 요청...');
      final callable = _functions.httpsCallable('verifyKakaoToken');
      final response = await callable.call({'accessToken': token.accessToken});

      debugPrint('✅ 서버 검증 완료: ${response.data}');

      final String customToken = response.data['customToken'];

      // 3. Firebase Auth 로그인
      debugPrint('🔧 Firebase signInWithCustomToken 시작...');
      await _auth.signInWithCustomToken(customToken);

      debugPrint('✅ signInWithCustomToken 완료');

      // currentUser는 authStateChanges를 통해 비동기로 업데이트됨
      // 짧은 대기 후 재확인 (타이밍 이슈 해결)
      await Future.delayed(const Duration(milliseconds: 200));

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ Firebase Auth currentUser가 null (비정상)');
        return null;
      }

      debugPrint('✅✅✅ 카카오 로그인 완전 성공!');
      debugPrint('✅ UID: ${currentUser.uid}');
      debugPrint('✅ Email: ${currentUser.email}');

      return currentUser;
    } catch (e, stackTrace) {
      debugPrint('❌ 카카오 로그인 예외 발생');
      debugPrint('❌ Error: $e');
      debugPrint('❌ StackTrace: $stackTrace');
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
