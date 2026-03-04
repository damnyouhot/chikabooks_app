import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 로그인 provider / lastLoginAt 기록 유틸
///
/// - Firestore `users/{uid}` 에 `provider`, `lastLoginAt` 저장
///   (카카오/네이버/애플은 Cloud Function에서 이미 저장하지만,
///    Google / Email 은 여기서 저장)
/// - SharedPreferences 에도 저장하여 로그인 페이지 "마지막 로그인" 배지에 활용
class SignInTracker {
  static final _db = FirebaseFirestore.instance;

  static const _prefKey = 'lastSignInProvider';

  // ── Firestore + 로컬 저장 ─────────────────────────────────
  /// 로그인 성공 직후 호출
  static Future<void> record(String provider) async {
    // 1) 로컬 저장 (배지용)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, provider);
    } catch (_) {}

    // 2) Firestore 저장
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db.collection('users').doc(uid).set({
        'provider': provider,
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ SignInTracker: provider=$provider 저장 완료');
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

