import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 기능 소개 온보딩 관리 서비스
///
/// - [appOnboardingCompleted] : Firestore `users/{uid}.appOnboardingCompleted`
/// - [pendingOnboarding]      : SharedPreferences — 로그인 직전 [forceSchedule]로 예약.
///   온보딩을 **완료**할 때만 제거한다. (시작 시점에 지우면 앱 중간 종료 후 재실행 시 온보딩이 안 뜸)
///   [shouldRunOnboarding]은 Firestore [appOnboardingCompleted]를 우선하며, Firestore 오류 시에만 pending을 본다.
class OnboardingService {
  static final _db = FirebaseFirestore.instance;
  static const _pendingKey = 'pendingOnboarding';

  // ─────────────────────────────────────────────────────────────
  // 무조건 pendingOnboarding 플래그 설정 (Firestore/Auth 체크 없음)
  //
  // 사용처:
  //   1) 계정 삭제 후 (signOut 상태여서 currentUser가 null)
  //   2) 로그인 직전 (race condition 방지 — auth state 변경 전에 설정)
  //
  // shouldRunOnboarding()에서 Firestore appOnboardingCompleted을 재확인하므로
  // 기존 유저에게 중복 온보딩이 실행되지 않음.
  // ─────────────────────────────────────────────────────────────
  static Future<void> forceSchedule() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_pendingKey, true);
      debugPrint('✅ OnboardingService.forceSchedule: pendingOnboarding=true 설정');
    } catch (e) {
      debugPrint('⚠️ OnboardingService.forceSchedule 실패: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 로그인 직후 호출 — 신규 유저만 온보딩 예약
  // appOnboardingCompleted=true인 기존 유저는 예약 자체를 건너뜀
  // ─────────────────────────────────────────────────────────────
  static Future<void> schedulePendingOnboarding() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 이미 온보딩 완료한 유저이면 예약하지 않음
      try {
        final doc = await _db.collection('users').doc(user.uid).get();
        final completed =
            doc.data()?['appOnboardingCompleted'] as bool? ?? false;
        if (completed) {
          debugPrint(
            '🔍 OnboardingService.schedulePendingOnboarding: 기존 유저(온보딩 완료) → 예약 스킵',
          );
          return;
        }
      } catch (e) {
        // Firestore 조회 실패 시 → 일단 예약 진행 (shouldRunOnboarding에서 재확인)
        debugPrint('⚠️ OnboardingService: Firestore 확인 실패 → 예약 진행: $e');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_pendingKey, true);
      debugPrint('✅ OnboardingService: pendingOnboarding=true 예약 (신규 유저)');
    } catch (e) {
      debugPrint('⚠️ OnboardingService.schedulePendingOnboarding 실패: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HomeShell 진입 시 앱 기능 소개 온보딩을 실행해야 하는지 판단
  //
  // - Firestore [appOnboardingCompleted]가 있으면 그것이 기준이다.
  //   · true  → pending 정리 후 스킵 (재로그인해도 반복 안 함)
  //   · false → 온보딩 실행. pending은 여기서 지우지 않는다 → 앱 강제 종료 후에도 재실행 시 다시 표시.
  // - Firestore 조회 실패 시에만 [pendingOnboarding]으로 판단 (로그인 직전 forceSchedule 대비)
  // ─────────────────────────────────────────────────────────────
  static Future<bool> shouldRunOnboarding() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final prefs = await SharedPreferences.getInstance();

      try {
        final doc = await _db.collection('users').doc(user.uid).get();
        final completed =
            doc.data()?['appOnboardingCompleted'] as bool? ?? false;
        if (completed) {
          await prefs.remove(_pendingKey);
          debugPrint(
            '✅ OnboardingService: appOnboardingCompleted=true → 스킵 (기존 유저)',
          );
          return false;
        }
        debugPrint(
          '✅ OnboardingService: appOnboarding 미완료 → 온보딩 실행 (pending 유지)',
        );
        return true;
      } catch (e) {
        debugPrint(
          '⚠️ OnboardingService: Firestore 확인 실패 → pendingOnboarding 기준: $e',
        );
      }

      final isPending = prefs.getBool(_pendingKey) ?? false;
      if (!isPending) {
        debugPrint(
          '🔍 OnboardingService: pendingOnboarding=false → 스킵 (Firestore 오류)',
        );
        return false;
      }
      debugPrint(
        '✅ OnboardingService: Firestore 오류 + pending → 온보딩 실행',
      );
      return true;
    } catch (e) {
      debugPrint('⚠️ OnboardingService.shouldRunOnboarding 실패: $e');
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
}
