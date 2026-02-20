import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';

/// 네이버 로그인 서비스 (서버 기반 인증)
/// Access Token을 서버로 전송하여 검증 및 Custom Token 발급
class NaverAuthService {
  static final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  static final _auth = FirebaseAuth.instance;

  /// 네이버 로그인 실행
  static Future<User?> signInWithNaver() async {
    try {
      debugPrint('🔑 네이버 로그인 시작');
      
      // 1. 네이버 SDK로 로그인
      final result = await FlutterNaverLogin.logIn();
      
      debugPrint('🧩 네이버 result.status: ${result.status}');
      
      // ✅ status 확인
      if (result.status != NaverLoginStatus.loggedIn) {
        debugPrint('❌ 네이버 로그인 실패: ${result.status}');
        return null;
      }
      
      // ✅ account 확인
      final account = result.account;
      if (account == null) {
        debugPrint('❌ 네이버 계정 정보가 없습니다');
        return null;
      }
      
    // 2. Access Token 가져오기 (getCurrentAccessToken 사용)
    debugPrint('🔧 Access Token 가져오는 중...');
    
    // ✅ flutter_naver_login 2.x: getCurrentAccessToken() 메서드 사용
    final tokenResult = await FlutterNaverLogin.getCurrentAccessToken();
    
    debugPrint('🧩 tokenResult: $tokenResult');
      
      if (tokenResult == null || tokenResult.accessToken.isEmpty) {
        debugPrint('❌ 네이버 Access Token이 없습니다');
        
        // 토큰이 없으면 로그아웃 후 재시도 권장
        await FlutterNaverLogin.logOut();
        return null;
      }
      
      debugPrint('✅ 네이버 Access Token 획득: ${tokenResult.accessToken.substring(0, 20)}...');

      // 3. 서버로 Access Token 전송하여 검증 및 Custom Token 발급
      debugPrint('🔧 서버로 토큰 검증 요청...');
      final callable = _functions.httpsCallable('verifyNaverToken');
      final response = await callable.call({
        'accessToken': tokenResult.accessToken,
      });

      debugPrint('✅ 서버 검증 완료: ${response.data}');

      final String customToken = response.data['customToken'];

      // 4. Firebase Auth 로그인
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
      
      debugPrint('✅✅✅ 네이버 로그인 완전 성공!');
      debugPrint('✅ UID: ${currentUser.uid}');
      debugPrint('✅ Email: ${currentUser.email}');
      
      return currentUser;
    } catch (e, stackTrace) {
      debugPrint('❌ 네이버 로그인 예외 발생');
      debugPrint('❌ Error: $e');
      debugPrint('❌ StackTrace: $stackTrace');
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
      await FlutterNaverLogin.logOut();
      await _auth.currentUser?.delete();
      debugPrint('✅ 네이버 연결 해제 완료');
    } catch (e) {
      debugPrint('⚠️ 네이버 연결 해제 실패: $e');
    }
  }
}
