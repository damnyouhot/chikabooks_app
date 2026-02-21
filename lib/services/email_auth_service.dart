import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 이메일/비밀번호 로그인 서비스
/// Firebase Auth 기본 기능 사용
class EmailAuthService {
  static final _auth = FirebaseAuth.instance;

  /// 이메일/비밀번호로 회원가입
  static Future<User?> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 닉네임 설정
      if (displayName != null && displayName.isNotEmpty) {
        await credential.user?.updateDisplayName(displayName);
      }

      debugPrint('✅ 이메일 회원가입 완료: ${credential.user?.uid}');

      return credential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('⚠️ 이메일 회원가입 실패: ${e.code}');
      switch (e.code) {
        case 'weak-password':
          debugPrint('비밀번호가 너무 약합니다');
          break;
        case 'email-already-in-use':
          debugPrint('이미 사용 중인 이메일입니다');
          break;
        case 'invalid-email':
          debugPrint('유효하지 않은 이메일입니다');
          break;
        default:
          debugPrint('알 수 없는 오류: ${e.message}');
      }
      return null;
    }
  }

  /// 이메일/비밀번호로 로그인
  static Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      debugPrint('✅ 이메일 로그인 완료: ${credential.user?.uid}');

      return credential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('⚠️ 이메일 로그인 실패: ${e.code}');
      switch (e.code) {
        case 'user-not-found':
          debugPrint('등록되지 않은 이메일입니다');
          break;
        case 'wrong-password':
          debugPrint('비밀번호가 틀렸습니다');
          break;
        case 'invalid-email':
          debugPrint('유효하지 않은 이메일입니다');
          break;
        case 'user-disabled':
          debugPrint('비활성화된 계정입니다');
          break;
        default:
          debugPrint('알 수 없는 오류: ${e.message}');
      }
      return null;
    }
  }

  /// 비밀번호 재설정 이메일 발송
  static Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('✅ 비밀번호 재설정 이메일 발송 완료');
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('⚠️ 비밀번호 재설정 이메일 발송 실패: ${e.code}');
      return false;
    }
  }

  /// 로그아웃
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      debugPrint('✅ 로그아웃 완료');
    } catch (e) {
      debugPrint('⚠️ 로그아웃 실패: $e');
    }
  }

  /// 계정 삭제
  static Future<void> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
      debugPrint('✅ 계정 삭제 완료');
    } on FirebaseAuthException catch (e) {
      debugPrint('⚠️ 계정 삭제 실패: ${e.code}');
      if (e.code == 'requires-recent-login') {
        debugPrint('재인증이 필요합니다');
      }
    }
  }

  /// 재인증 (비밀번호 변경 등 민감한 작업 전)
  static Future<bool> reauthenticate(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return false;

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      debugPrint('✅ 재인증 완료');
      return true;
    } catch (e) {
      debugPrint('⚠️ 재인증 실패: $e');
      return false;
    }
  }
}


