import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 네이버 로그인 서비스
/// Custom Token 방식으로 Firebase Auth 연동
/// 
/// ⚠️ 주의: 네이버 로그인은 flutter_naver_login 패키지 설치 후
/// 네이버 개발자 콘솔에서 Client ID/Secret을 발급받아야 합니다.
/// 현재는 기본 구조만 작성되어 있으며, 실제 테스트 시 수정이 필요합니다.
class NaverAuthService {
  static final _functions = FirebaseFunctions.instance;
  static final _auth = FirebaseAuth.instance;

  /// 네이버 로그인 실행
  /// 
  /// TODO: flutter_naver_login 패키지의 정확한 API를 확인하여 구현 필요
  /// 네이버 개발자 센터 설정:
  /// 1. https://developers.naver.com/
  /// 2. 애플리케이션 등록 → Client ID/Secret 발급
  /// 3. Android/iOS 환경 추가 (패키지명: com.chikabooks.tenth)
  static Future<User?> signInWithNaver() async {
    try {
      debugPrint('⚠️ 네이버 로그인은 아직 구현 중입니다');
      debugPrint('네이버 개발자 콘솔에서 Client ID/Secret 발급 후');
      debugPrint('flutter_naver_login 패키지 설정 가이드에 따라 구현하세요');
      
      // 임시로 null 반환 (실제 구현 시 제거)
      return null;
      
      /* 실제 구현 예시 (flutter_naver_login 패키지 설치 후):
      
      // 1. 네이버 로그인
      await FlutterNaverLogin.logIn();
      
      // 2. 사용자 정보 가져오기
      final account = await FlutterNaverLogin.currentUser();
      final providerId = account?.id;
      final email = account?.email;
      final displayName = account?.name;

      if (providerId == null) return null;

      // 3. Firebase Custom Token 발급
      final result = await _functions.httpsCallable('createCustomToken').call({
        'provider': 'naver',
        'providerId': providerId,
        'email': email,
        'displayName': displayName,
      });

      final customToken = result.data['customToken'];

      // 4. Firebase Auth 로그인
      final credential = await _auth.signInWithCustomToken(customToken);
      return credential.user;
      */
    } catch (e) {
      debugPrint('⚠️ 네이버 로그인 실패: $e');
      return null;
    }
  }

  /// 네이버 로그아웃
  static Future<void> signOut() async {
    try {
      // await FlutterNaverLogin.logOut();
      await _auth.signOut();
      debugPrint('✅ 네이버 로그아웃 완료');
    } catch (e) {
      debugPrint('⚠️ 네이버 로그아웃 실패: $e');
    }
  }

  /// 네이버 연결 해제 (회원 탈퇴)
  static Future<void> unlink() async {
    try {
      // await FlutterNaverLogin.logOutAndDeleteToken();
      await _auth.currentUser?.delete();
      debugPrint('✅ 네이버 연결 해제 완료');
    } catch (e) {
      debugPrint('⚠️ 네이버 연결 해제 실패: $e');
    }
  }
}

