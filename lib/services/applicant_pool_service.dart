import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/applicant_pool_entry.dart';
import '../models/application.dart';
import '../models/resume.dart';

/// 인재풀 서비스 — 운영자(병원) 입장에서 본인 지점에 지원한 사람들을 모아본다.
///
/// 정책 결정사항(2026-04):
///   1. **지점별 분리**: branchId 단위 — 현재 데이터 구조상 1계정=1지점이
///      기본이지만, 나중에 다지점이 도입되어 jobs 에 profileId 가 추가되면
///      자연스럽게 확장된다. 지금은 `branchId == 본인 uid` 가 유일한 지점.
///   2. **수동 등록 (favorite-only)**: 풀 등록은 운영자가 ⭐을 눌러야 발생
///      — `setFavorite(uid, branchId, true)` 가 곧 풀 등록.
///   3. **이메일 재알림만**: 재알림 채널은 1차 이메일만 (Cloud Functions
///      `notifyPastApplicant` 가 이메일 큐에 적재).
///
/// 저장 위치:
///   `clinics_accounts/{ownerUid}/branches/{branchId}/applicantPool/{applicantUid}`
class ApplicantPoolService {
  ApplicantPoolService._();

  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static final _fns =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  static String? get _uid => _auth.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> _poolCol(
    String ownerUid,
    String branchId,
  ) =>
      _db
          .collection('clinics_accounts')
          .doc(ownerUid)
          .collection('branches')
          .doc(branchId)
          .collection('applicantPool');

  // ──────────────────────────────────────────────────────
  // 조회 — 합본 ViewModel
  // ──────────────────────────────────────────────────────

  /// 한 지점의 지원자 합본 스트림 (지원이력 + 풀엔트리 + 캐시 프로필)
  ///
  /// [branchId] 동작:
  ///   - 값이 주어지면 → 그 지점만 조회 (단일 지점 모드)
  ///   - null 이면 → 본인 소유의 **모든 지점을 fan-out 으로 합산** (전체 보기)
  ///
  /// 합산 모드에서는 같은 지원자가 두 지점에 지원했더라도 **지점별로 별개 row**
  /// 로 노출한다 (`applicantUid + branchId` 가 사실상 키). 이유:
  ///   1. 풀 엔트리(즐겨찾기/메모/태그)는 지점 단위로 따로 저장되므로,
  ///      "어느 지점의 즐겨찾기인지" 가 row 마다 명확해야 한다.
  ///   2. 운영자가 합산 화면에서 ⭐ / 메모를 편집할 때 의도와 어긋나는 지점에
  ///      쓰여 데이터가 섞이는 것을 막는다.
  ///   3. 같은 사람이 여러 지점에 지원한 사실 자체가 중요한 운영 정보이다.
  static Stream<List<JoinedApplicant>> watchJoinedApplicants({
    String? branchId,
    String? ownerUid,
  }) {
    final uid = ownerUid ?? _uid;
    if (uid == null) return Stream.value(const []);

    if (branchId != null) {
      return _watchSingleBranch(ownerUid: uid, branchId: branchId);
    }
    return _watchAllBranches(ownerUid: uid);
  }

  /// 단일 지점 합본 스트림.
  static Stream<List<JoinedApplicant>> _watchSingleBranch({
    required String ownerUid,
    required String branchId,
  }) {
    final appsStream = _db
        .collection('applications')
        .where('clinicId', isEqualTo: branchId)
        .orderBy('submittedAt', descending: true)
        .snapshots();

    final poolStream = _poolCol(ownerUid, branchId).snapshots();

    return _combineLatest2<QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>>(appsStream, poolStream)
        .asyncMap((tuple) async {
      final appsSnap = tuple.$1;
      final poolSnap = tuple.$2;

      final apps = appsSnap.docs.map(Application.fromDoc).toList();
      final pools = <String, ApplicantPoolEntry>{};
      for (final d in poolSnap.docs) {
        pools[d.id] = ApplicantPoolEntry.fromMap(
          d.data(),
          applicantUid: d.id,
          branchId: branchId,
        );
      }

      final jobIds =
          apps.map((a) => a.jobId).where((s) => s.isNotEmpty).toSet();
      final jobTitles = await _fetchJobTitles(jobIds);

      return _assembleForBranch(
        branchId: branchId,
        apps: apps,
        pools: pools,
        jobTitles: jobTitles,
      )..sort(_compareJoined);
    });
  }

