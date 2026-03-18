import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_public_profile.dart';
import '../models/partner_preferences.dart';

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

    // 현재 활성 파트너 그룹의 memberMeta도 최신 관심사로 업데이트
    await _syncMemberMetaConcerns(uid, profile.mainConcerns);
  }

  /// 파트너 그룹 memberMeta의 관심사를 최신 값으로 동기화
  static Future<void> _syncMemberMetaConcerns(
    String uid,
    List<String> mainConcerns,
  ) async {
    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      final groupId = userDoc.data()?['partnerGroupId'] as String?;
      if (groupId == null || groupId.isEmpty) return;

      final concerns = mainConcerns.take(2).toList();
      await _db
          .collection('partnerGroups')
          .doc(groupId)
          .collection('memberMeta')
          .doc(uid)
          .update({
            'mainConcerns': concerns,
            'mainConcernShown': concerns.isNotEmpty ? concerns[0] : null,
          });
      debugPrint('✅ [UserProfileService] memberMeta 관심사 동기화 완료');
    } catch (e) {
      // memberMeta 업데이트 실패는 치명적이지 않으므로 로그만 남김
      debugPrint('⚠️ [UserProfileService] memberMeta 동기화 실패 (무시): $e');
    }
  }

  /// 현재 결 점수 (마이그레이션 포함, 0~100 범위)
  /// 구버전(35~85) 데이터가 있으면 자동 변환 후 저장
  static Future<double> getBondScore() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 50.0;

    final profile = await getMyProfile();
    if (profile == null) return 50.0;

    // 이미 v2면 캐시값 그대로
    if (profile.bondScoreVersion >= 2) return profile.bondScore;

    // 구버전 → BondScoreService.readAndMigrate 로 1회 변환+저장
    // (순환 import 방지: 여기서 직접 변환)
    final raw = profile.bondScore;
    final migrated = ((raw.clamp(35.0, 85.0) - 35.0) * 2.0).clamp(0.0, 100.0);
    await _db.collection('users').doc(uid).update({
      'bondScore': migrated,
      'bondScoreVersion': 2,
    });
    _cache = null; // 캐시 갱신 유도
    return migrated;
  }

  /// 활성 파트너 그룹 ID (없으면 null)
  static Future<String?> getPartnerGroupId() async {
    final profile = await getMyProfile(forceRefresh: true);
    if (profile?.hasActiveGroup == true) {
      return profile!.partnerGroupId;
    }
    return null;
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

    // bondScore가 없는 신규 계정은 20.0으로 초기화
    final existingDoc = await _db.collection('users').doc(uid).get();
    final existingData = existingDoc.data();
    final Map<String, dynamic> data = {
      'nickname': nickname.trim(),
      'region': region,
      'careerGroup': careerGroup, // 원본도 저장
      'careerBucket': careerBucket, // 매칭용 버킷도 저장
      'mainConcerns': concernTags,
      'isProfileCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
      // 파트너 매칭 기본값 (없는 경우에만 설정)
      if (existingData?['partnerStatus'] == null) 'partnerStatus': 'active',
      if (existingData?['bondScore'] == null) 'bondScore': 20.0,
      if (existingData?['bondScore'] == null) 'bondScoreVersion': 2,
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

  // ═══════════════════════ 파트너 선호도 (v1 설계) ═══════════════════════

  /// 파트너 매칭 선호도 가져오기
  static Future<PartnerPreferences> getPartnerPreferences() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return PartnerPreferences.defaultPreset();

    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return PartnerPreferences.defaultPreset();

      final data = doc.data();
      if (data?['partnerPreferences'] != null) {
        return PartnerPreferences.fromMap(
          data!['partnerPreferences'] as Map<String, dynamic>,
        );
      }
      return PartnerPreferences.defaultPreset();
    } catch (e) {
      debugPrint('⚠️ getPartnerPreferences error: $e');
      return PartnerPreferences.defaultPreset();
    }
  }

  /// 파트너 매칭 선호도 저장
  static Future<void> updatePartnerPreferences(
    PartnerPreferences preferences,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');

    try {
      await _db.collection('users').doc(uid).update({
        'partnerPreferences': preferences.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _cache = null; // 캐시 초기화
    } catch (e) {
      debugPrint('⚠️ updatePartnerPreferences error: $e');
      rethrow;
    }
  }

  /// 파트너 상태 업데이트 ('active' | 'pause')
  static Future<void> updatePartnerStatus(String status) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');

    if (status != 'active' && status != 'pause') {
      throw Exception('유효하지 않은 상태값입니다: $status');
    }

    try {
      await _db.collection('users').doc(uid).update({
        'partnerStatus': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _cache = null;
    } catch (e) {
      debugPrint('⚠️ updatePartnerStatus error: $e');
      rethrow;
    }
  }

  /// 다음 주 매칭 여부 업데이트 (pause 상태에서만 의미 있음)
  static Future<void> updateWillMatchNextWeek(bool willMatch) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');

    // pause 상태 확인 - active는 항상 매칭 대상이므로 변경 불가
    final profile = await getMyProfile(forceRefresh: true);
    if (profile?.partnerStatus != 'pause') {
      debugPrint('⚠️ active 상태에서는 willMatchNextWeek 변경 불가 (항상 매칭 대상)');
      return;
    }

    try {
      await _db.collection('users').doc(uid).update({
        'willMatchNextWeek': willMatch,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _cache = null;
    } catch (e) {
      debugPrint('⚠️ updateWillMatchNextWeek error: $e');
      rethrow;
    }
  }

  /// 이어가기 파트너 선택 (리스트 저장, 구버전 단일 필드도 함께 유지)
  static Future<void> selectContinuePartners(List<String> partnerUids) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');

    try {
      await _db.collection('users').doc(uid).update({
        'continueWithPartners': partnerUids,
        // 구버전 호환: 첫 번째 UID를 단일 필드에도 저장
        'continueWithPartner':
            partnerUids.isNotEmpty ? partnerUids.first : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _cache = null;
    } catch (e) {
      debugPrint('⚠️ selectContinuePartners error: $e');
      rethrow;
    }
  }

  /// 이어가기 선택 취소
  static Future<void> cancelContinuePartners() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');

    try {
      await _db.collection('users').doc(uid).update({
        'continueWithPartners': [],
        'continueWithPartner': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _cache = null;
    } catch (e) {
      debugPrint('⚠️ cancelContinuePartners error: $e');
      rethrow;
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
