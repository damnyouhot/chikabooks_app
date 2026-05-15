import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// OAuth(구글·애플 등)과 이메일·비밀번호 계정이 같은 이메일로 충돌할 때 연동한다.
class AppFirebaseAccountLinking {
  AppFirebaseAccountLinking._();

  /// [signInWithCredential] 1차 시도. 성공 시 [OAuthSignInFirstAttempt.success],
  /// `account-exists-with-different-credential` 이면 이메일·비밀번호로 연동할 수 있게 [needsEmailPasswordMerge].
  static Future<OAuthSignInFirstAttempt> signInWithOAuthCredential(
    AuthCredential credential,
  ) async {
    try {
      final uc = await FirebaseAuth.instance.signInWithCredential(credential);
      return OAuthSignInFirstAttempt.success(uc);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        final em = e.email?.trim();
        final pending = e.credential;
        if (em != null && em.isNotEmpty && pending != null) {
          return OAuthSignInFirstAttempt.needsEmailPasswordMerge(
            email: em,
            pending: pending,
          );
        }
      }
      rethrow;
    }
  }

  /// 이미 있는 이메일·비밀번호로 로그인한 뒤 [pendingOAuthCredential]을 같은 Firebase 사용자에 연결한다.
  static Future<UserCredential> signInWithEmailPasswordAndLinkOAuth({
    required String email,
    required String password,
    required AuthCredential pendingOAuthCredential,
  }) async {
    final existing = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = existing.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: '로그인 후 사용자 정보를 불러오지 못했어요.',
      );
    }
    try {
      await user.linkWithCredential(pendingOAuthCredential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        debugPrint('ℹ️ OAuth provider 이미 연결됨 — 그대로 진행');
      } else if (e.code == 'credential-already-in-use') {
        throw FirebaseAuthException(
          code: e.code,
          message: '이 SNS 계정은 다른 이메일 계정에 이미 연결되어 있어요.',
        );
      } else {
        rethrow;
      }
    }
    return existing;
  }
}

/// OAuth 1차 로그인 결과.
class OAuthSignInFirstAttempt {
  const OAuthSignInFirstAttempt._({
    this.directUserCredential,
    this.mergeEmail,
    this.pendingOAuthCredential,
  });

  factory OAuthSignInFirstAttempt.success(UserCredential uc) {
    return OAuthSignInFirstAttempt._(directUserCredential: uc);
  }

  factory OAuthSignInFirstAttempt.needsEmailPasswordMerge({
    required String email,
    required AuthCredential pending,
  }) {
    return OAuthSignInFirstAttempt._(
      mergeEmail: email,
      pendingOAuthCredential: pending,
    );
  }

  final UserCredential? directUserCredential;
  final String? mergeEmail;
  final AuthCredential? pendingOAuthCredential;

  bool get needsMerge =>
      (mergeEmail?.isNotEmpty ?? false) && pendingOAuthCredential != null;
}
