import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';

/// 네이버 로그인 서비스 (서버 기반 인증)
/// Access Token을 서버로 전송하여 검증 및 Custom Token 발급
class NaverAuthService {
  static final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  static final _auth = FirebaseAuth.instance;

  /// 네이버 로그인 실행
  ///
  /// 성공 시 `(User, nid/SDK에서 확보한 이메일)` — Auth에 이메일이 없어도 SDK에서 온 주소는 두 번째 값으로 전달( SignInTracker용 ).
  static Future<(User user, String? profileEmail)?> signInWithNaver() async {
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
      
      if (tokenResult.accessToken.isEmpty) {
        debugPrint('❌ 네이버 Access Token이 없습니다');
        
        // 토큰이 없으면 로그아웃 후 재시도 권장
        await FlutterNaverLogin.logOut();
        return null;
      }
      
      debugPrint('✅ 네이버 Access Token 획득: ${tokenResult.accessToken.substring(0, 20)}...');

      // 2b. 동일 세션에서 nid/me 를 한 번 더 호출해 이메일 누락 보완
      String? profileEmail = account.email?.trim();
      debugPrint('🧩 logIn account.email: ${account.email}');
      try {
        final acc2 = await FlutterNaverLogin.getCurrentAccount();
        debugPrint('🧩 getCurrentAccount.email: ${acc2.email}');
        final e2 = acc2.email?.trim();
        if (e2 != null && e2.isNotEmpty) {
          profileEmail = e2;
        }
      } catch (e) {
        debugPrint('⚠️ getCurrentAccount 실패(무시): $e');
      }

      // 2c. 토큰으로 직접 nid/me 호출 (SDK→Dart 맵에 email 이 비는 경우 대비)
      if (profileEmail == null || profileEmail.isEmpty) {
        try {
          final res = await http.get(
            Uri.parse('https://openapi.naver.com/v1/nid/me'),
            headers: {
              'Authorization': 'Bearer ${tokenResult.accessToken}',
            },
          );
          if (res.statusCode == 200) {
            final map = jsonDecode(res.body) as Map<String, dynamic>?;
            final resp = map?['response'] as Map<String, dynamic>?;
            final em = resp?['email'] as String?;
            if (em != null && em.trim().isNotEmpty) {
              profileEmail = em.trim();
              debugPrint('🧩 직접 nid/me email: $profileEmail');
            }
          }
        } catch (e) {
          debugPrint('⚠️ 직접 nid/me 조회 실패(무시): $e');
        }
      }

      // 3. 서버로 Access Token 전송하여 검증 및 Custom Token 발급
      debugPrint('🔧 서버로 토큰 검증 요청...');
      final callable = _functions.httpsCallable('verifyNaverToken');
      final response = await callable.call({
        'accessToken': tokenResult.accessToken,
        if (profileEmail != null && profileEmail.isNotEmpty)
          'profileEmail': profileEmail,
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
      debugPrint('✅ Auth.email: ${currentUser.email} / SDK profileEmail: $profileEmail');
      
      return (currentUser, profileEmail);
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