  /// 본인 소유의 모든 지점을 동적으로 구독해서 합산하는 스트림.
  ///
  /// `clinic_profiles` 자체가 변할 수도 있으므로(지점 추가/삭제) 그 변화를
  /// 감지하면 하위 구독을 재구성한다.
  static Stream<List<JoinedApplicant>> _watchAllBranches({
    required String ownerUid,
  }) {
    final profilesStream = _db
        .collection('clinics_accounts')
        .doc(ownerUid)
        .collection('clinic_profiles')
        .snapshots();

    late StreamController<List<JoinedApplicant>> ctrl;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? profilesSub;
    final perBranchSubs = <String, StreamSubscription<List<JoinedApplicant>>>{};
    final latestPerBranch = <String, List<JoinedApplicant>>{};

    void emit() {
      // 모든 지점의 가장 최근 결과를 평탄화 + 정렬해서 한 리스트로.
      final merged = <JoinedApplicant>[];
      for (final list in latestPerBranch.values) {
        merged.addAll(list);
      }
      merged.sort(_compareJoined);
      ctrl.add(merged);
    }

    Future<void> cancelAllBranches() async {
      for (final sub in perBranchSubs.values) {
        await sub.cancel();
      }
      perBranchSubs.clear();
      latestPerBranch.clear();
    }

    ctrl = StreamController<List<JoinedApplicant>>.broadcast(
      onListen: () {
        profilesSub = profilesStream.listen(
          (snap) {
            final currentIds = snap.docs.map((d) => d.id).toSet();

            // 사라진 지점은 구독 해제 + 결과에서 제거
            final gone = perBranchSubs.keys
                .where((id) => !currentIds.contains(id))
                .toList();
            for (final id in gone) {
              perBranchSubs.remove(id)?.cancel();
              latestPerBranch.remove(id);
            }

            // 새로 추가된 지점은 구독 시작
            for (final id in currentIds) {
              if (perBranchSubs.containsKey(id)) continue;
              perBranchSubs[id] = _watchSingleBranch(
                ownerUid: ownerUid,
                branchId: id,
              ).listen(
                (list) {
                  latestPerBranch[id] = list;
                  emit();
                },
                onError: ctrl.addError,
              );
            }

            // 지점이 0개면 빈 리스트라도 한 번 emit (로딩 무한 방지)
            if (currentIds.isEmpty) {
              ctrl.add(const []);
            }
          },
          onError: ctrl.addError,
        );
      },
      onCancel: () async {
        await profilesSub?.cancel();
        profilesSub = null;
        await cancelAllBranches();
      },
    );
    return ctrl.stream;
  }

  /// 한 지점의 apps/pools 를 [JoinedApplicant] 리스트로 조립.
  static List<JoinedApplicant> _assembleForBranch({
    required String branchId,
    required List<Application> apps,
    required Map<String, ApplicantPoolEntry> pools,
    required Map<String, String> jobTitles,
  }) {
    final grouped = <String, List<Application>>{};
    for (final a in apps) {
      grouped.putIfAbsent(a.applicantUid, () => <Application>[]).add(a);
    }
    final allUids = <String>{...grouped.keys, ...pools.keys};

    final out = <JoinedApplicant>[];
    for (final auid in allUids) {
      final myApps = grouped[auid] ?? const <Application>[];
      final pool = pools[auid];

      final joinedApps = myApps
          .map((a) => JoinedApplication(
                applicationId: a.id,
                jobId: a.jobId,
                jobTitle: jobTitles[a.jobId],
                submittedAt: a.submittedAt,
                status: a.status.name,
                resumeId: a.resumeId,
              ))
          .toList();

      out.add(JoinedApplicant(
        applicantUid: auid,
        branchId: branchId,
        applications: joinedApps,
        displayName: pool?.displayName ?? '',
        pool: pool,
      ));
    }
    return out;
  }

