import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_public_profile.dart';

/// 교감 프로필 서비스 (캐시 포함)
///
/// Firestore users/{uid} 문서에서 프로필 필드를 읽고 쓴다.
/// 최초 호출 시 1회 로드 후 메모리 캐시하여 읽기 과부하 방지.
class UserProfileService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// 메모리 캐시 (앱 세션 동안 유지)
  static UserPublicProfile? _cache;

  /// 캐시 강제 초기화 (로그아웃/계정 전환 시)
  static void clearCache() => _cache = null;

  /// 현재 유저의 교감 프로필 반환 (캐시 우선)
  static Future<UserPublicProfile?> getMyProfile({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cache != null) return _cache;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      _cache = UserPublicProfile.fromMap(doc.data() ?? {});
      return _cache;
    } catch (e) {
      debugPrint('⚠️ getMyProfile error: $e');
      return null;
    }
  }

  /// Step A 기본 프로필 입력 완료 여부
  static Future<bool> hasBasicProfile() async {
    final profile = await getMyProfile();
    return profile?.hasBasicProfile ?? false;
  }

  /// Step B 파트너 프로필 입력 완료 여부
  static Future<bool> hasPartnerProfile() async {
    final profile = await getMyProfile();
    return profile?.hasPartnerProfile ?? false;
  }

  /// Step A 저장: 닉네임 / 지역 / 연차
  static Future<void> updateBasicProfile({
    required String nickname,
    required String region,
    required String careerBucket,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');

    final data = {
      'nickname': nickname.trim(),
      'region': region,
      'careerBucket': careerBucket,
    };

    await _db.collection('users').doc(uid).update(data);
    // 캐시 갱신
    _cache = await getMyProfile(forceRefresh: true);
  }

  /// Step B 저장: 주 고민 / 근무 유형
  static Future<void> updatePartnerProfile({
    required List<String> mainConcerns,
    String? workplaceType,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');

    final data = <String, dynamic>{
      'mainConcerns': mainConcerns,
      'workplaceType': workplaceType,
    };

    await _db.collection('users').doc(uid).update(data);
    _cache = await getMyProfile(forceRefresh: true);
  }

  /// 전체 교감 프로필 한 번에 저장 (설정 페이지용)
  static Future<void> updateFullProfile(UserPublicProfile profile) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');

    await _db.collection('users').doc(uid).update(profile.toMap());
    _cache = profile;
  }

  /// 현재 결 점수 (캐시에서 읽기, 없으면 60.0)
  static Future<double> getBondScore() async {
    final profile = await getMyProfile();
    return profile?.bondScore ?? 60.0;
  }

  /// 활성 파트너 그룹 ID (없으면 null)
  static Future<String?> getPartnerGroupId() async {
    final profile = await getMyProfile(forceRefresh: true);
    if (profile?.hasActiveGroup == true) {
      return profile!.partnerGroupId;
    }
    return null;
  }
}

