import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 공고자(치과) 계정 상태 모델
///
/// 판별 기준: `clinics_accounts/{uid}` 문서 존재 여부 + 승인 상태
/// (기존 role 문자열 기반 구조 제거)
class ClinicStatus {
  final bool exists;
  final bool phoneVerified;
  final bool profileDone;
  final bool clinicVerified;
  final bool isPending;
  final String approvalStatus; // pending, approved, rejected, suspended
  final bool canPost;

  const ClinicStatus({
    this.exists = false,
    this.phoneVerified = false,
    this.profileDone = false,
    this.clinicVerified = false,
    this.isPending = false,
    this.approvalStatus = 'pending',
    this.canPost = false,
  });

  factory ClinicStatus.fromMap(Map<String, dynamic> data) {
    final onboarding = data['onboarding'] as Map<String, dynamic>? ?? {};
    final approval = data['approvalStatus'] as String? ?? 'pending';
    return ClinicStatus(
      exists: true,
      phoneVerified: data['phoneVerified'] as bool? ?? false,
      profileDone: onboarding['profile'] == 'done',
      clinicVerified: data['clinicVerified'] as bool? ?? false,
      isPending: approval == 'pending' || onboarding['business'] == 'pending',
      approvalStatus: approval,
      canPost: data['canPost'] as bool? ?? false,
    );
  }

  /// 온보딩 완료 + 승인 상태에 따른 공고 작성 가능 여부
  bool get isApprovedAndCanPost =>
      approvalStatus == 'approved' && canPost;

  /// 다음에 가야 할 온보딩 라우트
  String get nextRoute {
    if (!phoneVerified) return '/publisher/verify-phone';
    if (!profileDone) return '/publisher/profile';
    if (!clinicVerified && !isPending) return '/publisher/verify-business';
    if (isPending) return '/publisher/pending';
    return '/publisher/done';
  }
}

