import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Apple 로그인 서비스
/// Custom Token 방식으로 Firebase Auth 연동
class AppleAuthService {
  static final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  static final _auth = FirebaseAuth.instance;

  /// Apple 로그인 실행
  static Future<User?> signInWithApple() async {
    try {
      // 1. Apple 로그인 (SDK)
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final String? providerId = appleCredential.userIdentifier;
      final String? email = appleCredential.email;
      final String? givenName = appleCredential.givenName;
      final String? familyName = appleCredential.familyName;
      final String? displayName = givenName != null && familyName != null
          ? '$givenName $familyName'
          : null;

      if (providerId == null) {
        debugPrint('⚠️ Apple 사용자 ID를 가져올 수 없습니다');
        return null;
      }

      debugPrint('✅ Apple 로그인 성공: $providerId ($email)');

      // 2. Firebase Custom Token 발급 요청
      final result = await _functions.httpsCallable('createCustomToken').call({
        'provider': 'apple',
        'providerId': providerId,
        'email': email,
        'displayName': displayName,
      });

      final String customToken = result.data['customToken'];

      // 3. Firebase Auth에 Custom Token으로 로그인
      final credential = await _auth.signInWithCustomToken(customToken);

      debugPrint('✅ Firebase 로그인 완료: ${credential.user?.uid}');

      return credential.user;
    } catch (e) {
      debugPrint('⚠️ Apple 로그인 실패: $e');
      return null;
    }
  }

  /// Apple 로그아웃 (Firebase Auth만)
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      debugPrint('✅ Apple 로그아웃 완료');
    } catch (e) {
      debugPrint('⚠️ Apple 로그아웃 실패: $e');
    }
  }

  /// Apple 연결 해제 (회원 탈퇴)
  static Future<void> unlink() async {
    try {
      // Apple은 SDK에서 연결 해제 API를 제공하지 않으므로
      // Firebase Auth 사용자만 삭제
      await _auth.currentUser?.delete();
      debugPrint('✅ Apple 연결 해제 완료');
    } catch (e) {
      debugPrint('⚠️ Apple 연결 해제 실패: $e');
    }
  }
}

