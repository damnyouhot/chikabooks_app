import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/poll.dart';
import '../models/poll_option.dart';

/// 공감투표 서비스
///
/// ── 핵심 정책 ──────────────────────────────────────────────────
/// - 유저당 투표 1개에 공감 1회만 보유
/// - 종료 전까지 다른 보기로 변경 가능, 취소는 불가
/// - 공감 변경 시 기존 option -1, 새 option +1, totalEmpathyCount 불변
/// - 첫 공감 시에만 totalEmpathyCount +1
/// - 보기 추가: 유저당 투표 1개에 최대 2개, 50자 제한
/// - 신고: 사용자 추가 보기(isSystem=false)만 가능
/// ──────────────────────────────────────────────────────────────
class EmpathyPollService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> get _pollsRef =>
      _db.collection('polls');

  static DocumentReference<Map<String, dynamic>> _pollDoc(String pollId) =>
      _pollsRef.doc(pollId);

  static CollectionReference<Map<String, dynamic>> _optionsRef(String pollId) =>
      _pollDoc(pollId).collection('options');

  static CollectionReference<Map<String, dynamic>> _votesRef(String pollId) =>
      _pollDoc(pollId).collection('votes');

  // ═══════════════════════════════════════════════════════════
  // 조회
  // ═══════════════════════════════════════════════════════════

  /// 현재 활성 투표 1개 (없으면 null)
  ///
  /// startsAt <= now < endsAt 인 투표만 반환 (미래 투표 제외)
  static Future<Poll?> getActivePoll() async {
    try {
      final now = DateTime.now();
      final nowTs = Timestamp.fromDate(now);
      final snap = await _pollsRef
          .where('status', isEqualTo: 'active')
          .where('startsAt', isLessThanOrEqualTo: nowTs)
          .orderBy('startsAt', descending: true)
          .limit(5)
          .get();

      if (snap.docs.isEmpty) return null;

      // endsAt > now인 것만 필터
      for (final doc in snap.docs) {
        final poll = Poll.fromDoc(doc);
        if (poll.endsAt.isAfter(now)) return poll;
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ EmpathyPollService.getActivePoll: $e');
      return null;
    }
  }

  /// 특정 투표의 보기 목록 (isHidden=false만, empathyCount 내림차순)
  static Future<List<PollOption>> getOptions(String pollId) async {
    try {
      final snap = await _optionsRef(pollId)
          .where('isHidden', isEqualTo: false)
          .orderBy('empathyCount', descending: true)
          .get();

      return snap.docs.map((d) => PollOption.fromDoc(d)).toList();
    } catch (e) {
      debugPrint('⚠️ EmpathyPollService.getOptions: $e');
      return [];
    }
  }

  /// 내가 이 투표에서 선택한 optionId (없으면 null)
  static Future<String?> getMyVote(String pollId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      final doc = await _votesRef(pollId).doc(uid).get();
      if (!doc.exists) return null;
      return doc.data()?['optionId'] as String?;
    } catch (e) {
      debugPrint('⚠️ EmpathyPollService.getMyVote: $e');
      return null;
    }
  }

  /// 종료된 투표 피드 (페이지네이션)
  static Future<List<Poll>> getClosedPolls({
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      var query = _pollsRef
          .where('status', isEqualTo: 'closed')
          .orderBy('closedAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snap = await query.get();
      return snap.docs.map((d) => Poll.fromDoc(d)).toList();
    } catch (e) {
      debugPrint('⚠️ EmpathyPollService.getClosedPolls: $e');
      return [];
    }
  }

  /// 종료된 투표의 상위 N개 보기 (메달용)
  static Future<List<PollOption>> getTopOptions(String pollId, {int top = 3}) async {
    try {
      final snap = await _optionsRef(pollId)
          .where('isHidden', isEqualTo: false)
          .orderBy('empathyCount', descending: true)
          .limit(top)
          .get();

      return snap.docs.map((d) => PollOption.fromDoc(d)).toList();
    } catch (e) {
      debugPrint('⚠️ EmpathyPollService.getTopOptions: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 실시간 스트림
  // ═══════════════════════════════════════════════════════════

  /// 보기 목록 실시간 스트림 (공감 수 변동 즉시 반영)
  static Stream<List<PollOption>> optionsStream(String pollId) {
    return _optionsRef(pollId)
        .where('isHidden', isEqualTo: false)
        .orderBy('empathyCount', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => PollOption.fromDoc(d)).toList());
  }

  /// 내 투표 상태 실시간 스트림
  static Stream<String?> myVoteStream(String pollId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    return _votesRef(pollId).doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return doc.data()?['optionId'] as String?;
    });
  }

  // ═══════════════════════════════════════════════════════════
  // 공감 / 변경
  // ═══════════════════════════════════════════════════════════

  /// 공감하기 또는 변경하기
  ///
  /// - 첫 공감: option.empathyCount +1, poll.totalEmpathyCount +1
  /// - 변경: 기존 option -1, 새 option +1, totalEmpathyCount 불변
  /// - 같은 option 재탭: 무시 (취소 없음)
  static Future<EmpathyResult> empathize(String pollId, String optionId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return EmpathyResult.fail('로그인이 필요합니다.');

    try {
      final pollRef = _pollDoc(pollId);
      final voteRef = _votesRef(pollId).doc(uid);
      final newOptionRef = _optionsRef(pollId).doc(optionId);

      return await _db.runTransaction((tx) async {
        final pollSnap = await tx.get(pollRef);
        if (!pollSnap.exists) return EmpathyResult.fail('투표를 찾을 수 없습니다.');

        final poll = Poll.fromDoc(pollSnap);
        if (poll.isClosed) return EmpathyResult.fail('종료된 투표입니다.');
        if (poll.endsAt.isBefore(DateTime.now())) {
          return EmpathyResult.fail('투표 시간이 종료되었습니다.');
        }

        final voteSnap = await tx.get(voteRef);
        final now = FieldValue.serverTimestamp();

        if (!voteSnap.exists) {
          // 첫 공감
          tx.set(voteRef, {
            'optionId': optionId,
            'votedAt': now,
            'updatedAt': now,
          });
          tx.update(newOptionRef, {
            'empathyCount': FieldValue.increment(1),
          });
          tx.update(pollRef, {
            'totalEmpathyCount': FieldValue.increment(1),
          });
          return EmpathyResult.ok(isChange: false);
        }

        // 이미 공감한 상태
        final currentOptionId = voteSnap.data()?['optionId'] as String?;
        if (currentOptionId == optionId) {
          return EmpathyResult.fail('이미 선택한 보기입니다.');
        }

        // 공감 변경
        final oldOptionRef = _optionsRef(pollId).doc(currentOptionId);
        tx.update(oldOptionRef, {
          'empathyCount': FieldValue.increment(-1),
        });
        tx.update(newOptionRef, {
          'empathyCount': FieldValue.increment(1),
        });
        tx.update(voteRef, {
          'optionId': optionId,
          'updatedAt': now,
        });
        // totalEmpathyCount는 변경하지 않음
        return EmpathyResult.ok(isChange: true);
      });
    } catch (e) {
      debugPrint('⚠️ EmpathyPollService.empathize: $e');
      return EmpathyResult.fail('공감 처리 중 오류가 발생했습니다.');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 보기 추가
  // ═══════════════════════════════════════════════════════════

  static const int maxUserOptionsPerPoll = 2;
  static const int maxOptionLength = 50;

  /// 사용자 보기 추가
  static Future<AddOptionResult> addOption(String pollId, String content) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return AddOptionResult.fail('로그인이 필요합니다.');

    final trimmed = content.trim();
    if (trimmed.isEmpty) return AddOptionResult.fail('내용을 입력해주세요.');
    if (trimmed.length > maxOptionLength) {
      return AddOptionResult.fail('$maxOptionLength자 이내로 작성해주세요.');
    }

    try {
      // 투표 상태 확인
      final pollSnap = await _pollDoc(pollId).get();
      if (!pollSnap.exists) return AddOptionResult.fail('투표를 찾을 수 없습니다.');
      final poll = Poll.fromDoc(pollSnap);
      if (poll.isClosed || poll.endsAt.isBefore(DateTime.now())) {
        return AddOptionResult.fail('종료된 투표에는 보기를 추가할 수 없습니다.');
      }

      // 유저가 이 투표에 추가한 보기 수 확인
      final myOptions = await _optionsRef(pollId)
          .where('authorUid', isEqualTo: uid)
          .get();

      if (myOptions.docs.length >= maxUserOptionsPerPoll) {
        return AddOptionResult.fail(
          '보기는 투표당 최대 ${maxUserOptionsPerPoll}개까지 추가할 수 있습니다.',
        );
      }

      final docRef = await _optionsRef(pollId).add({
        'content': trimmed,
        'authorUid': uid,
        'isSystem': false,
        'createdAt': FieldValue.serverTimestamp(),
        'empathyCount': 0,
        'reportCount': 0,
        'isHidden': false,
      });

      return AddOptionResult.ok(docRef.id);
    } catch (e) {
      debugPrint('⚠️ EmpathyPollService.addOption: $e');
      return AddOptionResult.fail('보기 추가 중 오류가 발생했습니다.');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 신고
  // ═══════════════════════════════════════════════════════════

  static const int reportHideThreshold = 3;

  /// 사용자 추가 보기 신고
  ///
  /// - 시스템 보기(isSystem=true)는 신고 불가
  /// - 동일 uid 중복 신고 불가
  /// - 임계값 초과 시 isHidden=true
  static Future<ReportResult> reportOption(
    String pollId,
    String optionId,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return ReportResult.fail('로그인이 필요합니다.');

    try {
      final optionRef = _optionsRef(pollId).doc(optionId);

      return await _db.runTransaction((tx) async {
        final optionSnap = await tx.get(optionRef);
        if (!optionSnap.exists) return ReportResult.fail('보기를 찾을 수 없습니다.');

        final option = PollOption.fromDoc(optionSnap);
        if (option.isSystem) {
          return ReportResult.fail('기본 보기는 신고할 수 없습니다.');
        }

        // 중복 신고 체크
        final reportRef = optionRef.collection('reports').doc(uid);
        final reportSnap = await tx.get(reportRef);
        if (reportSnap.exists) {
          return ReportResult.fail('이미 신고한 보기입니다.');
        }

        tx.set(reportRef, {
          'uid': uid,
          'reportedAt': FieldValue.serverTimestamp(),
        });

        final newCount = option.reportCount + 1;
        final updates = <String, dynamic>{
          'reportCount': FieldValue.increment(1),
        };
        if (newCount >= reportHideThreshold) {
          updates['isHidden'] = true;
        }
        tx.update(optionRef, updates);

        return ReportResult.ok(hidden: newCount >= reportHideThreshold);
      });
    } catch (e) {
      debugPrint('⚠️ EmpathyPollService.reportOption: $e');
      return ReportResult.fail('신고 처리 중 오류가 발생했습니다.');
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// 결과 객체
// ═══════════════════════════════════════════════════════════════

class EmpathyResult {
  final bool success;
  final bool isChange;
  final String? error;

  const EmpathyResult._({required this.success, this.isChange = false, this.error});
  factory EmpathyResult.ok({required bool isChange}) =>
      EmpathyResult._(success: true, isChange: isChange);
  factory EmpathyResult.fail(String msg) =>
      EmpathyResult._(success: false, error: msg);
}

class AddOptionResult {
  final bool success;
  final String? optionId;
  final String? error;

  const AddOptionResult._({required this.success, this.optionId, this.error});
  factory AddOptionResult.ok(String id) =>
      AddOptionResult._(success: true, optionId: id);
  factory AddOptionResult.fail(String msg) =>
      AddOptionResult._(success: false, error: msg);
}

class ReportResult {
  final bool success;
  final bool hidden;
  final String? error;

  const ReportResult._({required this.success, this.hidden = false, this.error});
  factory ReportResult.ok({required bool hidden}) =>
      ReportResult._(success: true, hidden: hidden);
  factory ReportResult.fail(String msg) =>
      ReportResult._(success: false, error: msg);
}
