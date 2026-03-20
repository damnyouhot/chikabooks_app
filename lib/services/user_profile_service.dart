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
      DocumentSnapshot<Map<String, dynamic>> doc;
      if (forceRefresh) {
        doc = await _db.collection('users').doc(uid).get();
      } else {
        // 캐시 우선: 콜드 스타트 시 Firestore 연결 대기 없이 즉시 반환
        try {
          doc = await _db.collection('users').doc(uid).get(
            const GetOptions(source: Source.cache),
          );
          if (!doc.exists) throw Exception('cache miss');
        } catch (_) {
          doc = await _db.collection('users').doc(uid).get();
        }
      }
      if (!doc.exists) return null;
      _cache = UserPublicProfile.fromMap(doc.data() ?? {});
      await _ensurePublicProfile(uid, _cache);
      return _cache;
    } catch (e) {
      debugPrint('⚠️ getMyProfile error: $e');
      return null;
    }
  }

  static Future<void> _ensurePublicProfile(
    String uid,
    UserPublicProfile? profile,
  ) async {
    try {
      final nickname = profile?.nickname.trim() ?? '';
      if (nickname.isEmpty) return;
      await _db.collection('publicProfiles').doc(uid).set({
        'uid': uid,
        'nickname': nickname,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ _ensurePublicProfile error: $e');
    }
  }

  /// Step A 기본 프로필 입력 완료 여부
  static Future<bool> hasBasicProfile() async {
    final profile = await getMyProfile();
    return profile?.hasBasicProfile ?? false;
  }

  /// Step A 저장: 닉네임 / 지역 / 연차
  static Future<void> updateBasicProfile({
    required String nickname,
    required String region,
    required String careerBucket,
    String? careerGroup, // 원본 연차 텍스트도 함께 저장
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');

    final data = <String, dynamic>{
      'nickname': nickname.trim(),
      'region': region,
      'careerBucket': careerBucket,
      if (careerGroup != null) 'careerGroup': careerGroup,
    };

    await _db.collection('users').doc(uid).update(data);
    await _ensurePublicProfile(uid, UserPublicProfile(nickname: nickname));
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
    await _ensurePublicProfile(uid, profile);
    _cache = profile;
  }

  /// 온보딩 프로필 완료 (닉네임 + 지역군 + 연차 + 관심사)
  /// 최초 로그인 후 1회만 실행
  static Future<void> completeOnboarding({
    required String nickname,
    required String region,
    required String careerGroup,
    required List<String> concernTags,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');

    debugPrint('🔍 [completeOnboarding] UID: $uid');
    debugPrint('🔍 [completeOnboarding] nickname: $nickname');
    debugPrint('🔍 [completeOnboarding] region: $region');
    debugPrint('🔍 [completeOnboarding] careerGroup: $careerGroup');
    debugPrint('🔍 [completeOnboarding] concernTags: $concernTags');

    // ✅ careerGroup → careerBucket 변환
    String careerBucket;
    if (careerGroup == '학생' || careerGroup == '1년차' || careerGroup == '2년차') {
      careerBucket = '0-2';
    } else if (careerGroup == '3년차' ||
        careerGroup == '4년차' ||
        careerGroup == '5년차') {
      careerBucket = '3-5';
    } else {
      careerBucket = '6+';
    }

    final Map<String, dynamic> data = {
      'nickname': nickname.trim(),
      'region': region,
      'careerGroup': careerGroup,
      'careerBucket': careerBucket,
      'mainConcerns': concernTags,
      'isProfileCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    debugPrint('🔍 [completeOnboarding] Firestore 업데이트 시작...');
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
    debugPrint('✅ [completeOnboarding] Firestore 업데이트 완료');

    // 캐시 갱신
    debugPrint('🔍 [completeOnboarding] 캐시 갱신 중...');
    _cache = await getMyProfile(forceRefresh: true);
    debugPrint('✅ [completeOnboarding] 캐시 갱신 완료');
  }

  /// 온보딩 완료 여부 체크 (캐시 우선 — 탭 전환 블로킹 방지)
  static Future<bool> isOnboardingCompleted() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    // 캐시가 있으면 Firestore 호출 없이 즉시 반환
    // hasBasicProfile = nickname + region + careerBucket 모두 입력된 상태
    if (_cache != null) {
      return _cache!.hasBasicProfile;
    }

    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return false;

      final data = doc.data() ?? {};
      // 조회 결과를 캐시에 저장해서 이후 호출 최적화
      _cache = UserPublicProfile.fromMap(data);
      // Firestore에 isProfileCompleted 필드가 있으면 우선 사용, 없으면 hasBasicProfile
      return data['isProfileCompleted'] == true || _cache!.hasBasicProfile;
    } catch (e) {
      debugPrint('⚠️ isOnboardingCompleted error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 관리자 / 통계 제어
  // ═══════════════════════════════════════════════════════════════

  /// 현재 유저가 관리자인지 확인
  ///
  /// users/{uid}.isAdmin == true 이면 관리자 대시보드 접근 허용
  static Future<bool> isAdmin() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return false;

      // 캐시에 있으면 캐시 사용
      if (_cache != null) return _cache!.isAdmin;

      final doc = await _db.collection('users').doc(uid).get();
      return doc.data()?['isAdmin'] == true;
    } catch (e) {
      debugPrint('⚠️ UserProfileService.isAdmin error: $e');
      return false;
    }
  }

  /// 특정 유저의 통계 제외 여부 설정 (관리자 전용)
  ///
  /// [targetUid]  : 대상 유저 UID
  /// [exclude]    : true이면 통계 제외, false이면 포함
  static Future<void> setExcludeFromStats(
    String targetUid, {
    required bool exclude,
  }) async {
    try {
      await _db.collection('users').doc(targetUid).update({
        'excludeFromStats': exclude,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // 자신에 대한 설정이면 캐시 초기화
      if (targetUid == _auth.currentUser?.uid) _cache = null;
    } catch (e) {
      debugPrint('⚠️ UserProfileService.setExcludeFromStats error: $e');
      rethrow;
    }
  }
}