  /// 정렬: 즐겨찾기 → 마지막 지원일 desc → uid → branchId
  static int _compareJoined(JoinedApplicant a, JoinedApplicant b) {
    if (a.isFavorite != b.isFavorite) {
      return a.isFavorite ? -1 : 1;
    }
    final ad = a.lastAppliedAt;
    final bd = b.lastAppliedAt;
    if (ad != null && bd != null) {
      final cmp = bd.compareTo(ad);
      if (cmp != 0) return cmp;
    } else if (ad == null && bd != null) {
      return 1;
    } else if (ad != null && bd == null) {
      return -1;
    }
    final uidCmp = a.applicantUid.compareTo(b.applicantUid);
    if (uidCmp != 0) return uidCmp;
    return a.branchId.compareTo(b.branchId);
  }

  static Future<Map<String, String>> _fetchJobTitles(
      Set<String> jobIds) async {
    if (jobIds.isEmpty) return const {};
    final result = <String, String>{};
    final list = jobIds.toList();
    // Firestore whereIn 한 번에 30개 제한
    for (var i = 0; i < list.length; i += 30) {
      final chunk = list.sublist(i, (i + 30).clamp(0, list.length));
      try {
        final snap = await _db
            .collection('jobs')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final d in snap.docs) {
          result[d.id] = (d.data()['title'] as String?) ?? '';
        }
      } catch (e) {
        debugPrint('⚠️ ApplicantPoolService._fetchJobTitles: $e');
      }
    }
    return result;
  }

  // ──────────────────────────────────────────────────────
  // 지원자 상세 — 이력서 readonly
  // ──────────────────────────────────────────────────────

  /// 지원자의 이력서 읽기 (rules 상 본인 only 라서 server-side mirror가 필요할 수
  /// 있음 — 1차에서는 시도하고 실패 시 안내).
  static Future<Resume?> tryReadResume(String resumeId) async {
    if (resumeId.isEmpty) return null;
    try {
      final doc = await _db.collection('resumes').doc(resumeId).get();
      if (!doc.exists) return null;
      return Resume.fromMap(doc.data()!, id: doc.id);
    } catch (e) {
      debugPrint('⚠️ ApplicantPoolService.tryReadResume: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────
  // CRUD — 풀 엔트리
  // ──────────────────────────────────────────────────────

  /// ⭐ 토글 — 처음 ⭐ 누르면 자동으로 풀에 등록된다.
  static Future<void> setFavorite({
    required String applicantUid,
    required bool value,
    String? branchId,
    String? displayName,
    DateTime? lastAppliedAt,
    List<String>? applicationIds,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final bid = branchId ?? uid;
    final ref = _poolCol(uid, bid).doc(applicantUid);

    final snap = await ref.get();
    if (!snap.exists) {
      // 신규 풀 등록
      final entry = ApplicantPoolEntry(
        applicantUid: applicantUid,
        branchId: bid,
        displayName: displayName ?? '',
        firstSeenAt: lastAppliedAt,
        lastAppliedAt: lastAppliedAt,
        applicationIds: applicationIds ?? const [],
        isFavorite: value,
      );
      await ref.set({
        ...entry.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.update({
        'isFavorite': value,
        if (displayName != null && displayName.isNotEmpty)
          'displayName': displayName,
        if (lastAppliedAt != null)
          'lastAppliedAt': Timestamp.fromDate(lastAppliedAt),
        if (applicationIds != null) 'applicationIds': applicationIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// 메모/태그/상태 일괄 업데이트
  static Future<void> updateMeta({
    required String applicantUid,
    String? branchId,
    String? memo,
    List<String>? tags,
    String? status,
    String? displayName,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final bid = branchId ?? uid;
    final ref = _poolCol(uid, bid).doc(applicantUid);

    final snap = await ref.get();
    final patch = <String, dynamic>{
      if (memo != null) 'memo': memo,
      if (tags != null) 'tags': tags,
      if (status != null) 'status': status,
      if (displayName != null) 'displayName': displayName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!snap.exists) {
      // 풀에 처음 들어옴 — favorite=false 로 시작
      final entry = ApplicantPoolEntry(
        applicantUid: applicantUid,
        branchId: bid,
        displayName: displayName ?? '',
        memo: memo ?? '',
        tags: tags ?? const [],
        status: status ?? 'new',
      );
      await ref.set({
        ...entry.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.update(patch);
    }
  }

  /// 풀에서 제거 (지원이력 자체는 그대로)
  static Future<void> removeFromPool({
    required String applicantUid,
    String? branchId,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final bid = branchId ?? uid;
    await _poolCol(uid, bid).doc(applicantUid).delete();
  }

  // ──────────────────────────────────────────────────────
  // 재알림 — Callable 호출
  // ──────────────────────────────────────────────────────

  /// 과거 지원자에게 새 공고 알림 이메일 큐 적재
  ///
  /// [applicantUids] 대상자들의 uid 목록 (지점 내)
  /// [jobId] 알릴 공고 ID
  /// [message] 운영자가 추가로 적은 메모(optional)
  static Future<int> notifyPastApplicants({
    required List<String> applicantUids,
    required String jobId,
    String? message,
    String? branchId,
  }) async {
    final uid = _uid;
    if (uid == null) return 0;
    final bid = branchId ?? uid;
    if (applicantUids.isEmpty) return 0;

    try {
      final callable = _fns.httpsCallable('notifyPastApplicant');
      final res = await callable.call(<String, dynamic>{
        'branchId': bid,
        'jobId': jobId,
        'applicantUids': applicantUids,
        if (message != null) 'message': message,
      });
      final data = (res.data as Map?) ?? const {};
      return (data['queued'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('⚠️ notifyPastApplicants: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────
  // 내부 — 두 스트림 결합
  // ──────────────────────────────────────────────────────

  static Stream<({A $1, B $2})> _combineLatest2<A, B>(
    Stream<A> a,
    Stream<B> b,
  ) {
    // broadcast 컨트롤러 — 부모 위젯 리빌드로 StreamBuilder 가 같은 stream 을
    // 두 번 listen 하려 해도 "Bad state: Stream has already been listened to."
    // 가 발생하지 않는다. Firestore .snapshots() 자체가 broadcast 라 두 source
    // 도 broadcast 인 게 자연스럽다.
    late StreamController<({A $1, B $2})> ctrl;
    A? lastA;
    B? lastB;
    var hasA = false;
    var hasB = false;
    StreamSubscription<A>? subA;
    StreamSubscription<B>? subB;

    void emit() {
      if (hasA && hasB) {
        ctrl.add(($1: lastA as A, $2: lastB as B));
      }
    }

    ctrl = StreamController<({A $1, B $2})>.broadcast(
      onListen: () {
        // 첫 listener 가 붙는 시점에만 source 구독 시작
        subA ??= a.listen(
          (v) {
            lastA = v;
            hasA = true;
            emit();
          },
          onError: ctrl.addError,
        );
        subB ??= b.listen(
          (v) {
            lastB = v;
            hasB = true;
            emit();
          },
          onError: ctrl.addError,
        );
      },
      onCancel: () async {
        // 마지막 listener 가 떨어지면 source 도 해제 (메모리 누수 방지)
        await subA?.cancel();
        await subB?.cancel();
        subA = null;
        subB = null;
        hasA = false;
        hasB = false;
      },
    );
    return ctrl.stream;
  }
}
