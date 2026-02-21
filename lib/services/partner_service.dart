import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/partner_group.dart';
import '../models/daily_slot.dart';
import '../models/activity_log.dart';
import '../models/slot_status.dart';
import '../models/slot_message.dart';
import '../models/inbox_card.dart';
import 'bond_score_service.dart';
import 'user_profile_service.dart';

/// 파트너 시스템 핵심 서비스
/// 그룹 관리 / 슬롯 claim·post / 리액션 / 매칭풀
class PartnerService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ─── 리액션 선택지 (슬롯 + 북돋기 공용) ───
  static const Map<String, SlotReactionOption> reactionOptions = {
    'HEART_SEEING': SlotReactionOption('💛', '보고 있어'),
    'BUBBLE_OK': SlotReactionOption('🫧', '괜찮아'),
    'SPARKLE_GOOD': SlotReactionOption('✨', '잘했어'),
    'MOON_DAY': SlotReactionOption('🌙', '오늘은 이런 날'),
    'ICE_BREATHE': SlotReactionOption('🧊', '숨 고르자'),
    'FIRE_ENDURED': SlotReactionOption('🔥', '버텼다'),
  };

  // ═══════════════════════ 그룹 조회 ═══════════════════════

  /// 내 현재 활성 그룹 가져오기
  static Future<PartnerGroup?> getMyGroup() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      // 항상 최신 프로필을 읽어야 매칭 직후에도 groupId 반영됨
      final profile = await UserProfileService.getMyProfile(forceRefresh: true);
      final groupId = profile?.partnerGroupId;
      if (groupId == null || groupId.isEmpty) return null;

      final doc =
          await _db.collection('partnerGroups').doc(groupId).get();
      if (!doc.exists) return null;

      final group = PartnerGroup.fromDoc(doc);
      return group.isActive ? group : null;
    } catch (e) {
      debugPrint('⚠️ getMyGroup error: $e');
      return null;
    }
  }

  /// 그룹 멤버 메타 목록
  static Future<List<GroupMemberMeta>> getGroupMembers(
      String groupId) async {
    try {
      final snap = await _db
          .collection('partnerGroups')
          .doc(groupId)
          .collection('memberMeta')
          .get();
      return snap.docs.map(GroupMemberMeta.fromDoc).toList();
    } catch (e) {
      debugPrint('⚠️ getGroupMembers error: $e');
      return [];
    }
  }

  // ═══════════════════════ 슬롯 ═══════════════════════

  /// 현재 활성 슬롯 키 결정 (KST 기준)
  /// 12:30~18:59 → "1230", 19:00~23:59 → "1900", 00:00~12:29 → null(대기)
  static String? currentSlotKey() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    final h = kst.hour;
    final m = kst.minute;
    final totalMin = h * 60 + m;

    if (totalMin >= 750 && totalMin < 1140) return '1230'; // 12:30~18:59
    if (totalMin >= 1140) return '1900'; // 19:00~23:59
    return null; // 00:00~12:29 → 대기
  }

  /// 다음 슬롯 시간 안내 텍스트
  static String nextSlotGuide() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    final h = kst.hour;
    final m = kst.minute;
    final totalMin = h * 60 + m;

    if (totalMin < 750) return '다음 말 시간: 12:30';
    if (totalMin >= 1140) return '오늘 슬롯이 모두 지났어요';
    return '';
  }

  /// KST 기준 오늘 dateKey
  static String todayDateKey() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    return '${kst.year}-${kst.month.toString().padLeft(2, '0')}-${kst.day.toString().padLeft(2, '0')}';
  }

  /// 슬롯 문서 ID
  static String slotDocId(String groupId, String dateKey, String slotKey) =>
      '${groupId}_${dateKey}_$slotKey';

  /// 슬롯 가져오기 (없으면 open 상태로 반환)
  static Future<DailySlot> getSlot(
      String groupId, String dateKey, String slotKey) async {
    final docId = slotDocId(groupId, dateKey, slotKey);
    try {
      final doc = await _db.collection('dailySlots').doc(docId).get();
      if (doc.exists) return DailySlot.fromDoc(doc);
    } catch (e) {
      debugPrint('⚠️ getSlot error: $e');
    }
    // 문서 미존재 → 빈 슬롯
    return DailySlot(
      id: docId,
      groupId: groupId,
      dateKey: dateKey,
      slotKey: slotKey,
      status: 'open',
    );
  }

  /// 슬롯 스트림 (실시간 UI 업데이트)
  static Stream<DailySlot> streamSlot(
      String groupId, String dateKey, String slotKey) {
    final docId = slotDocId(groupId, dateKey, slotKey);
    return _db
        .collection('dailySlots')
        .doc(docId)
        .snapshots()
        .map((snap) {
      if (snap.exists) return DailySlot.fromDoc(snap);
      return DailySlot(
        id: docId,
        groupId: groupId,
        dateKey: dateKey,
        slotKey: slotKey,
        status: 'open',
      );
    });
  }

  /// 선착순 claim (트랜잭션 — 핵심!)
  /// 성공 시 true, 이미 누군가 claim했으면 false
  static Future<bool> claimSlot(
      String groupId, String dateKey, String slotKey) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    final docId = slotDocId(groupId, dateKey, slotKey);
    final docRef = _db.collection('dailySlots').doc(docId);

    try {
      return await _db.runTransaction<bool>((tx) async {
        final snap = await tx.get(docRef);

        if (snap.exists) {
          final data = snap.data() ?? {};
          if (data['claimedByUid'] != null) {
            return false; // 이미 누가 claim
          }
          tx.update(docRef, {
            'claimedByUid': uid,
            'claimedAt': FieldValue.serverTimestamp(),
            'status': 'claimed',
          });
        } else {
          // 문서가 아예 없으면 생성
          tx.set(docRef, {
            'groupId': groupId,
            'dateKey': dateKey,
            'slotKey': slotKey,
            'claimedByUid': uid,
            'claimedAt': FieldValue.serverTimestamp(),
            'status': 'claimed',
          });
        }
        return true;
      });
    } catch (e) {
      debugPrint('⚠️ claimSlot error: $e');
      return false;
    }
  }

  /// 한마디 작성 (claim 후 60자 텍스트 저장)
  static Future<bool> postSlot({
    required String groupId,
    required String dateKey,
    required String slotKey,
    required String text,
    String? toneEmoji,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    if (text.trim().isEmpty || text.length > 60) return false;

    final docId = slotDocId(groupId, dateKey, slotKey);
    final docRef = _db.collection('dailySlots').doc(docId);

    try {
      await docRef.update({
        'text': text.trim(),
        'toneEmoji': toneEmoji,
        'status': 'posted',
      });

      // 활동 로그 기록
      await _logActivity(groupId, uid, ActivityType.slotPost, {
        'slotKey': slotKey,
        'dateKey': dateKey,
      });

      // 결 점수: 작성자 +0.8, 나머지 멤버 +0.2
      final group = await _getGroup(groupId);
      if (group != null) {
        await BondScoreService.applySlotPost(uid, group.memberUids);
      }

      return true;
    } catch (e) {
      debugPrint('⚠️ postSlot error: $e');
      return false;
    }
  }

  /// 슬롯 리액션 저장 (overwrite 허용)
  static Future<void> setSlotReaction(
    String slotDocId,
    String reactionKey,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db
          .collection('dailySlots')
          .doc(slotDocId)
          .collection('reactions')
          .doc(uid)
          .set({
        'reactionKey': reactionKey,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 슬롯에서 작성자 uid 읽어서 결 점수 적용
      final slotSnap =
          await _db.collection('dailySlots').doc(slotDocId).get();
      final authorUid = slotSnap.data()?['claimedByUid'] as String?;
      final groupId = slotSnap.data()?['groupId'] as String?;

      if (authorUid != null && authorUid != uid) {
        await BondScoreService.applyCheer(uid, authorUid);
      } else {
        await BondScoreService.applyEvent(uid, ActivityType.slotReaction);
      }

      // 활동 로그
      if (groupId != null) {
        await _logActivity(groupId, uid, ActivityType.slotReaction, {
          'slotDocId': slotDocId,
          'reactionKey': reactionKey,
        });
      }
    } catch (e) {
      debugPrint('⚠️ setSlotReaction error: $e');
    }
  }

  /// 슬롯 리액션 요약 (key → count)
  static Future<Map<String, int>> getSlotReactionSummary(
      String slotDocId) async {
    try {
      final snap = await _db
          .collection('dailySlots')
          .doc(slotDocId)
          .collection('reactions')
          .get();
      final summary = <String, int>{};
      for (final doc in snap.docs) {
        final key = doc.data()['reactionKey'] as String? ?? '';
        summary[key] = (summary[key] ?? 0) + 1;
      }
      return summary;
    } catch (e) {
      debugPrint('⚠️ getSlotReactionSummary error: $e');
      return {};
    }
  }

  /// 내 슬롯 리액션 키
  static Future<String?> getMySlotReaction(String slotDocId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    try {
      final doc = await _db
          .collection('dailySlots')
          .doc(slotDocId)
          .collection('reactions')
          .doc(uid)
          .get();
      if (!doc.exists) return null;
      return doc.data()?['reactionKey'] as String?;
    } catch (e) {
      return null;
    }
  }

  // ═══════════════════════ 새로운 슬롯 시스템 (서버 기준) ═══════════════════════

  /// 서버 시간 기준 슬롯 상태 가져오기
  static Future<SlotStatus?> getSlotStatus(String groupId) async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-northeast3',
      ).httpsCallable('getSlotStatus');

      final result = await callable.call<Map<String, dynamic>>({'groupId': groupId});
      return SlotStatus.fromMap(result.data);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('⚠️ getSlotStatus error: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('⚠️ getSlotStatus error: $e');
      return null;
    }
  }

  /// 슬롯 한마디 작성 (서버 검증)
  static Future<bool> submitSlotMessage({
    required String groupId,
    required String message,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-northeast3',
      ).httpsCallable('submitSlotMessage');

      await callable.call<Map<String, dynamic>>({
        'groupId': groupId,
        'message': message,
      });
      return true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('⚠️ submitSlotMessage error: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('⚠️ submitSlotMessage error: $e');
      return false;
    }
  }

  /// 슬롯 리액션 작성 (서버 검증)
  static Future<bool> submitSlotReaction({
    required String groupId,
    required String slotId,
    required String emoji,
    required String phraseId,
    required String phraseText,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-northeast3',
      ).httpsCallable('submitSlotReaction');

      await callable.call<Map<String, dynamic>>({
        'groupId': groupId,
        'slotId': slotId,
        'emoji': emoji,
        'phraseId': phraseId,
        'phraseText': phraseText,
      });
      return true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('⚠️ submitSlotReaction error: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('⚠️ submitSlotReaction error: $e');
      return false;
    }
  }

  /// 인박스 읽음 처리
  static Future<bool> markInboxRead(String inboxId) async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-northeast3',
      ).httpsCallable('markInboxRead');

      await callable.call<Map<String, dynamic>>({'inboxId': inboxId});
      return true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('⚠️ markInboxRead error: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('⚠️ markInboxRead error: $e');
      return false;
    }
  }

  /// 슬롯 메시지 스트림 (실시간 업데이트)
  static Stream<SlotMessage?> streamSlotMessage(String groupId, String slotId) {
    return _db
        .collection('partnerGroups')
        .doc(groupId)
        .collection('slots')
        .doc(slotId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return null;
      return SlotMessage.fromDoc(snap);
    });
  }

  /// 인박스 카드 스트림 (읽지 않은 것만)
  static Stream<List<InboxCard>> streamInboxCards() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(uid)
        .collection('partnerInbox')
        .where('unread', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map(InboxCard.fromDoc).toList());
  }

  // ═══════════════════════ 매칭풀 ═══════════════════════

  /// 매칭풀에 등록 (기존 — 로컬 전용, 서버 매칭 미포함)
  static Future<void> joinMatchingPool() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final profile = await UserProfileService.getMyProfile(forceRefresh: true);
    if (profile == null) return;

    try {
      await _db.collection('partnerMatchingPool').doc(uid).set({
        'region': profile.region,
        'careerBucket': profile.careerBucket,
        'mainConcerns': profile.mainConcerns,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ joinMatchingPool error: $e');
    }
  }

  /// 추천 매칭 요청 (Cloud Functions callable)
  ///
  /// 반환값:
  /// - `MatchingResult.matched(groupId)` — 3명 매칭 성공
  /// - `MatchingResult.waiting(message)` — 풀에 등록, 대기 중
  /// - `MatchingResult.error(message)` — 에러
  static Future<MatchingResult> requestMatching() async {
    debugPrint('🚀 [requestMatching] 시작');
    
    try {
      final uid = _auth.currentUser?.uid;
      debugPrint('🔍 [requestMatching] UID: $uid');
      
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-northeast3',
      ).httpsCallable('requestPartnerMatching');

      debugPrint('🔍 [requestMatching] Cloud Function 호출 중...');
      final result = await callable.call<Map<String, dynamic>>();
      debugPrint('🔍 [requestMatching] Cloud Function 응답 받음');
      
      final data = result.data;
      debugPrint('🔍 [requestMatching] 응답 데이터: $data');

      final status = data['status'] as String? ?? '';
      final groupId = data['groupId'] as String?;
      final message = data['message'] as String?;

      debugPrint('🔍 [requestMatching] status: $status, groupId: $groupId, message: $message');

      if (status == 'matched' && groupId != null) {
        debugPrint('✅ [requestMatching] 매칭 성공! 그룹 ID: $groupId');
        // 캐시 갱신 — 새 그룹 반영
        UserProfileService.clearCache();
        return MatchingResult.matched(groupId);
      }

      debugPrint('⏳ [requestMatching] 대기 중: $message');
      return MatchingResult.waiting(
        message ?? '아직 함께할 사람이 부족해요.',
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('⚠️ [requestMatching] FunctionsError - code: ${e.code}, message: ${e.message}');
      debugPrint('⚠️ [requestMatching] FunctionsError - details: ${e.details}');
      return MatchingResult.error(
        e.message ?? '매칭 요청 중 문제가 생겼어요.',
      );
    } catch (e, stackTrace) {
      debugPrint('⚠️ [requestMatching] 예외 발생: $e');
      debugPrint('⚠️ [requestMatching] 스택트레이스:\n$stackTrace');
      return MatchingResult.error('매칭 요청 중 문제가 생겼어요.');
    }
  }

  /// 그룹 생성 (테스트/Admin용 — 3명 uid 필요)
  static Future<String?> createGroup(List<String> memberUids) async {
    if (memberUids.length != 3) return null;

    try {
      final now = DateTime.now();
      final endsAt = now.add(const Duration(days: 7));

      final groupRef = _db.collection('partnerGroups').doc();
      final group = PartnerGroup(
        id: groupRef.id,
        ownerId: memberUids.first,
        title: '결 ${DateTime.now().millisecondsSinceEpoch % 100}',
        members: memberUids.map((uid) => PartnerMember(
          uid: uid,
          status: PartnerMemberStatus.active,
          joinedAt: now,
        )).toList(),
        createdAt: now,
        startedAt: now,
        endsAt: endsAt,
        memberUids: memberUids,
      );

      final batch = _db.batch();

      // 그룹 문서 생성
      batch.set(groupRef, group.toMap());

      // 각 멤버 메타 생성 + users 업데이트
      for (final uid in memberUids) {
        final userDoc = await _db.collection('users').doc(uid).get();
        final userData = userDoc.data() ?? {};

        final memberRef =
            groupRef.collection('memberMeta').doc(uid);
        batch.set(memberRef, GroupMemberMeta(
          uid: uid,
          region: userData['region'] ?? '',
          careerBucket: userData['careerBucket'] ?? '',
          careerGroup: userData['careerGroup'] ?? '',
          mainConcernShown: (userData['mainConcerns'] as List?)?.isNotEmpty == true
              ? (userData['mainConcerns'] as List).first as String
              : null,
          workplaceType: userData['workplaceType'] as String?,
          joinedAt: now,
        ).toMap());

        // users/{uid} 업데이트
        batch.update(_db.collection('users').doc(uid), {
          'partnerGroupId': groupRef.id,
          'partnerGroupEndsAt': Timestamp.fromDate(endsAt),
          'bondScore': FieldValue.increment(0), // 없으면 생성용
        });
      }

      await batch.commit();

      // 매칭풀에서 제거
      for (final uid in memberUids) {
        await _db.collection('partnerMatchingPool').doc(uid).delete();
      }

      return groupRef.id;
    } catch (e) {
      debugPrint('⚠️ createGroup error: $e');
      return null;
    }
  }

  // ═══════════════════════ 내부 유틸 ═══════════════════════

  static Future<PartnerGroup?> _getGroup(String groupId) async {
    try {
      final doc =
          await _db.collection('partnerGroups').doc(groupId).get();
      if (!doc.exists) return null;
      return PartnerGroup.fromDoc(doc);
    } catch (e) {
      return null;
    }
  }

  static Future<void> _logActivity(
    String groupId,
    String actorUid,
    ActivityType type,
    Map<String, dynamic> meta,
  ) async {
    try {
      await _db
          .collection('partnerGroups')
          .doc(groupId)
          .collection('activityLogs')
          .add(ActivityLog(
            id: '',
            createdAt: DateTime.now(),
            actorUid: actorUid,
            type: type,
            meta: meta,
          ).toMap());
    } catch (e) {
      debugPrint('⚠️ _logActivity error: $e');
    }
  }
}

/// 슬롯 리액션 옵션 (이모지 + 멘트)
class SlotReactionOption {
  final String emoji;
  final String label;
  const SlotReactionOption(this.emoji, this.label);
}

/// 매칭 요청 결과
class MatchingResult {
  final MatchingStatus status;
  final String? groupId;
  final String? message;

  const MatchingResult._({
    required this.status,
    this.groupId,
    this.message,
  });

  factory MatchingResult.matched(String groupId) =>
      MatchingResult._(status: MatchingStatus.matched, groupId: groupId);

  factory MatchingResult.waiting(String message) =>
      MatchingResult._(status: MatchingStatus.waiting, message: message);

  factory MatchingResult.error(String message) =>
      MatchingResult._(status: MatchingStatus.error, message: message);
}

enum MatchingStatus { matched, waiting, error }

