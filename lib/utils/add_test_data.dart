import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 테스트 데이터 추가 유틸리티
/// 
/// 사용법:
/// - Flutter 앱을 실행한 후
/// - 개발자 콘솔에서 TestDataHelper.addTestData() 호출
class TestDataHelper {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// 전체 테스트 데이터 추가
  static Future<void> addTestData() async {
    try {
      debugPrint('🔄 테스트 데이터 추가 시작...');
      
      // 1. 전광판 테스트 데이터
      await addBillboardTestPost();
      
      // 2. 오늘을 나누기 테스트 데이터
      await addBondTestPosts();
      
      debugPrint('✅ 테스트 데이터 추가 완료!');
    } catch (e) {
      debugPrint('⚠️ 테스트 데이터 추가 실패: $e');
    }
  }

  /// 전광판 테스트 게시물 추가 (다양한 파트너 그룹에서)
  static Future<void> addBillboardTestPost() async {
    try {
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 48));

      // 다양한 파트너 그룹의 게시물들
      final testPosts = [
        {
          'text': '오늘 환자분께 칭찬을 받았어요. 따뜻한 말 한마디가 이렇게 힘이 되는구나 느꼈습니다 ✨',
          'authorId': 'minji_24',
        },
        {
          'text': '처음으로 어려운 케이스를 성공했어요! 선배님들 덕분에 성장하는 느낌이에요 💪',
          'authorId': 'jieun_89',
        },
        {
          'text': '환자분이 "여기 올 때마다 기분이 좋아져요"라고 하셨어요. 정말 보람찼던 하루 😊',
          'authorId': 'hyunsu_dental',
        },
      ];

      for (int i = 0; i < testPosts.length; i++) {
        final post = testPosts[i];
        await _db.collection('billboardPosts').add({
          'sourceBondId': 'test-bond-group-$i',
          'sourcePostId': 'test-post-${now.millisecondsSinceEpoch}-$i',
          'textSnapshot': post['text'],
          'enthroneCount': 3,
          'requiredCount': 3,
          'createdAt': Timestamp.fromDate(now.subtract(Duration(minutes: i * 5))),
          'expiresAt': Timestamp.fromDate(expiresAt),
          'status': 'active',
          'bondGroupName': '결',  // 더 이상 출처로 사용하지 않음
          'isAnonymous': false,
          'authorId': post['authorId'],  // 추가: 원작자 ID
        });
      }

      debugPrint('✅ 전광판 테스트 게시물 ${testPosts.length}개 추가 완료');
    } catch (e) {
      debugPrint('⚠️ 전광판 테스트 게시물 추가 실패: $e');
    }
  }

  /// 오늘을 나누기 테스트 게시물 추가 (3개: 현재 사용자 + 파트너 2명)
  static Future<void> addBondTestPosts() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        debugPrint('⚠️ 로그인이 필요합니다.');
        return;
      }

      // 현재 사용자의 파트너 그룹 ID 가져오기
      final userDoc = await _db.collection('users').doc(uid).get();
      final partnerGroupId = userDoc.data()?['partnerGroupId'] as String?;

      if (partnerGroupId == null || partnerGroupId.isEmpty) {
        debugPrint('⚠️ 파트너 그룹에 가입되어 있지 않습니다.');
        return;
      }

      final bondGroupId = partnerGroupId;
      final now = DateTime.now();
      final kst = now.toUtc().add(const Duration(hours: 9));
      final dateKey = '${kst.year}-${kst.month.toString().padLeft(2, '0')}-${kst.day.toString().padLeft(2, '0')}';
      final timeSlot = kst.hour < 12 ? 'morning' : 'afternoon';

      // 테스트 게시물 3개 (현재 사용자 1개 + 파트너 2개)
      final testPosts = [
        {
          'text': '오늘 처음으로 스케일링을 혼자 완료했어요! 떨렸지만 잘 마무리했습니다 💪',
          'authorName': '민지',
          'uid': 'test_partner_minji_${DateTime.now().millisecondsSinceEpoch}',
        },
        {
          'text': '환자분이 "너무 꼼꼼하게 해주셔서 좋아요"라고 하셨어요. 힘이 나네요 😊',
          'authorName': '지은',
          'uid': 'test_partner_jieun_${DateTime.now().millisecondsSinceEpoch}',
        },
        {
          'text': '오늘은 힘든 하루였지만 파트너들 덕분에 버틸 수 있었어요. 감사합니다 🙏',
          'authorName': '나',
          'uid': uid, // 현재 사용자
        },
      ];

      for (final post in testPosts) {
        await _db
            .collection('bondGroups')
            .doc(bondGroupId)
            .collection('posts')
            .add({
          'text': post['text'],
          'uid': post['uid'],
          'bondGroupId': bondGroupId,
          'dateKey': dateKey,
          'timeSlot': timeSlot,
          'createdAt': Timestamp.fromDate(now.subtract(Duration(minutes: testPosts.indexOf(post) * 10))),
          'isDeleted': false,
          'publicEligible': true,
          'reports': 0,
          // 테스트용 메타 정보 (익명이 아닌 경우만)
          if (post['authorName'] != '나') '_testAuthorName': post['authorName'],
        });
      }

      debugPrint('✅ 오늘을 나누기 테스트 게시물 ${testPosts.length}개 추가 완료 (bondGroupId: $bondGroupId)');
    } catch (e) {
      debugPrint('⚠️ 오늘을 나누기 테스트 게시물 추가 실패: $e');
    }
  }

  /// 특정 전광판 게시물 삭제 (테스트 후 정리용)
  static Future<void> clearTestBillboardPosts() async {
    try {
      final snapshot = await _db
          .collection('billboardPosts')
          .where('sourceBondId', isEqualTo: 'test-bond-group')
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }

      debugPrint('✅ 전광판 테스트 게시물 삭제 완료 (${snapshot.docs.length}개)');
    } catch (e) {
      debugPrint('⚠️ 전광판 테스트 게시물 삭제 실패: $e');
    }
  }

  /// 테스트 Bond 게시물 삭제 (테스트 후 정리용)
  static Future<void> clearTestBondPosts() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final userDoc = await _db.collection('users').doc(uid).get();
      final partnerGroupId = userDoc.data()?['partnerGroupId'] as String?;
      if (partnerGroupId == null) return;

      final snapshot = await _db
          .collection('bondGroups')
          .doc(partnerGroupId)
          .collection('posts')
          .where('uid', whereIn: ['test_partner_민지', 'test_partner_지은', 'test_partner_현수'])
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }

      debugPrint('✅ 오늘을 나누기 테스트 게시물 삭제 완료 (${snapshot.docs.length}개)');
    } catch (e) {
      debugPrint('⚠️ 오늘을 나누기 테스트 게시물 삭제 실패: $e');
    }
  }
}

