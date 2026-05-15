import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Apple 로그인 서비스
/// Firebase OAuthCredential 직접 방식 (Cloud Functions 불필요)
class AppleAuthService {
  static final _auth = FirebaseAuth.instance;

  static const _webClientId = 'com.chikabooks.web';
  static const _webRedirectUri =
      'https://chikabooks3rd.web.app/__/auth/handler';

  /// nonce를 생성하여 replay attack 방지
  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Apple 로그인 실행
  ///
  /// 성공 시 `(Firebase User, Apple이 첫 인증에만 넘겨주는 이메일)` — 두 번째 인자는 재로그인 시 null 인 경우가 많음.
  static Future<(User user, String? emailFromCredential)?> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: kIsWeb ? null : nonce,
        webAuthenticationOptions: kIsWeb
            ? WebAuthenticationOptions(
                clientId: _webClientId,
                redirectUri: Uri.parse(_webRedirectUri),
              )
            : null,
      );

      final emailFromApple = appleCredential.email?.trim();

      final identityToken = appleCredential.identityToken;
      if (identityToken == null) {
        debugPrint('⚠️ Apple identityToken이 null');
        return null;
      }

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential =
          await _auth.signInWithCredential(oauthCredential);

      // Apple은 이름을 최초 1회만 제공 → displayName 업데이트
      final givenName = appleCredential.givenName;
      final familyName = appleCredential.familyName;
      if (givenName != null || familyName != null) {
        final displayName =
            [familyName, givenName].where((s) => s != null).join(' ').trim();
        if (displayName.isNotEmpty) {
          await userCredential.user?.updateDisplayName(displayName);
        }
      }

      final u = userCredential.user;
      if (u == null) {
        debugPrint('⚠️ Apple userCredential.user가 null');
        return null;
      }

      debugPrint(
        '✅ Apple 로그인 성공: ${u.uid} (${u.email}) '
        'credentialEmail=${emailFromApple ?? "(없음·재로그인 또는 숨김)"}',
      );

      return (u, emailFromApple);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        rethrow;
      }
      debugPrint(
        '⚠️ Apple 로그인 FirebaseAuthException: ${e.code} ${e.message}',
      );
      return null;
    } catch (e) {
      if (e.toString().contains('AuthorizationErrorCode.canceled')) {
        debugPrint('ℹ️ Apple 로그인 취소');
        return null;
      }
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
      await _auth.currentUser?.delete();
      debugPrint('✅ Apple 연결 해제 완료');
    } catch (e) {
      debugPrint('⚠️ Apple 연결 해제 실패: $e');
    }
  }
}
