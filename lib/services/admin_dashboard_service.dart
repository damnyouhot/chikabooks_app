import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../core/analytics/event_catalog.dart';
import '../models/admin_dashboard_models.dart';
import '../models/quiz_schedule.dart';
import 'quiz_pool_service.dart';

/// 관리자 대시보드 데이터를 Firestore에서 읽어오는 서비스
///
/// ── 기간 필터 ─────────────────────────────────────────────────
/// [since] 파라미터로 기간을 제한합니다.
/// null이면 전체 기간 데이터를 대상으로 합니다.
/// ──────────────────────────────────────────────────────────────
class AdminDashboardService {
  static final _db = FirebaseFirestore.instance;

  // ─── Callable 응답 정규화 (플랫폼 채널 중첩 `Map<Object?, Object?>` 캐스팅 오류 방지) ───

  static Map<String, dynamic> _deepDecodeCallableMap(Map<dynamic, dynamic> raw) {
    return Map<String, dynamic>.fromEntries(
      raw.entries.map(
        (e) => MapEntry(
          e.key is String ? e.key as String : e.key.toString(),
          _deepDecodeCallableValue(e.value),
        ),
      ),
    );
  }

  static dynamic _deepDecodeCallableValue(dynamic v) {
    if (v == null) return null;
    if (v is Map) {
      return _deepDecodeCallableMap(Map<dynamic, dynamic>.from(v));
    }
    if (v is List) {
      return v.map(_deepDecodeCallableValue).toList();
    }
    return v;
  }

  static Map<String, dynamic>? _mapFromCallableResult(Object? data) {
    if (data is! Map) return null;
    return _deepDecodeCallableMap(Map<dynamic, dynamic>.from(data));
  }

  // ─── Overview ─────────────────────────────────────────────────

  /// 전체 사용자 수 (excludeFromStats 제외, 기간 무관)
  static Future<int> getTotalUserCount() async {
    try {
      final snap = await _db
          .collection('users')
          .where('excludeFromStats', isEqualTo: false)
          .count()
          .get();
      debugPrint('📊 getTotalUserCount: ${snap.count}');
      return snap.count ?? 0;
    } catch (e, st) {
      debugPrint('⚠️ getTotalUserCount 실패: $e');
      debugPrint('⚠️ stack: $st');
      return 0;
    }
  }

