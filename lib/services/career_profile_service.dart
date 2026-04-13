import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'career_network_dedupe_helper.dart';

class CareerProfileService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// [watchNetworkEntries] 구독 시 과도한 Firestore 호출 방지 (분 단위)
  static final Map<String, DateTime> _lastNetworkMergeAt = {};

  static String? get _uid => _auth.currentUser?.uid;

  static DocumentReference<Map<String, dynamic>>? get _userRef {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  static Stream<Map<String, dynamic>?> watchMyCareerProfile() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return const Stream.empty();
      return _db
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map(
            (snap) => snap.data()?['careerProfile'] as Map<String, dynamic>?,
          );
    });
  }

  static Future<Map<String, dynamic>?> getMyCareerProfile() async {
    try {
      final ref = _userRef;
      if (ref == null) return null;
      final snap = await ref.get();
      return snap.data()?['careerProfile'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('⚠️ CareerProfileService.getMyCareerProfile error: $e');
      return null;
    }
  }

  // ── 스킬 마스터 리스트 (앱 상수) ──
  // 이력서 임상스킬(_clinicalPresets) + 소프트스킬(_softPresets)과 동일하게 유지
  static const skillMaster = <Map<String, dynamic>>[
    // ── 임상 스킬 ──
    {'id': 'scaling',        'title': '스케일링',          'icon': 'cleaning_services'},
    {'id': 'perio',          'title': '치주 관리',          'icon': 'favorite'},
    {'id': 'fluoride',       'title': '불소도포',           'icon': 'water_drop'},
    {'id': 'xray',           'title': '방사선 촬영',        'icon': 'radio'},
    {'id': 'prostho',        'title': '인상 채득',          'icon': 'handyman'},
    {'id': 'denture_imp',    'title': '덴처임프',           'icon': 'denture_imp'},
    {'id': 'temp_crown',     'title': '임시치아 제작',      'icon': 'build_circle'},
    {'id': 'ortho',          'title': '교정 와이어 교체',   'icon': 'architecture'},
    {'id': 'implant',        'title': '임플란트 보조',      'icon': 'build'},
    {'id': 'endo',           'title': '근관치료 보조',      'icon': 'medical_services'},
    {'id': 'pediatric',      'title': '소아 진료 보조',     'icon': 'child_care'},
    {'id': 'resin',          'title': '레진/실란트',        'icon': 'colorize'},
    {'id': 'whitening',      'title': '치아미백',           'icon': 'auto_awesome'},
    {'id': 'scanner',        'title': '구강스캐너',         'icon': 'document_scanner'},
    {'id': 'photo',          'title': '구내,구외 포토',     'icon': 'photo_camera'},
    // ── 소프트 스킬 ──
    {'id': 'consult',        'title': '환자 상담',          'icon': 'chat_bubble'},
    {'id': 'insurance',      'title': '보험청구',           'icon': 'receipt_long'},
    {'id': 'chart',          'title': '차트 관리',          'icon': 'description'},
    {'id': 'sterile',        'title': '감염 관리',          'icon': 'sanitizer'},
    {'id': 'inventory',      'title': '재고 관리',          'icon': 'inventory'},
    {'id': 'leadership',     'title': '팀 리더십',          'icon': 'groups'},
    {'id': 'training',       'title': '신규 직원 교육',     'icon': 'school'},
    {'id': 'reception',      'title': '고객 CS',            'icon': 'phone'},
  ];

  static Future<Map<String, Map<String, dynamic>>> getMySkills() async {
    try {
      final profile = await getMyCareerProfile();
      final raw = profile?['skills'] as Map<String, dynamic>? ?? {};
      return raw.map(
        (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
      );
    } catch (e) {
      debugPrint('⚠️ CareerProfileService.getMySkills error: $e');
      return {};
    }
  }

  static Stream<Map<String, Map<String, dynamic>>> watchMySkills() {
    return watchMyCareerProfile().map((profile) {
      final raw = profile?['skills'] as Map<String, dynamic>? ?? {};
      return raw.map(
        (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
      );
    });
  }

  static Future<void> updateSkill({
    required String skillId,
    required bool enabled,
    int? level,
  }) async {
    try {
      final ref = _userRef;
      if (ref == null) throw Exception('로그인이 필요합니다.');
      final data = <String, dynamic>{
        'enabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (level != null) data['level'] = level;
      await ref.set({
        'careerProfile': {
          'skills': {skillId: data},
        },
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ CareerProfileService.updateSkill error: $e');
      rethrow;
    }
  }

  /// 커스텀 스킬의 title을 Firestore에 저장 (skillMaster에 없는 직접 입력 스킬)
  static Future<void> updateSkillTitle({
    required String skillId,
    required String title,
  }) async {
    try {
      final ref = _userRef;
      if (ref == null) throw Exception('로그인이 필요합니다.');
      await ref.set({
        'careerProfile': {
          'skills': {
            skillId: {'title': title},
          },
        },
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ CareerProfileService.updateSkillTitle error: $e');
      rethrow;
    }
  }

  /// enabled 여부만 일괄 저장 (레벨 없이 체크 여부만 관리)
  static Future<void> updateAllSkillsEnabled(
    Map<String, Map<String, dynamic>> skillsMap,
  ) async {
    try {
      final ref = _userRef;
      if (ref == null) throw Exception('로그인이 필요합니다.');
      final skillsPayload = skillsMap.map(
        (id, entry) => MapEntry(id, {
          'enabled': entry['enabled'] as bool,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );
      await ref.set({
        'careerProfile': {'skills': skillsPayload},
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ CareerProfileService.updateAllSkillsEnabled error: $e');
      rethrow;
    }
  }

  /// 여러 스킬을 한 번의 Firestore 쓰기로 일괄 저장 (하위 호환 유지)
  static Future<void> updateAllSkills(
    Map<String, Map<String, dynamic>> skillsMap,
  ) async {
    try {
      final ref = _userRef;
      if (ref == null) throw Exception('로그인이 필요합니다.');

      // 전체 스킬 맵을 한 번에 merge write
      final skillsPayload = skillsMap.map(
        (id, entry) => MapEntry(id, {
          'enabled': entry['enabled'] as bool,
          'level': entry['level'] as int,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );

      await ref.set({
        'careerProfile': {'skills': skillsPayload},
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ CareerProfileService.updateAllSkills error: $e');
      rethrow;
    }
  }

  // ── 치과 히스토리 (careerNetwork 컬렉션) ───────────────────
  static CollectionReference<Map<String, dynamic>>? get _networkRef {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('careerNetwork');
  }

  static Stream<List<DentalNetworkEntry>> watchNetworkEntries() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return const Stream.empty();
      unawaited(
        Future(() async {
          try {
            final now = DateTime.now();
            final last = _lastNetworkMergeAt[user.uid];
            if (last != null &&
                now.difference(last) < const Duration(minutes: 3)) {
              return;
            }
            _lastNetworkMergeAt[user.uid] = now;
            await CareerNetworkDedupeHelper.mergeSimilarNetworkEntries(
              _db.collection('users').doc(user.uid).collection('careerNetwork'),
            );
          } catch (e) {
            debugPrint('⚠️ CareerProfileService network dedupe: $e');
          }
        }),
      );
      return _db
          .collection('users')
          .doc(user.uid)
          .collection('careerNetwork')
          .orderBy('startDate', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map(DentalNetworkEntry.fromDoc).toList());
    });
  }

  static Future<void> addNetworkEntry(DentalNetworkEntry entry) async {
    final ref = _networkRef;
    if (ref == null) throw Exception('로그인이 필요합니다.');
    await ref.add({
      ...entry.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateNetworkEntry(DentalNetworkEntry entry) async {
    final ref = _networkRef;
    if (ref == null) throw Exception('로그인이 필요합니다.');
    await ref.doc(entry.id).update({
      ...entry.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteNetworkEntry(String entryId) async {
    final ref = _networkRef;
    if (ref == null) throw Exception('로그인이 필요합니다.');
    await ref.doc(entryId).delete();
  }

  /// `syncedFromResume == true`인 치과 히스토리 행만 일괄 삭제 (이력서 추출로 쌓인 줄만 비움)
  static Future<int> deleteAllSyncedFromResumeNetworkEntries() async {
    final ref = _networkRef;
    if (ref == null) throw Exception('로그인이 필요합니다.');
    final snap = await ref.where('syncedFromResume', isEqualTo: true).get();
    final docs = snap.docs;
    if (docs.isEmpty) return 0;

    const chunk = 450;
    for (var i = 0; i < docs.length; i += chunk) {
      final batch = _db.batch();
      final end = i + chunk > docs.length ? docs.length : i + chunk;
      for (var j = i; j < end; j++) {
        batch.delete(docs[j].reference);
      }
      await batch.commit();
    }
    return docs.length;
  }

  static Future<void> updateCareerIdentity({
    required String status, // 'employed' | 'leave' | 'unemployed'
    String clinicName = '',
    DateTime? currentStartDate,
    List<String> specialtyTags = const [],
    bool useTotalCareerMonthsOverride = false,
    int? totalCareerMonthsOverride,
    /// true: 총 경력 직접 입력 사용 중 — 프로필 연차 저장 시 덮어쓰지 않음(연차 변경 시만 동기화).
    bool? careerOverrideLocked,
  }) async {
    try {
      final ref = _userRef;
      if (ref == null) throw Exception('로그인이 필요합니다.');

      final identityPayload = <String, dynamic>{
        'status': status,
        'clinicName': clinicName.trim(),
        'currentStartDate':
            currentStartDate != null
                ? Timestamp.fromDate(currentStartDate)
                : null,
        'specialtyTags': specialtyTags,
        'useTotalCareerMonthsOverride': useTotalCareerMonthsOverride,
        'totalCareerMonthsOverride': totalCareerMonthsOverride,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (careerOverrideLocked != null) {
        identityPayload['careerOverrideLocked'] = careerOverrideLocked;
      }

      await ref.set({
        'careerProfile': {'identity': identityPayload},
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ CareerProfileService.updateCareerIdentity error: $e');
      rethrow;
    }
  }
}

class DentalNetworkEntry {
  final String id;
  final String clinicName;
  final DateTime startDate;
  final DateTime? endDate; // null = 현재 재직 중
  final List<String> tags;
  final List<String> acquiredSkills;

  /// 이력서 저장 시 자동 동기화로 생성·갱신된 항목
  final bool syncedFromResume;

  DentalNetworkEntry({
    this.id = '',
    required this.clinicName,
    required this.startDate,
    this.endDate,
    this.tags = const [],
    this.acquiredSkills = const [],
    this.syncedFromResume = false,
  });

  bool get isCurrent => endDate == null;

  int get months {
    final end = endDate ?? DateTime.now();
    final m = (end.year - startDate.year) * 12 + (end.month - startDate.month);
    return m < 1 ? 1 : m;
  }

  /// `YYYY.MM` 단위 — 연도만이 아니라 월까지 보여 검증·중복 확인에 유리
  String get periodLabel {
    String ym(DateTime d) =>
        '${d.year}.${d.month.toString().padLeft(2, '0')}';
    final s = ym(startDate);
    if (endDate == null) return '$s ~ 현재';
    final e = ym(endDate!);
    return '$s ~ $e';
  }

  DentalNetworkEntry copyWith({
    String? id,
    String? clinicName,
    DateTime? startDate,
    Object? endDate = _sentinel,
    List<String>? tags,
    List<String>? acquiredSkills,
    bool? syncedFromResume,
  }) {
    return DentalNetworkEntry(
      id: id ?? this.id,
      clinicName: clinicName ?? this.clinicName,
      startDate: startDate ?? this.startDate,
      endDate: endDate == _sentinel ? this.endDate : endDate as DateTime?,
      tags: tags ?? this.tags,
      acquiredSkills: acquiredSkills ?? this.acquiredSkills,
      syncedFromResume: syncedFromResume ?? this.syncedFromResume,
    );
  }

  factory DentalNetworkEntry.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data()!;
    return DentalNetworkEntry(
      id: doc.id,
      clinicName: d['clinicName'] as String? ?? '',
      startDate: (d['startDate'] as Timestamp).toDate(),
      endDate: (d['endDate'] as Timestamp?)?.toDate(),
      tags: List<String>.from(d['tags'] as List? ?? []),
      acquiredSkills: List<String>.from(d['acquiredSkills'] as List? ?? []),
      syncedFromResume: d['syncedFromResume'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'clinicName': clinicName,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
    'tags': tags,
    'acquiredSkills': acquiredSkills,
    'syncedFromResume': syncedFromResume,
  };
}

// copyWith sentinel
const _sentinel = Object();
