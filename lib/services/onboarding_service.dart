import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 기능 소개 온보딩 관리 서비스
///
/// - [appOnboardingCompleted] : Firestore `users/{uid}.appOnboardingCompleted`
/// - [pendingOnboarding]      : SharedPreferences — 로그인 직후 온보딩 실행 신호
/// - 테스트 계정(doughong@naver.com)은 항상 온보딩 실행
class OnboardingService {
  static final _db = FirebaseFirestore.instance;
  static const _pendingKey = 'pendingOnboarding';

  // ── 테스트 계정: 매 로그인마다 온보딩 재실행 ────────────────
  static const _testEmail = 'doughong@naver.com';

  // ─────────────────────────────────────────────────────────────
  // 로그인 직후 호출 — "다음 HomeShell 진입 시 온보딩 실행" 예약
  // ─────────────────────────────────────────────────────────────
  static Future<void> schedulePendingOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_pendingKey, true);
    } catch (e) {
      debugPrint('⚠️ OnboardingService.schedulePendingOnboarding 실패: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HomeShell 진입 시 온보딩을 실행해야 하는지 판단
  //
  // true 반환 조건:
  //   1) pendingOnboarding == true (이번 로그인에서 처음 진입)
  //      AND
  //   2) appOnboardingCompleted == false (아직 온보딩 미완료)
  //      OR 테스트 계정
  // ─────────────────────────────────────────────────────────────
  static Future<bool> shouldRunOnboarding() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // 테스트 계정 확인: Firebase Auth email 우선, 없으면 Firestore email 확인
      final authEmail = user.email;
      final isTestAccount = await _isTestAccount(user.uid, authEmail);
      if (isTestAccount) {
        debugPrint('🧪 테스트 계정: 온보딩 강제 실행');
        return true;
      }

      // 일반 계정: pendingOnboarding 플래그 확인 (이번 로그인이 첫 HomeShell 진입인지)
      final prefs = await SharedPreferences.getInstance();
      final isPending = prefs.getBool(_pendingKey) ?? false;
      if (!isPending) return false;

      // ✅ pendingOnboarding=true이면 appOnboardingCompleted 체크 없이 바로 실행
      // 이유: 계정 삭제 후 재가입 시 Firestore에 이전 문서(appOnboardingCompleted=true)가
      //       남아있어도 온보딩이 실행되어야 함. pendingOnboarding 플래그 자체가
      //       "이번 로그인에서 최초 HomeShell 진입" 여부를 이미 보장함.
      debugPrint('✅ OnboardingService: pendingOnboarding=true → 온보딩 실행');
      return true;
    } catch (e) {
      debugPrint('⚠️ OnboardingService.shouldRunOnboarding 실패: $e');
      return false;
    }
  }

  /// 테스트 계정 여부: Auth email 없으면 Firestore에서 email 조회
  static Future<bool> _isTestAccount(String uid, String? authEmail) async {
    if (authEmail == _testEmail) return true;
    // Naver 커스텀 토큰 로그인은 Firebase Auth email이 null일 수 있으므로
    // Firestore users/{uid}.email 에서 확인
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final firestoreEmail = doc.data()?['email'] as String?;
      return firestoreEmail == _testEmail;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 온보딩 완료 처리
  // ─────────────────────────────────────────────────────────────
  static Future<void> completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingKey);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 테스트 계정은 Firestore에 완료 기록 저장하지 않음 (매번 재실행)
      final isTest = await _isTestAccount(user.uid, user.email);
      if (isTest) {
        debugPrint('🧪 테스트 계정: 온보딩 완료 기록 저장 생략');
        return;
      }

      await _db.collection('users').doc(user.uid).set(
        {'appOnboardingCompleted': true},
        SetOptions(merge: true),
      );
      debugPrint('✅ OnboardingService: appOnboardingCompleted=true 저장 완료');
    } catch (e) {
      debugPrint('⚠️ OnboardingService.completeOnboarding 실패: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 재가입자 온보딩 표시 여부 (deletedUsers 이력 기반)
  // signUpCount == 1 → 온보딩 표시
  // signUpCount >= 2 → 온보딩 없이 풀기능
  // ─────────────────────────────────────────────────────────────
  static Future<bool> shouldShowOnboardingForReturningUser(String uid) async {
    try {
      final snap = await _db.collection('deletedUsers').doc(uid).get();
      if (!snap.exists) return true; // 신규 가입 → 온보딩 표시
      final count = snap.data()?['signUpCount'] as int? ?? 0;
      return count <= 1; // 1번 탈퇴자까지만 온보딩
    } catch (e) {
      debugPrint('⚠️ OnboardingService.shouldShowOnboardingForReturningUser 실패: $e');
      return true;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // internal
  // ─────────────────────────────────────────────────────────────
}