  /// 신규 가입자 수 ([since] 이후 createdAt)
  static Future<int> getRecentSignups({required DateTime since}) async {
    try {
      debugPrint('📊 getRecentSignups since=$since');
      final snap = await _db
          .collection('users')
          .where('excludeFromStats', isEqualTo: false)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(since))
          .count()
          .get();
      debugPrint('📊 getRecentSignups result: ${snap.count}');
      return snap.count ?? 0;
    } catch (e, st) {
      debugPrint('❌ getRecentSignups 실패: $e');
      debugPrint('❌ stack: $st');
      // 인덱스 미배포 시 에러 메시지에 "indexes" 포함 → 사용자에게 알림
      if (e.toString().contains('index')) {
        debugPrint('💡 복합 인덱스 배포 필요: (excludeFromStats, createdAt)');
      }
      return 0;
    }
  }

  /// 활성 유저 수 ([since] 이후 lastActiveAt)
  static Future<int> getActiveUserCount({required DateTime since}) async {
    try {
      debugPrint('📊 getActiveUserCount since=$since');
      final snap = await _db
          .collection('users')
          .where('excludeFromStats', isEqualTo: false)
          .where('lastActiveAt', isGreaterThan: Timestamp.fromDate(since))
          .count()
          .get();
      debugPrint('📊 getActiveUserCount result: ${snap.count}');
      return snap.count ?? 0;
    } catch (e, st) {
      debugPrint('❌ getActiveUserCount 실패: $e');
      debugPrint('❌ stack: $st');
      if (e.toString().contains('index')) {
        debugPrint('💡 복합 인덱스 배포 필요: (excludeFromStats, lastActiveAt)');
      }
      return 0;
    }
  }

  /// 장기 미접속 유저 수 (lastActiveAt이 14일 이전, 기간 무관)
  static Future<int> getLongAbsentCount({int days = 14}) async {
    try {
      final before = DateTime.now().subtract(Duration(days: days));
      debugPrint('📊 getLongAbsentCount before=$before');
      final snap = await _db
          .collection('users')
          .where('excludeFromStats', isEqualTo: false)
          .where('lastActiveAt', isLessThan: Timestamp.fromDate(before))
          .count()
          .get();
      debugPrint('📊 getLongAbsentCount result: ${snap.count}');
      return snap.count ?? 0;
    } catch (e, st) {
      debugPrint('❌ getLongAbsentCount 실패: $e');
      debugPrint('❌ stack: $st');
      if (e.toString().contains('index')) {
        debugPrint('💡 복합 인덱스 배포 필요: (excludeFromStats, lastActiveAt)');
      }
      return 0;
    }
  }

  /// 연차별 사용자 분포 (careerBucket 기준, 기간 무관)
  static Future<List<CareerGroupCount>> getCareerGroupDistribution() async {
    const buckets = <(String, String)>[
      ('0-2', '0~2년차'),
      ('3-5', '3~5년차'),
      ('6+', '6년차+'),
    ];
    final result = <CareerGroupCount>[];
    for (final (bucket, _) in buckets) {
      try {
        final snap = await _db
            .collection('users')
            .where('careerBucket', isEqualTo: bucket)
            .where('excludeFromStats', isEqualTo: false)
            .count()
            .get();
        result.add(CareerGroupCount(group: bucket, count: snap.count ?? 0));
      } catch (_) {
        result.add(CareerGroupCount(group: bucket, count: 0));
      }
    }
    return result;
  }

  /// [since] 이후 오류 수
  static Future<int> getRecentErrorCount({required DateTime since}) async {
    try {
      final snap = await _db
          .collection('appErrors')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ getRecentErrorCount: $e');
      return 0;
    }
  }

  // ─── 기록하기(한 줄 기록) KPI & Feed ───────────────────────────

  /// [since] 이후 기록하기(한 줄 기록) 수
  ///
  /// 1번 탭 '기록하기'에서 사용자가 작성한 notes 개수
  static Future<int> getNoteCount({required DateTime since}) async {
    try {
      final snap = await _db
          .collectionGroup('notes')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(since))
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ getNoteCount: $e');
      return 0;
    }
  }

  /// 최근 기록하기(한 줄 기록) 리스트 — 트위터 타임라인 형태
  ///
  /// 1번 탭 '기록하기'에서 작성한 notes를 최신순 [limit]건
  static Future<List<NoteFeedItem>> getRecentNotes({
    int limit = 50,
    DateTime? since,
  }) async {
    try {
      final fetchLimit = since != null ? 200 : limit;
      final snap = await _db
          .collectionGroup('notes')
          .orderBy('createdAt', descending: true)
          .limit(fetchLimit)
          .get();

      var items = snap.docs.map((d) {
        final userId = d.reference.parent.parent?.id ?? '';
        final data = d.data();
        final rawUrls = data['imageUrls'];
        final imageUrls = rawUrls is List
            ? rawUrls.cast<String>()
            : <String>[];
        return NoteFeedItem(
          id: d.id,
          userId: userId,
          text: data['text'] as String? ?? '',
          createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
          imageUrls: imageUrls,
        );
      }).toList();

      if (since != null) {
        items = items
            .where((e) => e.createdAt.isAfter(since))
            .take(limit)
            .toList();
      }
      return items;
    } catch (e, st) {
      debugPrint('⚠️ getRecentNotes: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  // ─── Quiz Pool ────────────────────────────────────────────────

  /// quiz_meta/state 문서 읽기 (1 read)
  static Future<QuizMetaState?> getQuizMetaState() async {
    try {
      // 캐시가 아닌 서버 기준으로 읽어 대시보드 숫자가 최신이 되도록 함
      final doc = await _db.doc('quiz_meta/state').get(
            const GetOptions(source: Source.server),
          );
      if (!doc.exists) return null;
      return QuizMetaState.fromFirestore(doc);
    } catch (e) {
      debugPrint('⚠️ getQuizMetaState: $e');
      return null;
    }
  }

  /// 콘텐츠 운영 허브 스냅샷 (Cloud Function `getContentOpsHub`).
  ///
  /// [schedulePreviewDays]: 오늘(KST) 포함 역방향으로 읽을 `quiz_schedule` 일수 (1~60, 기본 14).
  static Future<Map<String, dynamic>?> getContentOpsHub({
    int schedulePreviewDays = 14,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('getContentOpsHub');
      final result = await callable.call(<String, dynamic>{
        'schedulePreviewDays': schedulePreviewDays,
      });
      return _mapFromCallableResult(result.data);
    } catch (e, st) {
      debugPrint('⚠️ getContentOpsHub: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// 다음 일일 퀴즈 선정 시뮬 (읽기 전용, Cloud Function `previewNextQuizSelection`).
  static Future<Map<String, dynamic>?> previewNextQuizSelection() async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('previewNextQuizSelection');
      final result = await callable.call();
      return _mapFromCallableResult(result.data);
    } catch (e, st) {
      debugPrint('⚠️ previewNextQuizSelection: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// `quiz_schedule` 의 국시/임상 첫 슬롯만 제거 또는 교체 (`adminMutateQuizScheduleSlot`).
  ///
  /// [action]: `remove` | `replace` · [slotType]: `national_exam` | `clinical`
  /// 메타·풀·유저 기록은 변경하지 않음 (스케줄 문서만).
  static Future<Map<String, dynamic>?> adminMutateQuizScheduleSlot({
    String? dateKey,
    required String action,
    required String slotType,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('adminMutateQuizScheduleSlot');
      final payload = <String, dynamic>{
        'action': action,
        'slotType': slotType,
      };
      if (dateKey != null && dateKey.isNotEmpty) {
        payload['dateKey'] = dateKey;
      }
      final result = await callable.call(payload);
      return _mapFromCallableResult(result.data);
    } catch (e, st) {
      debugPrint('⚠️ adminMutateQuizScheduleSlot: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// 진행 중 공감투표를 종료하고 `displayOrder` 기준 다음 미종료 투표를 즉시 진행 (`adminAdvancePollQueue`).
  static Future<Map<String, dynamic>?> adminAdvancePollQueue() async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('adminAdvancePollQueue');
      final result = await callable.call();
      return _mapFromCallableResult(result.data);
    } catch (e, st) {
      debugPrint('⚠️ adminAdvancePollQueue: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// 공감투표 수동 종료 (Cloud Function `manualClosePoll`).
  static Future<Map<String, dynamic>?> manualClosePoll(String pollId) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('manualClosePoll');
      final result = await callable.call(<String, dynamic>{'pollId': pollId});
      return _mapFromCallableResult(result.data);
    } catch (e, st) {
      debugPrint('⚠️ manualClosePoll: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// 공감투표 완전 삭제 — [confirmPollId] 가 [pollId] 와 같아야 함 (`adminDeletePoll`).
  static Future<Map<String, dynamic>?> adminDeletePoll({
    required String pollId,
    required String confirmPollId,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('adminDeletePoll');
      final result = await callable.call(<String, dynamic>{
        'pollId': pollId,
        'confirmPollId': confirmPollId,
      });
      return _mapFromCallableResult(result.data);
    } catch (e, st) {
      debugPrint('⚠️ adminDeletePoll: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// `quiz_meta/state` 의 usedQuizIds·lastScheduledDate 를
  /// 현재 사이클 [quiz_schedule] 과 맞춤 (Cloud Function `rebuildQuizMetaFromSchedules`).
  static Future<Map<String, dynamic>?> rebuildQuizMetaFromSchedules() async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('rebuildQuizMetaFromSchedules');
      final result = await callable.call();
      return _mapFromCallableResult(result.data);
    } catch (e, st) {
      debugPrint('⚠️ rebuildQuizMetaFromSchedules: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// 오늘(또는 [targetDate]) `quiz_schedule` 재생성 — Cloud Function `manualScheduleQuiz`.
  ///
  /// [forceReplace]: true면 기존 해당 날짜 스케줄을 덮어씀.
  /// [targetDate] 미지정 시 KST 기준 오늘 (`QuizPoolService.todayKey`).
  static Future<Map<String, dynamic>?> manualScheduleQuiz({
    String? targetDate,
    bool forceReplace = false,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('manualScheduleQuiz');
      final result = await callable.call(<String, dynamic>{
        'targetDate': targetDate ?? QuizPoolService.todayKey,
        'forceReplace': forceReplace,
      });
      return _mapFromCallableResult(result.data);
    } catch (e, st) {
      debugPrint('⚠️ manualScheduleQuiz: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  // ─── User Flow (퍼널) ─────────────────────────────────────────

  /// 온보딩 **순차 퍼널** 단계별 유저 수 (교집합 집계)
  ///
  /// - 정의: [EventCatalog.onboardingFunnelOrderedSteps] (①~⑤)
  /// - 집계: \(U_1\) = ① 이벤트를 가진 유저, \(U_{k} = U_{k-1} \cap S_k\)
  ///   (\(S_k\) = k번째 이벤트 타입을 **한 번이라도** 가진 유저 집합)
  /// - 기록: ①은 일반 로그, ②~⑤는 계정당 1회 [FunnelOnboardingService] + `isFunnel`
  ///
  /// Firestore는 distinct count 미지원 → 문서 읽어 클라이언트에서 집합 연산.
  ///
  /// [since] 로 기간 제한 (null이면 전체 기간)
  static Future<List<FunnelStep>> getFunnelSteps({DateTime? since}) async {
    final steps = EventCatalog.onboardingFunnelOrderedSteps;
    final result = <FunnelStep>[];
    Set<String>? eligible;

    debugPrint('📊 getFunnelSteps (sequential ∩) since=$since');
    for (final (key, label) in steps) {
      try {
        Query<Map<String, dynamic>> q =
            _db.collection('activityLogs').where('type', isEqualTo: key);
        if (since != null) {
          q = q.where('timestamp', isGreaterThan: Timestamp.fromDate(since));
        }
        final snap = await q.get();
        final stepUsers = <String>{};
        for (final doc in snap.docs) {
          final uid = doc.data()['userId'] as String?;
          if (uid != null && uid.isNotEmpty) stepUsers.add(uid);
        }
        final intersected = eligible == null
            ? stepUsers
            : stepUsers.intersection(eligible);
        eligible = intersected;
        final count = intersected.length;
        debugPrint(
          '📊 funnel [$key]: $count명 (이 단계 raw ${stepUsers.length}, 문서 ${snap.docs.length}건)',
        );
        final prevCount = result.isEmpty ? null : result.last.count;
        final rate = (prevCount != null && prevCount > 0)
            ? count / prevCount
            : null;
        result.add(FunnelStep(label: label, count: count, conversionRate: rate));
      } catch (e, st) {
        debugPrint('❌ funnel [$key] 실패: $e');
        debugPrint('❌ stack: $st');
        if (e.toString().contains('index')) {
          debugPrint('💡 복합 인덱스 배포 필요: activityLogs(type, timestamp)');
        }
        result.add(FunnelStep(label: label, count: 0, conversionRate: null));
        eligible = <String>{};
      }
    }

    return result;
  }

  // ─── Feature Reaction ─────────────────────────────────────────

  /// `같이` 탭: 공감투표를 의미 단위로 합친 뒤 정렬·상위 N에 포함시킵니다.
  ///
  /// - [poll_empathize] + [poll_change_empathy] → [FeatureReactionAggregates.bondPollVote]
  /// - [poll_add_option] → [FeatureReactionAggregates.bondPollAdd] (별도 행)
  static void _mergeBondPollFeatureAggregates(
    Map<String, ({int clicks, Set<String> users})> typeMap,
  ) {
    const voteTypes = <String>['poll_empathize', 'poll_change_empathy'];
    var voteClicks = 0;
    final voteUsers = <String>{};
    for (final t in voteTypes) {
      final p = typeMap.remove(t);
      if (p != null) {
        voteClicks += p.clicks;
        voteUsers.addAll(p.users);
      }
    }
    if (voteClicks > 0) {
      typeMap[FeatureReactionAggregates.bondPollVote] = (
        clicks: voteClicks,
        users: voteUsers,
      );
    }

    final add = typeMap.remove('poll_add_option');
    if (add != null) {
      typeMap[FeatureReactionAggregates.bondPollAdd] = add;
    }
  }

  /// 기능 반응 TOP N
  ///
  /// Firestore group-by 미지원 → 최근 N건 읽어 클라이언트 집계
  /// [since] 로 기간 제한 가능
  ///
  /// 공감투표 관련 타입은 [_mergeBondPollFeatureAggregates] 후 정렬합니다.
  static Future<List<FeatureReactionItem>> getTopFeatures({
    int limit = 12,
    DateTime? since,
  }) async {
    try {
      // isFunnel 필터를 Firestore 쿼리에서 제거 → 클라이언트에서 필터링
      // (기존 문서에 isFunnel 필드 자체가 없어서 isEqualTo: false 매치 불가)
      Query<Map<String, dynamic>> q = _db
          .collection('activityLogs')
          .orderBy('timestamp', descending: true)
          .limit(2000);
      if (since != null) {
        q = _db
            .collection('activityLogs')
            .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
            .orderBy('timestamp', descending: true)
            .limit(2000);
      }
      debugPrint('📊 getTopFeatures: since=$since');
      final snap = await q.get();
      debugPrint('📊 getTopFeatures result: ${snap.docs.length}건');

      final typeMap = <String, ({int clicks, Set<String> users})>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        // 클라이언트에서 퍼널 이벤트 제외
        if (data['isFunnel'] == true) continue;
        final type = data['type'] as String? ?? '';
        final uid = data['userId'] as String? ?? '';
        if (type.isEmpty) continue;
        final prev = typeMap[type];
        if (prev == null) {
          typeMap[type] = (clicks: 1, users: {uid});
        } else {
          typeMap[type] = (
            clicks: prev.clicks + 1,
            users: {...prev.users, uid},
          );
        }
      }

      _mergeBondPollFeatureAggregates(typeMap);

      final items = typeMap.entries
          .map((e) => FeatureReactionItem(
                eventType: e.key,
                label: FeatureReactionItem.labelFor(e.key),
                tab: (e.key == FeatureReactionAggregates.bondPollVote ||
                        e.key == FeatureReactionAggregates.bondPollAdd)
                    ? EventTab.bond
                    : EventCatalog.tabForType(e.key),
                clickCount: e.value.clicks,
                userCount: e.value.users.length,
              ))
          .toList()
        ..sort((a, b) => b.clickCount.compareTo(a.clickCount));

      return items.take(limit).toList();
    } catch (e) {
      debugPrint('⚠️ getTopFeatures: $e');
      return [];
    }
  }

  // ─── Emotion Logs (emotionLogs 컬렉션, 레거시) ─────────────────

  static Future<List<EmotionLogItem>> getRecentEmotionLogs({
    int limit = 50,
    DateTime? since,
  }) async {
    try {
      // where 없이 orderBy만 사용 → 복합 인덱스 없이 동작
      final fetchLimit = since != null ? 200 : limit;
      final snap = await _db
          .collection('emotionLogs')
          .orderBy('timestamp', descending: true)
          .limit(fetchLimit)
          .get();

      var items = snap.docs
          .map((d) => EmotionLogItem.fromMap(d.id, d.data()))
          .toList();

      if (since != null) {
        items = items
            .where((e) => e.timestamp.isAfter(since))
            .take(limit)
            .toList();
      }
      return items;
    } catch (e, st) {
      debugPrint('⚠️ getRecentEmotionLogs: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  // ─── Error Monitor ────────────────────────────────────────────

  /// 최근 오류 리스트 ([since] 필터 포함)
  static Future<List<AppErrorItem>> getRecentErrors({
    int limit = 50,
    DateTime? since,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _db
          .collection('appErrors')
          .orderBy('timestamp', descending: true)
          .limit(limit);
      if (since != null) {
        q = _db
            .collection('appErrors')
            .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
            .orderBy('timestamp', descending: true)
            .limit(limit);
      }
      final snap = await q.get();
      return snap.docs
          .map((d) => AppErrorItem.fromMap(d.id, d.data()))
          .toList();
    } catch (e) {
      debugPrint('⚠️ getRecentErrors: $e');
      return [];
    }
  }

  // ─── Publisher (공고자) KPI ──────────────────────────────────

  /// 전체 공고자 수
  static Future<int> getTotalPublisherCount() async {
    try {
      final snap = await _db.collection('clinics_accounts').count().get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ getTotalPublisherCount: $e');
      return 0;
    }
  }

  /// 신규 공고자 가입 수 ([since] 이후)
  static Future<int> getRecentPublisherSignups({
    required DateTime since,
  }) async {
    try {
      final snap = await _db
          .collection('clinics_accounts')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(since))
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ getRecentPublisherSignups: $e');
      return 0;
    }
  }

  /// 승인 상태별 공고자 수
  static Future<Map<String, int>> getPublisherApprovalCounts() async {
    final result = <String, int>{
      'pending': 0,
      'approved': 0,
      'rejected': 0,
      'suspended': 0,
    };
    for (final status in result.keys.toList()) {
      try {
        final snap = await _db
            .collection('clinics_accounts')
            .where('approvalStatus', isEqualTo: status)
            .count()
            .get();
        result[status] = snap.count ?? 0;
      } catch (_) {}
    }
    return result;
  }

  /// 공고 작성 가능한 공고자 수 (approved + canPost)
  static Future<int> getActivePublisherCount() async {
    try {
      final snap = await _db
          .collection('clinics_accounts')
          .where('approvalStatus', isEqualTo: 'approved')
          .where('canPost', isEqualTo: true)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ getActivePublisherCount: $e');
      return 0;
    }
  }

  // ─── Error Monitor ────────────────────────────────────────────

  /// 페이지별 오류 빈도 TOP N ([since] 필터 포함)
  static Future<List<MapEntry<String, int>>> getTopErrorPages({
    int limit = 5,
    DateTime? since,
  }) async {
    try {
      Query<Map<String, dynamic>> q =
          _db.collection('appErrors').limit(500);
      if (since != null) {
        q = _db
            .collection('appErrors')
            .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
            .limit(500);
      }
      final snap = await q.get();
      final pageMap = <String, int>{};
      for (final doc in snap.docs) {
        final page = doc.data()['page'] as String? ?? '(알 수 없음)';
        pageMap[page] = (pageMap[page] ?? 0) + 1;
      }
      final sorted = pageMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return sorted.take(limit).toList();
    } catch (e) {
      debugPrint('⚠️ getTopErrorPages: $e');
      return [];
    }
  }
}


