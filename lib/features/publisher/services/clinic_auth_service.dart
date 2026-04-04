import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 공고자(치과) 마스터 계정 상태 모델
///
/// 판별 기준: `clinics_accounts/{uid}` 문서 존재 여부 + 인증/권한 상태
class ClinicStatus {
  final bool exists;

  // ── 새 플로우 필드 ──
  /// 본인인증 완료 여부 (토스 본인확인 / Firebase OTP fallback)
  final bool identityVerified;

  /// 본인인증 방식 ('toss' | 'firebase' | null)
  final String? identityMethod;

  /// 프로필(치과) 마이그레이션 완료
  final bool profilesMigrated;

  // ── 레거시 호환 필드 (기존 코드 참조용, 점진 제거 예정) ──
  @Deprecated('새 플로우에서는 identityVerified 사용')
  final bool phoneVerified;
  @Deprecated('새 플로우에서는 clinic_profiles 서브컬렉션 사용')
  final bool profileDone;
  @Deprecated('새 플로우에서는 clinic_profiles.businessVerification 사용')
  final bool clinicVerified;
  @Deprecated('새 플로우에서는 개별 프로필 인증 상태로 판별')
  final bool isPending;
  @Deprecated('새 플로우에서는 결제 기반 게시 전환')
  final String approvalStatus;
  @Deprecated('새 플로우에서는 결제 완료 시 서버가 jobs 생성')
  final bool canPost;

  const ClinicStatus({
    this.exists = false,
    this.identityVerified = false,
    this.identityMethod,
    this.profilesMigrated = false,
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
    // identityVerified: 새 필드 우선, 없으면 기존 phoneVerified fallback
    final identity = data['identityVerified'] as bool?
        ?? data['phoneVerified'] as bool?
        ?? false;
    return ClinicStatus(
      exists: true,
      identityVerified: identity,
      identityMethod: data['identityMethod'] as String?,
      profilesMigrated: data['profilesMigrated'] as bool? ?? false,
      // 레거시
      phoneVerified: data['phoneVerified'] as bool? ?? false,
      profileDone: onboarding['profile'] == 'done',
      clinicVerified: data['clinicVerified'] as bool? ?? false,
      isPending: approval == 'pending' || onboarding['business'] == 'pending',
      approvalStatus: approval,
      canPost: data['canPost'] as bool? ?? false,
    );
  }

  /// 레거시 호환: 기존 라우터/로그인 로직에서 아직 참조 중
  @Deprecated('새 플로우에서는 사용하지 않음')
  bool get isApprovedAndCanPost =>
      approvalStatus == 'approved' && canPost;

  /// 레거시 호환: 기존 온보딩 라우트 판정
  @Deprecated('새 플로우에서는 사용하지 않음')
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

  /// 위생사(지원자) 로그인 경로에서 치과(공고자) 계정을 막을 때 사용하는 안내 문구
  static const String applicantLoginBlockedMessage =
      '이 계정은 치과(공고자) 전용으로 등록되어 있어\n'
      '위생사 앱·지원자 로그인으로는 이용할 수 없습니다.\n\n'
      '공고·채용 이용은 웹의 치과(공고자) 로그인을 이용해 주세요.\n\n'
      '※ 직전에 로그인을 여러 번 시도하셨다면\n'
      '   1~2분 후 웹 치과 로그인을 시도해주세요.\n'
      '   (Firebase가 반복 시도를 일시적으로 차단할 수 있어요)';

  static String? get _uid => _auth.currentUser?.uid;

  /// 지원자 로그인 직후 호출. `clinics_accounts`가 있으면 로그아웃하고 차단 사유 문자열 반환.
  /// Firestore 오류 시에도 확인 불가이므로 로그아웃 후 안내 반환.
  static Future<String?> blockClinicAccountFromApplicantLogin() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final doc = await _db.collection(_collection).doc(uid).get();
      if (!doc.exists) return null;
      await _auth.signOut();
      return applicantLoginBlockedMessage;
    } catch (e) {
      debugPrint('⚠️ blockClinicAccountFromApplicantLogin: $e');
      try {
        await _auth.signOut();
      } catch (_) {}
      return '로그인 확인 중 오류가 발생했어요. 잠시 후 다시 시도해주세요.';
    }
  }

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

  // ── 초기 공고자 마스터 계정 생성 ─────────────────────

  /// 마스터 문서만 생성. 치과 정보는 clinic_profiles에서 별도 관리.
  static Future<void> initClinicAccount() async {
    final uid = _uid;
    if (uid == null) return;

    final email = _auth.currentUser?.email ?? '';
    final normalizedEmail = email.trim().toLowerCase();

    await _db.collection(_collection).doc(uid).set({
      'email': email,
      'normalizedEmail': normalizedEmail,
      // 새 플로우 필드
      'identityVerified': false,
      'profilesMigrated': false,
      // 레거시 호환 (기존 라우터·관리자 대시보드가 참조)
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

    debugPrint('✅ ClinicAuthService: clinics_accounts/$uid 마스터 문서 생성');
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

  // ── 본인인증 완료 기록 (서버에서 호출 권장, 클라이언트 fallback) ──

  /// 본인인증 완료 시 마스터 문서 갱신
  static Future<void> markIdentityVerified({
    required String method,
    required String verifiedName,
    required String verifiedPhone,
    String? ci,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection(_collection).doc(uid).update({
      'identityVerified': true,
      'identityMethod': method,
      'verifiedName': verifiedName,
      'verifiedPhone': verifiedPhone,
      if (ci != null) 'ci': ci,
      // 레거시 호환
      'phoneVerified': true,
      'phone': verifiedPhone,
      'onboarding.phone': 'done',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
