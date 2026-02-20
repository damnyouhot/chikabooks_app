import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/bond_score_service.dart';

/// 신고 사유
enum ReportReason {
  /// 욕설/비방
  profanity('욕설/비방'),
  
  /// 괴롭힘
  harassment('괴롭힘'),
  
  /// 성희롱
  sexualHarassment('성희롱'),
  
  /// 개인정보 노출
  privacyViolation('개인정보 노출'),
  
  /// 스팸/광고
  spam('스팸/광고'),
  
  /// 기타
  other('기타');

  const ReportReason(this.displayName);
  final String displayName;
}

/// 게시물 신고/차단 서비스
class ReportService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// 자동 비노출 기준 신고 횟수
  static const int autoHideThreshold = 3;

  /// 게시물 신고하기
  /// 
  /// [documentPath]: 'bondGroups/{groupId}/posts/{postId}' 또는 'bondPosts/{postId}' 등의 전체 경로
  /// [reason]: 신고 사유
  /// [additionalInfo]: 추가 설명 (선택)
  static Future<bool> reportPost({
    required String documentPath,
    required ReportReason reason,
    String? additionalInfo,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      debugPrint('⚠️ reportPost: User not logged in');
      return false;
    }

    try {
      final postRef = _db.doc(documentPath);

      // 중복 신고 방지: 이미 신고했는지 확인
      final existingReport = await postRef
          .collection('reports')
          .doc(uid)
          .get();

      if (existingReport.exists) {
        debugPrint('⚠️ reportPost: Already reported');
        return false; // 이미 신고함
      }

      // 신고 기록 저장
      await postRef.collection('reports').doc(uid).set({
        'reporterUid': uid,
        'reason': reason.name,
        'reasonDisplay': reason.displayName,
        'additionalInfo': additionalInfo,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 게시물의 총 신고 수 증가
      await postRef.update({
        'reports': FieldValue.increment(1),
        'lastReportReason': reason.displayName,
        'lastReportedAt': FieldValue.serverTimestamp(),
      });

      // 신고 수가 임계값 이상이면 자동 비노출 처리
      final postDoc = await postRef.get();
      final reportCount = postDoc.data()?['reports'] as int? ?? 0;

      final authorUid = postDoc.data()?['uid'] as String?;
      if (authorUid != null) {
        // BondScoreService 메서드가 없으므로 주석 처리
        // await BondScoreService.applyReportPenalty(authorUid);
        final enthronePenaltyApplied =
            postDoc.data()?['enthroneBonusApplied'] as bool? ?? false;
        if (enthronePenaltyApplied) {
          // await BondScoreService.applyEnthroneBonusPenalty(authorUid);
          await postRef.update({'enthroneBonusApplied': false});
        }
      }

      if (reportCount >= autoHideThreshold) {
        await postRef.update({
          'isHidden': true,
          'hiddenReason': 'auto_hide_by_reports',
          'hiddenAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Post auto-hidden due to reports: $documentPath');
      }

      debugPrint('✅ reportPost: Success');
      return true;
    } catch (e) {
      debugPrint('⚠️ reportPost error: $e');
      return false;
    }
  }

  /// 내가 이 게시물을 신고했는지 확인
  static Future<bool> hasReported({
    required String documentPath,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      final doc = await _db.doc(documentPath).collection('reports').doc(uid).get();
      return doc.exists;
    } catch (e) {
      debugPrint('⚠️ hasReported error: $e');
      return false;
    }
  }

  /// 사용자 차단하기
  /// 
  /// 차단한 사용자의 글/리액션이 내 화면에서 숨겨집니다.
  static Future<bool> blockUser(String targetUid) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('blockedUsers')
          .doc(targetUid)
          .set({
        'blockedUid': targetUid,
        'blockedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ blockUser: $targetUid');
      return true;
    } catch (e) {
      debugPrint('⚠️ blockUser error: $e');
      return false;
    }
  }

  /// 사용자 차단 해제
  static Future<bool> unblockUser(String targetUid) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('blockedUsers')
          .doc(targetUid)
          .delete();

      debugPrint('✅ unblockUser: $targetUid');
      return true;
    } catch (e) {
      debugPrint('⚠️ unblockUser error: $e');
      return false;
    }
  }

  /// 차단한 사용자 목록 가져오기
  static Future<List<String>> getBlockedUsers() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    try {
      final snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('blockedUsers')
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['blockedUid'] as String)
          .toList();
    } catch (e) {
      debugPrint('⚠️ getBlockedUsers error: $e');
      return [];
    }
  }

  /// 특정 사용자를 차단했는지 확인
  static Future<bool> isBlocked(String targetUid) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      final doc = await _db
          .collection('users')
          .doc(uid)
          .collection('blockedUsers')
          .doc(targetUid)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('⚠️ isBlocked error: $e');
      return false;
    }
  }
}








