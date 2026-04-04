import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';

/// 네이버 로그인 서비스 (서버 기반 인증)
/// Access Token을 서버로 전송하여 검증 및 Custom Token 발급
///
/// ■ Scope / 이메일
/// - `flutter_naver_login` 은 Dart 에서 OAuth scope 문자열을 넘기지 않습니다.
///   Android/iOS 는 NaverIdLoginSDK.authenticate() + 동일 토큰으로 `nid/me` 호출입니다.
/// - 이메일 노출 여부는 **네이버 개발자 센터**의 애플리케이션·동의 항목·API 설정과
///   발급된 액세스 토큰 권한에 따릅니다. (앱 코드에 별도 scope 파라미터 없음)
/// - 점검: 개발자 센터 → 제공 정보에 이메일 필수 여부, 서비스 환경(패키지/번들) 일치,
///   문제 계정은 네이버 **연결 해제 후 재로그인**. 디버그 시 로그의 `nid/me` 키 목록 확인.
class NaverAuthService {
  static final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  static final _auth = FirebaseAuth.instance;

  static String _debugBodyPrefix(String body, [int max = 420]) {
    if (body.isEmpty) return '(empty)';
    final t = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length <= max ? t : '${t.substring(0, max)}…';
  }

  /// 네이버 로그인 실행
  ///
  /// 성공 시 [user]가 non-null. 실패 시 [user]는 null이며 [errorMessage]에 Callable 메시지가 올 수 있음(이메일 중복 등).
  static Future<
      ({
        User? user,
        String? profileEmail,
        String? errorMessage,
      })> signInWithNaver() async {
    try {
      debugPrint('🔑 네이버 로그인 시작');
      
      // 1. 네이버 SDK로 로그인
      final result = await FlutterNaverLogin.logIn();
      
      debugPrint('🧩 네이버 result.status: ${result.status}');
      
      // ✅ status 확인
      if (result.status != NaverLoginStatus.loggedIn) {
        debugPrint('❌ 네이버 로그인 실패: ${result.status}');
        return (user: null, profileEmail: null, errorMessage: null);
      }
      
      // ✅ account 확인
      final account = result.account;
      if (account == null) {
        debugPrint('❌ 네이버 계정 정보가 없습니다');
        return (user: null, profileEmail: null, errorMessage: null);
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
        return (user: null, profileEmail: null, errorMessage: null);
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
        debugPrint('🧩 [nid/me] SDK 이메일 없음 → openapi.naver.com/v1/nid/me 직접 호출');
        try {
          final res = await http.get(
            Uri.parse('https://openapi.naver.com/v1/nid/me'),
            headers: {
              'Authorization': 'Bearer ${tokenResult.accessToken}',
            },
          );
          debugPrint(
            '🧩 [nid/me] HTTP ${res.statusCode} bytes=${res.body.length}',
          );
          if (res.statusCode != 200) {
            if (kDebugMode) {
              debugPrint(
                '🧩 [nid/me] 실패 본문(앞 420자): ${_debugBodyPrefix(res.body)}',
              );
            }
          } else {
            Map<String, dynamic>? map;
            try {
              map = jsonDecode(res.body) as Map<String, dynamic>?;
            } catch (e) {
              debugPrint('⚠️ [nid/me] JSON 파싱 실패: $e');
              if (kDebugMode) {
                debugPrint(
                  '🧩 [nid/me] raw(앞 420자): ${_debugBodyPrefix(res.body)}',
                );
              }
            }
            if (map != null) {
              final resultCode = map['resultcode'];
              final msg = map['message'] as String?;
              final resp = map['response'] as Map<String, dynamic>?;
              final ok =
                  resultCode == '00' ||
                  resultCode == 0 ||
                  resultCode == '0' ||
                  '$resultCode' == '00';
              if (!ok) {
                debugPrint(
                  '🧩 [nid/me] API 오류 resultcode=$resultCode message=$msg',
                );
              }
              final responseKeys =
                  resp == null ? <String>[] : (resp.keys.toList()..sort());
              final hasEmailKey =
                  resp != null &&
                  resp.containsKey('email') &&
                  (resp['email'] as String?)?.trim().isNotEmpty == true;
              debugPrint(
                '🧩 [nid/me] resultcode=$resultCode ok=$ok '
                'response.keys=$responseKeys emailFieldPresent=$hasEmailKey',
              );
              final em = resp?['email'] as String?;
              if (em != null && em.trim().isNotEmpty) {
                profileEmail = em.trim();
                debugPrint('🧩 [nid/me] email 확보: $profileEmail');
              } else if (ok && resp != null && kDebugMode) {
                debugPrint(
                  '🧩 [nid/me] 성공 응답이나 email 비어 있음 (검수·동의·토큰 scope 의심)',
                );
              }
            }
          }
        } catch (e, st) {
          debugPrint('⚠️ [nid/me] 직접 호출 예외: $e');
          debugPrint('⚠️ [nid/me] $st');
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
        return (
          user: null,
          profileEmail: null,
          errorMessage: null,
        );
      }
      
      debugPrint('✅✅✅ 네이버 로그인 완전 성공!');
      debugPrint('✅ UID: ${currentUser.uid}');
      debugPrint('✅ Auth.email: ${currentUser.email} / SDK profileEmail: $profileEmail');
      
      return (
        user: currentUser,
        profileEmail: profileEmail,
        errorMessage: null,
      );
    } on FirebaseFunctionsException catch (e, stackTrace) {
      debugPrint('❌ 네이버 로그인 (Functions): ${e.code} ${e.message}');
      debugPrint('❌ StackTrace: $stackTrace');
      return (
        user: null,
        profileEmail: null,
        errorMessage: e.message,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ 네이버 로그인 예외 발생');
      debugPrint('❌ Error: $e');
      debugPrint('❌ StackTrace: $stackTrace');
      return (user: null, profileEmail: null, errorMessage: null);
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
