import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 위생사(지원자) 로그인 provider / lastLoginAt / email 기록 유틸
///
/// 대상 컬렉션: `users/{uid}` (위생사 전용)
/// 공고자 로그인 기록은 `ClinicAuthService.recordLogin()`으로 별도 처리
///
/// - Firestore `users/{uid}` 에 `provider`, `lastLoginAt`, `email`, `normalizedEmail` 저장
///   (네이버는 Cloud Function에서도 저장하지만, Auth에 email 이 없을 때를 위해
///    [email] 인자로 SDK/애플 크리덴셜 이메일을 넘기면 여기서 보강)
/// - SharedPreferences 에도 저장하여 로그인 페이지 "마지막 로그인" 배지에 활용
class SignInTracker {
  static final _db = FirebaseFirestore.instance;

  static const _prefKey = 'lastSignInProvider';

  // ── Firestore + 로컬 저장 ─────────────────────────────────
  /// 로그인 성공 직후 호출.
  /// [email] 을 명시하면 Firestore에 저장. 생략 시 Firebase Auth currentUser.email 자동 사용.
  ///
  /// 치과(공고자) 계정(`clinics_accounts/{uid}`)이면 `users/{uid}`에 쓰지 않는다.
  /// 공고자 기록은 `ClinicAuthService.recordLogin()`에서 별도 처리.
  static Future<void> record(String provider, {String? email}) async {
    // 1) 로컬 저장 (배지용)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, provider);
    } catch (_) {}

    // 2) Firestore 저장
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // 치과(공고자) 계정이면 users 컬렉션에 쓰지 않는다
    try {
      final clinicDoc =
          await _db.collection('clinics_accounts').doc(uid).get();
      if (clinicDoc.exists) {
        debugPrint(
          '⏭️ SignInTracker: clinics_accounts/$uid 존재 → users 기록 skip',
        );
        return;
      }
    } catch (e) {
      debugPrint('⚠️ SignInTracker: clinics_accounts 확인 실패 (계속 진행): $e');
    }

    // 이메일: 파라미터 우선 → Firebase Auth currentUser.email 폴백
    final resolvedEmail =
        email?.trim().isNotEmpty == true
            ? email!.trim()
            : FirebaseAuth.instance.currentUser?.email;

    try {
      final userRef = _db.collection('users').doc(uid);

      // 기존 문서 확인: createdAt이 없으면 신규 가입으로 간주
      final existing = await userRef.get();
      final isNewUser = !existing.exists || existing.data()?['createdAt'] == null;

      final data = <String, dynamic>{
        'provider': provider,
        'lastLoginAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(), // 매 로그인마다 갱신
      };

      // 신규 가입 시에만 createdAt 기록 (기존 데이터 덮어쓰기 방지)
      if (isNewUser) {
        data['createdAt'] = FieldValue.serverTimestamp();
        // excludeFromStats 필드를 명시적으로 false로 저장
        // (없으면 isEqualTo: false 쿼리에서 제외되어 대시보드 집계 누락)
        data['excludeFromStats'] = false;
        debugPrint('✅ SignInTracker: 신규 가입 createdAt + excludeFromStats 기록');
      }

      // 이메일이 있으면 merge (애플: 첫 로그인 credential / Firebase User)
      if (resolvedEmail != null && resolvedEmail.isNotEmpty) {
        data['email'] = resolvedEmail;
        data['normalizedEmail'] = resolvedEmail.trim().toLowerCase();
      }

      await userRef.set(
        data,
        SetOptions(merge: true),
      );
      debugPrint('✅ SignInTracker: provider=$provider, email=$resolvedEmail 저장 완료');
    } catch (e) {
      debugPrint('⚠️ SignInTracker Firestore 저장 실패: $e');
    }
  }

  // ── 로컬에서 마지막 provider 조회 (로그인 페이지 배지용) ───
  static Future<String?> getLocalLastProvider() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefKey);
    } catch (_) {
      return null;
    }
  }
}

