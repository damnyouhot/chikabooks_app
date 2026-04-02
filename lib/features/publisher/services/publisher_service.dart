import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 게시자(치과 측) 온보딩 상태 모델
///
/// **Deprecated**: 새 플로우에서는 [ClinicAuthService] + [ClinicProfileService]를 사용합니다.
/// 이 클래스는 레거시 온보딩 페이지 호환용으로만 유지됩니다.
@Deprecated('Use ClinicAuthService + ClinicProfileService instead')
class PublisherStatus {
  final String role; // 'publisher' 또는 ''
  final bool phoneVerified; // 휴대폰 인증 완료
  final bool profileDone; // 기본정보 입력 완료
  final bool clinicVerified; // 사업자 인증 완료
  final bool isPending; // 사업자 인증 검토 중

  const PublisherStatus({
    this.role = '',
    this.phoneVerified = false,
    this.profileDone = false,
    this.clinicVerified = false,
    this.isPending = false,
  });

  factory PublisherStatus.fromMap(Map<String, dynamic> data) {
    final onboarding = data['onboarding'] as Map<String, dynamic>? ?? {};
    return PublisherStatus(
      role: data['role'] as String? ?? '',
      phoneVerified: data['phoneVerified'] as bool? ?? false,
      profileDone: onboarding['profile'] == 'done',
      clinicVerified: data['clinicVerified'] as bool? ?? false,
      isPending: onboarding['business'] == 'pending',
    );
  }

  /// 공고 작성 가능 여부
  bool get canPost => phoneVerified && profileDone && clinicVerified;

  /// 다음에 가야 할 라우트
  String get nextRoute {
    if (!phoneVerified) return '/publisher/verify-phone';
    if (!profileDone) return '/publisher/profile';
    if (!clinicVerified && !isPending) return '/publisher/verify-business';
    if (isPending) return '/publisher/pending';
    return '/publisher/done';
  }
}

/// 게시자 관련 Firestore 서비스
///
/// **Deprecated**: 새 플로우에서는 [ClinicAuthService] + [ClinicProfileService]를 사용합니다.
/// 이 클래스는 레거시 온보딩 페이지 호환용으로만 유지됩니다.
@Deprecated('Use ClinicAuthService + ClinicProfileService instead')
class PublisherService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  // ── 상태 조회 ─────────────────────────────────────────
  static Future<PublisherStatus> getStatus() async {
    final uid = _uid;
    if (uid == null) return const PublisherStatus();
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return const PublisherStatus();
    return PublisherStatus.fromMap(doc.data()!);
  }

  static Stream<PublisherStatus> watchStatus() {
    final uid = _uid;
    if (uid == null) return Stream.value(const PublisherStatus());
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map(
          (doc) =>
              doc.exists
                  ? PublisherStatus.fromMap(doc.data()!)
                  : const PublisherStatus(),
        );
  }

  // ── 초기 게시자 역할 설정 ──────────────────────────────
  static Future<void> initPublisherRole() async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'role': 'publisher',
      'email': _auth.currentUser?.email ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'phoneVerified': false,
      'clinicVerified': false,
      'onboarding': {
        'phone': 'pending',
        'profile': 'pending',
        'business': 'pending',
      },
    }, SetOptions(merge: true));
  }

  // ── 기본 정보 저장 ────────────────────────────────────
  static Future<void> saveProfile({
    required String name,
    required String position,
    required String clinicNameDraft,
    required String phone,
    required String contactEmail,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({
      'publisherProfile': {
        'name': name,
        'position': position,
        'clinicNameDraft': clinicNameDraft,
        'phone': phone,
        'contactEmail': contactEmail,
      },
      'onboarding.profile': 'done',
    });
  }

  // ── 휴대폰 인증 완료 처리 ─────────────────────────────
  static Future<void> markPhoneVerified(String phone) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({
      'phoneVerified': true,
      'phone': phone,
      'onboarding.phone': 'done',
    });
  }
}


