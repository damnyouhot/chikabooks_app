import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/poll.dart';
import '../models/poll_comment.dart';
import '../models/poll_option.dart';
import 'user_profile_service.dart';

/// 공감투표 서비스
///
/// ── 핵심 정책 ──────────────────────────────────────────────────
/// - 유저당 투표 1개에 공감 1회만 보유
/// - 종료 전까지 다른 보기로 변경 가능, 취소는 불가
/// - 공감 변경 시 기존 option -1, 새 option +1, totalEmpathyCount 불변
/// - 첫 공감 시에만 totalEmpathyCount +1
/// - 보기 추가: 유저당 투표 1개에 최대 2개, 50자 제한
/// - 신고: 사용자 추가 보기(isSystem=false)만 가능, 사유 필수, 5건 누적 시 Functions로 보기 삭제
/// - 삭제: 작성자만 — 공감 0(클라이언트) 또는 공감 본인 1표(Callable)
/// ──────────────────────────────────────────────────────────────
class EmpathyPollService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static const String _functionsRegion = 'us-central1';

  static CollectionReference<Map<String, dynamic>> get _pollsRef =>
      _db.collection('polls');

  static DocumentReference<Map<String, dynamic>> _pollDoc(String pollId) =>
      _pollsRef.doc(pollId);

  static CollectionReference<Map<String, dynamic>> _optionsRef(String pollId) =>
      _pollDoc(pollId).collection('options');

  static CollectionReference<Map<String, dynamic>> _votesRef(String pollId) =>
      _pollDoc(pollId).collection('votes');

  static CollectionReference<Map<String, dynamic>> _pollCommentsRef(String pollId) =>
      _pollDoc(pollId).collection('pollComments');

  /// 종료 투표 한마디 댓글 최대 길이
  static const int maxPollCommentLength = 300;

  // ═══════════════════════════════════════════════════════════
  // 조회
  // ═══════════════════════════════════════════════════════════

  /// 현재 진행 중인 투표 1개 (없으면 null)
  ///
  /// `startsAt <= now < endsAt` 인 문서만 (status는 `scheduled`/`active` 모두 가능).
  /// 동시에 겹치는 경우 [Poll.displayOrder]가 가장 작은 투표를 선택한다.
  static Future<Poll?> getActivePoll() async {
    try {
      final now = DateTime.now();
      final nowTs = Timestamp.fromDate(now);
      // 아직 종료되지 않은 투표 후보만 가져온 뒤, 클라이언트에서 진행 중 + displayOrder로 고른다.
      final snap = await _pollsRef
          .where('endsAt', isGreaterThan: nowTs)
          .orderBy('endsAt')
          .limit(500)
          .get();

      if (snap.docs.isEmpty) return null;

      Poll? best;
      for (final doc in snap.docs) {
        final poll = Poll.fromDoc(doc);
        if (!poll.isVotingOpen) continue;
        if (best == null) {
          best = poll;
          continue;
        }
        final cur = best;
        if (poll.displayOrder < cur.displayOrder ||
            (poll.displayOrder == cur.displayOrder &&
                poll.startsAt.isBefore(cur.startsAt))) {
          best = poll;
        }
      }
      return best;
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
  ///
  /// `endsAt < now` 기준(실제 마감). `endsAt` 내림차순.
  /// [ClosedPollsPage]를 반환하여 다음 페이지 커서를 함께 제공
  static Future<ClosedPollsPage> getClosedPolls({
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      final now = DateTime.now();
      final nowTs = Timestamp.fromDate(now);

      var query = _pollsRef
          .where('endsAt', isLessThan: nowTs)
          .orderBy('endsAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snap = await query.get();
      final polls = snap.docs.map((d) => Poll.fromDoc(d)).toList();
      final lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
      return ClosedPollsPage(polls: polls, lastDoc: lastDoc);
    } catch (e) {
      debugPrint('⚠️ EmpathyPollService.getClosedPolls: $e');
      return ClosedPollsPage(polls: [], lastDoc: null);
    }
  }

  /// 투표의 전체 보기 (공유 이미지용, 공감 수 내림차순)
  static Future<List<PollOption>> getOptionsOrderedForPoll(String pollId) async {
    try {
      final snap = await _optionsRef(pollId)
          .where('isHidden', isEqualTo: false)
          .orderBy('empathyCount', descending: true)
          .get();

      return snap.docs.map((d) => PollOption.fromDoc(d)).toList();
    } catch (e) {
      debugPrint('⚠️ EmpathyPollService.getOptionsOrderedForPoll: $e');
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
        if (!poll.isVotingOpen) {
          return EmpathyResult.fail(
            poll.hasEnded ? '투표 시간이 종료되었습니다.' : '아직 시작되지 않은 투표입니다.',
          );
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
  static const int maxAuthorNicknameLength = 30;

  /// 사용자 보기 추가
  ///
  /// [hideAuthorNickname]이 true이면 닉네임을 저장하지 않아 목록에는 `익명`으로만 표시됩니다.
  static Future<AddOptionResult> addOption(
    String pollId,
    String content, {
    bool hideAuthorNickname = false,
  }) async {
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
      if (!poll.isVotingOpen) {
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

      var nickname = '';
      if (!hideAuthorNickname) {
        final profile = await UserProfileService.getMyProfile();
        nickname = profile?.nickname.trim() ?? '';
        if (nickname.length > maxAuthorNicknameLength) {
          nickname = nickname.substring(0, maxAuthorNicknameLength);
        }
      }

      final docRef = await _optionsRef(pollId).add({
        'content': trimmed,
        'authorUid': uid,
        'authorNickname': nickname,
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
  // 종료 투표 댓글
  // ═══════════════════════════════════════════════════════════

  /// 종료된 투표 댓글 스트림 (오래된 순)
  static Stream<List<PollComment>> pollCommentsStream(String pollId) {
    return _pollCommentsRef(pollId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(PollComment.fromDoc).toList());
  }

  /// 종료된 투표에만 댓글 작성 가능
  static Future<PollCommentResult> addPollComment(String pollId, String text) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return PollCommentResult.fail('로그인이 필요합니다.');

    final trimmed = text.trim();
    if (trimmed.isEmpty) return PollCommentResult.fail('내용을 입력해주세요.');
    if (trimmed.length > maxPollCommentLength) {
      return PollCommentResult.fail('$maxPollCommentLength자 이내로 작성해주세요.');
    }

    try {
      final pollSnap = await _pollDoc(pollId).get();
      if (!pollSnap.exists) return PollCommentResult.fail('투표를 찾을 수 없습니다.');
      final poll = Poll.fromDoc(pollSnap);
      if (!poll.hasEnded) {
        return PollCommentResult.fail('종료된 투표에만 댓글을 달 수 있습니다.');
      }

      await _pollCommentsRef(pollId).add({
        'text': trimmed,
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return PollCommentResult.ok();
    } catch (e) {
      debugPrint('⚠️ EmpathyPollService.addPollComment: $e');
      return PollCommentResult.fail('댓글 등록 중 오류가 발생했습니다.');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 신고
  // ═══════════════════════════════════════════════════════════

  /// 누적 시 Cloud Functions로 보기 완전 삭제
  static const int reportDeleteThreshold = 5;

  /// 신고 사유 키 → UI 라벨
  static const Map<String, String> pollReportReasonLabels = {
    'spam': '스팸·광고',
    'abuse': '욕설·비방',
    'sexual': '선정적·불쾌한 내용',
    'privacy': '개인정보 노출',
    'other': '기타',
  };

  static final Set<String> _allowedReportReasons = pollReportReasonLabels.keys.toSet();

  static Future<void> _invokePurgeAfterReports(String pollId, String optionId) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: _functionsRegion)
          .httpsCallable('purgePollOptionAfterReports');
      await callable.call(<String, dynamic>{
        'pollId': pollId,
        'optionId': optionId,
      });
    } catch (e) {
      debugPrint('⚠️ purgePollOptionAfterReports: $e');
    }
  }

  /// 사용자 추가 보기 신고
  ///
  /// - 시스템 보기(isSystem=true)는 신고 불가
  /// - 동일 uid 중복 신고 불가
  /// - [reasonKey]는 [pollReportReasonLabels] 키 중 하나
  /// - 5건 이상이면 Callable로 보기·votes·집계 정리
  static Future<ReportResult> reportOption(
    String pollId,
    String optionId, {
    required String reasonKey,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return ReportResult.fail('로그인이 필요합니다.');
    if (!_allowedReportReasons.contains(reasonKey)) {
      return ReportResult.fail('신고 사유를 선택해주세요.');
    }

    try {
      final optionRef = _optionsRef(pollId).doc(optionId);

      final result = await _db.runTransaction((tx) async {
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
          'reason': reasonKey,
          'reportedAt': FieldValue.serverTimestamp(),
        });

        final newCount = option.reportCount + 1;
        tx.update(optionRef, {
          'reportCount': FieldValue.increment(1),
        });

        return ReportResult.ok(reachedRemovalThreshold: newCount >= reportDeleteThreshold);
      });

      if (result.success && result.reachedRemovalThreshold) {
        await _invokePurgeAfterReports(pollId, optionId);
      }
      return result;
    } catch (e) {
      debugPrint('⚠️ EmpathyPollService.reportOption: $e');
      return ReportResult.fail('신고 처리 중 오류가 발생했습니다.');
    }
  }

  /// 본인이 추가한 보기 삭제
  ///
  /// - 공감 0: 클라이언트 배치 직접 삭제
  /// - 공감 1~5: Cloud Function(`authorDeletePollOptionWithVote`)으로 votes·집계 정리 후 삭제
  /// - 공감 6 이상: 거절
  static Future<DeleteOptionResult> deleteMyOption(
    String pollId,
    String optionId,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return DeleteOptionResult.fail('로그인이 필요합니다.');

    try {
      final optionRef = _optionsRef(pollId).doc(optionId);
      final optionSnap = await optionRef.get();
      if (!optionSnap.exists) {
        return DeleteOptionResult.fail('보기를 찾을 수 없습니다.');
      }

      final option = PollOption.fromDoc(optionSnap);
      if (option.isSystem) {
        return DeleteOptionResult.fail('기본 보기는 삭제할 수 없습니다.');
      }
      if (option.authorUid != uid) {
        return DeleteOptionResult.fail('본인이 추가한 보기만 삭제할 수 있습니다.');
      }
      if (option.empathyCount > 5) {
        return DeleteOptionResult.fail('공감 인원이 많아 삭제할 수 없어요.');
      }

      if (option.empathyCount > 0) {
        try {
          final callable = FirebaseFunctions.instanceFor(region: _functionsRegion)
              .httpsCallable('authorDeletePollOptionWithVote');
          await callable.call(<String, dynamic>{
            'pollId': pollId,
            'optionId': optionId,
          });
          return DeleteOptionResult.ok();
        } on FirebaseFunctionsException catch (e) {
          return DeleteOptionResult.fail(e.message ?? '삭제에 실패했습니다.');
        }
      }

      // empathyCount == 0: 신고 서브컬렉션 정리 후 직접 삭제
      final reportsSnap = await optionRef.collection('reports').get();
      final batch = _db.batch();
      for (final d in reportsSnap.docs) {
        batch.delete(d.reference);
      }
      batch.delete(optionRef);
      await batch.commit();
      return DeleteOptionResult.ok();
    } catch (e) {
      debugPrint('⚠️ EmpathyPollService.deleteMyOption: $e');
      return DeleteOptionResult.fail('보기 삭제 중 오류가 발생했습니다.');
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

class PollCommentResult {
  final bool success;
  final String? error;

  const PollCommentResult._({required this.success, this.error});
  factory PollCommentResult.ok() => const PollCommentResult._(success: true);
  factory PollCommentResult.fail(String msg) =>
      PollCommentResult._(success: false, error: msg);
}

class ReportResult {
  final bool success;
  /// 신고 직후 누적이 5건 이상이면 true (이어서 Functions로 보기 삭제 시도)
  final bool reachedRemovalThreshold;
  final String? error;

  const ReportResult._({
    required this.success,
    this.reachedRemovalThreshold = false,
    this.error,
  });
  factory ReportResult.ok({bool reachedRemovalThreshold = false}) =>
      ReportResult._(success: true, reachedRemovalThreshold: reachedRemovalThreshold);
  factory ReportResult.fail(String msg) =>
      ReportResult._(success: false, error: msg);
}

class DeleteOptionResult {
  final bool success;
  final String? error;

  const DeleteOptionResult._({required this.success, this.error});
  factory DeleteOptionResult.ok() =>
      const DeleteOptionResult._(success: true);
  factory DeleteOptionResult.fail(String msg) =>
      DeleteOptionResult._(success: false, error: msg);
}

/// 종료된 투표 페이지 결과 (커서 포함)
class ClosedPollsPage {
  final List<Poll> polls;
  final DocumentSnapshot? lastDoc;

  const ClosedPollsPage({required this.polls, required this.lastDoc});
}