/// 공고자(치과) 계정 Firestore 서비스
///
/// 컬렉션: `clinics_accounts/{uid}`
/// 위생사 컬렉션(`users/{uid}`)과 완전 분리
class ClinicAuthService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static const _collection = 'clinics_accounts';

  static String? get _uid => _auth.currentUser?.uid;

  // ── 상태 조회 ─────────────────────────────────────────

  static Future<ClinicStatus> getStatus() async {
    final uid = _uid;
    if (uid == null) return const ClinicStatus();
    final doc = await _db.collection(_collection).doc(uid).get();
    if (!doc.exists) return const ClinicStatus();
    return ClinicStatus.fromMap(doc.data()!);
  }

  static Stream<ClinicStatus> watchStatus() {
    final uid = _uid;
    if (uid == null) return Stream.value(const ClinicStatus());
    return _db
        .collection(_collection)
        .doc(uid)
        .snapshots()
        .map(
          (doc) =>
              doc.exists
                  ? ClinicStatus.fromMap(doc.data()!)
                  : const ClinicStatus(),
        );
  }

  /// 공고자 계정 존재 여부 (uid 기준)
  static Future<bool> isClinicAccount([String? uid]) async {
    final targetUid = uid ?? _uid;
    if (targetUid == null) return false;
    final doc = await _db.collection(_collection).doc(targetUid).get();
    return doc.exists;
  }

  // ── 중복 역할 가입 차단 ────────────────────────────────

  /// 공고자 가입 전 중복 체크
  ///
  /// 같은 uid 또는 같은 normalizedEmail이 `users` 에 이미 존재하면
  /// 위생사 계정으로 가입된 것이므로 공고자 가입 불가.
  /// 반환: null이면 통과, 문자열이면 에러 메시지
  static Future<String?> checkDuplicateForClinicSignup(String email) async {
    final uid = _uid;
    if (uid == null) return '로그인 세션이 만료됐어요. 다시 로그인해주세요.';

    final normalizedEmail = email.trim().toLowerCase();

    // 1) uid 기준: users에 같은 uid 존재 여부
    final userDoc = await _db.collection('users').doc(uid).get();
    if (userDoc.exists) {
      return '이 이메일은 이미 위생사 계정으로 가입되어 있어\n공고자 계정으로 사용할 수 없습니다.\n공고자 가입은 별도의 이메일로 진행해 주세요.';
    }

    // 2) normalizedEmail 기준: users에 같은 이메일 존재 여부
    final emailQuery = await _db
        .collection('users')
        .where('normalizedEmail', isEqualTo: normalizedEmail)
        .limit(1)
        .get();
    if (emailQuery.docs.isNotEmpty) {
      return '이 이메일은 이미 위생사 계정으로 가입되어 있어\n공고자 계정으로 사용할 수 없습니다.\n공고자 가입은 별도의 이메일로 진행해 주세요.';
    }

    return null; // 통과
  }

  /// 위생사 가입 전 중복 체크
  ///
  /// 같은 uid 또는 같은 normalizedEmail이 `clinics_accounts` 에 존재하면
  /// 공고자 계정으로 가입된 것이므로 위생사 가입 불가.
  /// 반환: null이면 통과, 문자열이면 에러 메시지
  static Future<String?> checkDuplicateForApplicantSignup(String email) async {
    final uid = _uid;
    final normalizedEmail = email.trim().toLowerCase();

    // 1) uid 기준
    if (uid != null) {
      final clinicDoc = await _db.collection(_collection).doc(uid).get();
      if (clinicDoc.exists) {
        return '이 계정은 이미 공고자 계정으로 가입되어 있어\n위생사 계정으로 사용할 수 없습니다.\n위생사 가입은 별도의 이메일로 진행해 주세요.';
      }
    }

    // 2) normalizedEmail 기준
    final emailQuery = await _db
        .collection(_collection)
        .where('normalizedEmail', isEqualTo: normalizedEmail)
        .limit(1)
        .get();
    if (emailQuery.docs.isNotEmpty) {
      return '이 이메일은 이미 공고자 계정으로 가입되어 있어\n위생사 계정으로 사용할 수 없습니다.\n위생사 가입은 별도의 이메일로 진행해 주세요.';
    }

    return null; // 통과
  }

  // ── 초기 공고자 계정 생성 ─────────────────────────────

  static Future<void> initClinicAccount() async {
    final uid = _uid;
    if (uid == null) return;

    final email = _auth.currentUser?.email ?? '';
    final normalizedEmail = email.trim().toLowerCase();

    await _db.collection(_collection).doc(uid).set({
      'email': email,
      'normalizedEmail': normalizedEmail,
      'clinicName': '',
      'managerName': '',
      'phone': '',
      'businessNumber': '',
      'approvalStatus': 'pending',
      'canPost': false,
      'phoneVerified': false,
      'clinicVerified': false,
      'onboarding': {
        'phone': 'pending',
        'profile': 'pending',
        'business': 'pending',
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    });

    debugPrint('✅ ClinicAuthService: clinics_accounts/$uid 초기 문서 생성');
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
    await _db.collection(_collection).doc(uid).update({
      'managerName': name,
      'clinicName': clinicNameDraft,
      'phone': phone,
      'publisherProfile': {
        'name': name,
        'position': position,
        'clinicNameDraft': clinicNameDraft,
        'phone': phone,
        'contactEmail': contactEmail,
      },
      'onboarding.profile': 'done',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── 휴대폰 인증 완료 처리 ─────────────────────────────

  static Future<void> markPhoneVerified(String phone) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection(_collection).doc(uid).update({
      'phoneVerified': true,
      'phone': phone,
      'onboarding.phone': 'done',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── 로그인 기록 ───────────────────────────────────────

  static Future<void> recordLogin() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.collection(_collection).doc(uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ ClinicAuthService.recordLogin 실패: $e');
    }
  }
}
