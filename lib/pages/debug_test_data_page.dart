import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/add_test_data.dart';
import '../services/partner_service.dart';

/// 디버그용 테스트 데이터 추가 페이지
class DebugTestDataPage extends StatefulWidget {
  const DebugTestDataPage({super.key});

  @override
  State<DebugTestDataPage> createState() => _DebugTestDataPageState();
}

class _DebugTestDataPageState extends State<DebugTestDataPage> {
  bool _loading = false;
  String _message = '';

  Future<void> _addTestData() async {
    setState(() {
      _loading = true;
      _message = '테스트 데이터 추가 중...';
    });

    try {
      await TestDataHelper.addTestData();
      setState(() {
        _loading = false;
        _message = '✅ 테스트 데이터가 추가되었습니다!';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _message = '⚠️ 오류 발생: $e';
      });
    }
  }

  Future<void> _clearTestData() async {
    setState(() {
      _loading = true;
      _message = '테스트 데이터 삭제 중...';
    });

    try {
      await TestDataHelper.clearTestBillboardPosts();
      await TestDataHelper.clearTestBondPosts();
      setState(() {
        _loading = false;
        _message = '✅ 테스트 데이터가 삭제되었습니다!';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _message = '⚠️ 오류 발생: $e';
      });
    }
  }

  /// 파트너 데이터 삭제 (내 그룹 + 매칭풀)
  Future<void> _clearPartnerData() async {
    setState(() {
      _loading = true;
      _message = '파트너 데이터 삭제 중...';
    });

    try {
      final db = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // 1. 내 그룹 ID 가져오기
      final userDoc = await db.collection('users').doc(uid).get();
      final groupId = userDoc.data()?['partnerGroupId'] as String?;

      if (groupId != null) {
        // 2. 그룹의 모든 멤버 가져오기
        final groupDoc =
            await db.collection('partnerGroups').doc(groupId).get();
        final memberUids = List<String>.from(
          groupDoc.data()?['memberUids'] ?? [],
        );

        // 3. 모든 멤버의 users 문서에서 파트너 정보 제거
        final batch = db.batch();
        for (final memberUid in memberUids) {
          batch.update(db.collection('users').doc(memberUid), {
            'partnerGroupId': FieldValue.delete(),
            'partnerGroupEndsAt': FieldValue.delete(),
            'partnerStatus': 'active', // active로 초기화
            'willMatchNextWeek': false, // false로 초기화
            'continueWithPartner': FieldValue.delete(),
          });
        }
        await batch.commit();

        // 4. 그룹 멤버 메타 삭제
        final memberMetaSnapshot =
            await db
                .collection('partnerGroups')
                .doc(groupId)
                .collection('memberMeta')
                .get();

        for (final doc in memberMetaSnapshot.docs) {
          await doc.reference.delete();
        }

        // 5. 그룹 문서 삭제
        await db.collection('partnerGroups').doc(groupId).delete();
      }

      // 6. 매칭풀에서 제거
      await db.collection('partnerMatchingPool').doc(uid).delete();

      setState(() {
        _loading = false;
        _message = '✅ 파트너 데이터가 삭제되었습니다!';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _message = '⚠️ 오류 발생: $e';
      });
    }
  }

  /// 모든 파트너 데이터 강제 삭제 (관리자용)
  Future<void> _forceDeleteAllPartnerData() async {
    setState(() {
      _loading = true;
      _message = '모든 파트너 데이터 강제 삭제 중...';
    });

    try {
      final db = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // 1. 모든 partnerGroups 삭제
      final groupsSnapshot = await db.collection('partnerGroups').get();
      debugPrint('🔍 삭제할 그룹 수: ${groupsSnapshot.docs.length}');

      for (final groupDoc in groupsSnapshot.docs) {
        // 서브컬렉션 memberMeta 삭제
        final memberMetaSnapshot =
            await groupDoc.reference.collection('memberMeta').get();

        for (final metaDoc in memberMetaSnapshot.docs) {
          await metaDoc.reference.delete();
        }

        // 그룹 문서 삭제
        await groupDoc.reference.delete();
        debugPrint('✅ 그룹 삭제: ${groupDoc.id}');
      }

      // 2. 모든 users에서 파트너 정보 제거
      final usersSnapshot = await db.collection('users').get();
      debugPrint('🔍 업데이트할 사용자 수: ${usersSnapshot.docs.length}');

      final batch = db.batch();
      for (final userDoc in usersSnapshot.docs) {
        batch.update(userDoc.reference, {
          'partnerGroupId': FieldValue.delete(),
          'partnerGroupEndsAt': FieldValue.delete(),
          'partnerStatus': 'active',
          'willMatchNextWeek': false,
          'continueWithPartner': FieldValue.delete(),
        });
      }
      await batch.commit();
      debugPrint('✅ 모든 사용자 업데이트 완료');

      // 3. 모든 매칭풀 삭제
      final poolSnapshot = await db.collection('partnerMatchingPool').get();
      debugPrint('🔍 삭제할 매칭풀 수: ${poolSnapshot.docs.length}');

      for (final poolDoc in poolSnapshot.docs) {
        await poolDoc.reference.delete();
      }
      debugPrint('✅ 모든 매칭풀 삭제 완료');

      // 4. 모든 continuePairs 삭제
      final pairsSnapshot = await db.collection('partnerContinuePairs').get();
      debugPrint('🔍 삭제할 페어 수: ${pairsSnapshot.docs.length}');

      for (final pairDoc in pairsSnapshot.docs) {
        await pairDoc.reference.delete();
      }
      debugPrint('✅ 모든 페어 삭제 완료');

      setState(() {
        _loading = false;
        _message = '✅ 모든 파트너 데이터가 강제 삭제되었습니다!';
      });
    } catch (e, stackTrace) {
      debugPrint('⚠️ 강제 삭제 오류: $e');
      debugPrint('⚠️ 스택: $stackTrace');
      setState(() {
        _loading = false;
        _message = '⚠️ 오류 발생: $e';
      });
    }
  }

  /// 테스트 매칭 시작
  Future<void> _startTestMatching() async {
    setState(() {
      _loading = true;
      _message = '매칭 요청 중...';
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // ━━━ 0단계: 진단 프린트 ━━━
      await _printDiagnostics(uid);

      // ━━━ 1단계: 만료 그룹 정리 ━━━
      debugPrint('🔍 [매칭] 1단계: 만료 그룹 정리 시작');
      await _cleanupExpiredGroups(uid);
      debugPrint('✅ [매칭] 1단계 완료');

      // ━━━ 2단계: 프로필 검증 ━━━
      debugPrint('🔍 [매칭] 2단계: 프로필 검증');
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data();

      if (userData != null) {
        debugPrint('🔍 [매칭] ━━━ 프로필 필드 확인 ━━━');
        debugPrint(
          '🔍 [매칭] isProfileCompleted: ${userData['isProfileCompleted']}',
        );
        debugPrint('🔍 [매칭] nickname: ${userData['nickname']}');
        debugPrint('🔍 [매칭] partnerGroupId: ${userData['partnerGroupId']}');

        final missingFields = <String>[];
        if (userData['isProfileCompleted'] != true)
          missingFields.add('isProfileCompleted');
        if (userData['nickname'] == null || userData['nickname'] == '')
          missingFields.add('nickname');
        if (userData['careerGroup'] == null || userData['careerGroup'] == '')
          missingFields.add('careerGroup');
        if (userData['region'] == null || userData['region'] == '')
          missingFields.add('region');
        if (userData['mainConcerns'] == null ||
            (userData['mainConcerns'] as List).isEmpty)
          missingFields.add('mainConcerns');

        if (missingFields.isNotEmpty) {
          debugPrint('⚠️ [매칭] 누락된 필수 필드: ${missingFields.join(", ")}');
        } else {
          debugPrint('✅ [매칭] 필수 필드 모두 존재');
        }
      }

      // ━━━ 3단계: 매칭 요청 ━━━
      debugPrint('🔍 [매칭] 3단계: PartnerService.requestMatching() 호출');
      final result = await PartnerService.requestMatching();
      debugPrint('🔍 [매칭] 결과 status: ${result.status}');
      debugPrint('🔍 [매칭] 결과 message: ${result.message}');
      debugPrint('🔍 [매칭] 결과 groupId: ${result.groupId}');
      if (result.errorCode != null) {
        debugPrint('🔍 [매칭] 결과 errorCode: ${result.errorCode}');
        debugPrint('🔍 [매칭] 결과 errorDetails: ${result.errorDetails}');
      }

      setState(() {
        _loading = false;
        if (result.status == MatchingStatus.matched) {
          _message = '✅ ${result.message}\n그룹 ID: ${result.groupId}';
        } else if (result.status == MatchingStatus.waiting) {
          _message = '⏳ ${result.message}';
        } else {
          // 에러: 테스트 빌드에서 상세 정보 표시
          _message = '⚠️ ${result.message}';
          if (result.errorCode != null) {
            _message += '\n\n━━━ 상세 정보 ━━━';
            _message += '\nCode: ${result.errorCode}';
            if (result.errorDetails != null) {
              _message += '\nDetails: ${result.errorDetails}';
            }
          }
        }
      });
    } catch (e, stackTrace) {
      debugPrint('⚠️ [매칭] 오류 발생: $e');
      debugPrint('⚠️ [매칭] 스택트레이스:\n$stackTrace');
      setState(() {
        _loading = false;
        _message = '⚠️ 오류 발생: $e';
      });
    }
  }

  /// 진단 프린트: 매칭 전 현재 유저 상태 출력
  Future<void> _printDiagnostics(String uid) async {
    final db = FirebaseFirestore.instance;

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔍 [진단] 현재 로그인 UID: $uid');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // users 문서 상세 조회
    final userDoc = await db.collection('users').doc(uid).get();
    final userData = userDoc.data();

    if (userData != null) {
      debugPrint('📄 [진단] ━━━ users/{uid} 필드 상태 ━━━');
      debugPrint(
        '  ✓ isProfileCompleted: ${userData['isProfileCompleted']} (존재: ${userData.containsKey('isProfileCompleted')})',
      );
      debugPrint('  ✓ nickname: ${userData['nickname']}');
      debugPrint('  ✓ region: ${userData['region']}');
      debugPrint('  ✓ careerBucket: ${userData['careerBucket']}');
      debugPrint('  ✓ careerGroup: ${userData['careerGroup']}');
      debugPrint('  ✓ mainConcerns: ${userData['mainConcerns']}');
      debugPrint(
        '  ✓ partnerGroupId: ${userData['partnerGroupId']} (존재: ${userData.containsKey('partnerGroupId')})',
      );
      debugPrint(
        '  ✓ partnerStatus: ${userData['partnerStatus']} (존재: ${userData.containsKey('partnerStatus')})',
      );
    } else {
      debugPrint('⚠️ [진단] users 문서가 존재하지 않습니다!');
    }

    debugPrint('');
    debugPrint('🔍 [진단] ━━━ partnerGroups 활성 그룹 검색 ━━━');

    // partnerGroups에서 활성 그룹 검색
    final activeGroupsQuery =
        await db
            .collection('partnerGroups')
            .where('isActive', isEqualTo: true)
            .where('memberUids', arrayContains: uid)
            .get();

    if (activeGroupsQuery.docs.isNotEmpty) {
      debugPrint('⚠️ [진단] 활성 그룹 발견! (${activeGroupsQuery.docs.length}개)');
      for (var doc in activeGroupsQuery.docs) {
        final data = doc.data();
        debugPrint('  - groupId: ${doc.id}');
        debugPrint('    endsAt: ${data['endsAt']}');
        debugPrint('    isActive: ${data['isActive']}');
        debugPrint('    memberUids: ${data['memberUids']}');
      }
    } else {
      debugPrint('✅ [진단] 활성 그룹 없음 (매칭 가능 상태)');
    }

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('');
  }

  /// 만료된 그룹 정리 (매칭 전 필수)
  Future<void> _cleanupExpiredGroups(String uid) async {
    final db = FirebaseFirestore.instance;

    // 현재 시간 (UTC 기준으로 통일)
    final now = DateTime.now().toUtc();

    // ━━━ A. users 문서의 partnerGroupId 확인 ━━━
    final userDoc = await db.collection('users').doc(uid).get();
    final userData = userDoc.data();
    final partnerGroupId = userData?['partnerGroupId'] as String?;

    if (partnerGroupId != null) {
      debugPrint('🔍 [정리] users 문서에 partnerGroupId 있음: $partnerGroupId');

      final groupDoc =
          await db.collection('partnerGroups').doc(partnerGroupId).get();
      if (groupDoc.exists) {
        final endsAtTimestamp = groupDoc.data()?['endsAt'] as Timestamp?;
        final endsAt = endsAtTimestamp?.toDate().toUtc(); // UTC로 변환!
        final isActive = groupDoc.data()?['isActive'] as bool? ?? true;

        debugPrint('🔍 [정리] 그룹 endsAt (UTC): $endsAt');
        debugPrint('🔍 [정리] 현재 시간 (UTC): $now');
        debugPrint('🔍 [정리] 그룹 isActive: $isActive');

        if (endsAt != null && endsAt.isBefore(now)) {
          debugPrint('⚠️ [정리] 그룹 만료됨 → 정리 시작');
          await db.collection('users').doc(uid).update({
            'partnerGroupId': FieldValue.delete(),
            'partnerGroupEndsAt': FieldValue.delete(),
          });

          // 그룹도 비활성화
          await db.collection('partnerGroups').doc(partnerGroupId).update({
            'isActive': false,
          });

          debugPrint('✅ [정리] users 문서 및 그룹 정리 완료');
        } else {
          debugPrint(
            '✅ [정리] 그룹이 아직 유효함 (남은 시간: ${endsAt?.difference(now).inHours ?? 0}시간)',
          );
        }
      } else {
        debugPrint('⚠️ [정리] 그룹 문서 없음 → partnerGroupId만 삭제');
        await db.collection('users').doc(uid).update({
          'partnerGroupId': FieldValue.delete(),
          'partnerGroupEndsAt': FieldValue.delete(),
        });
      }
    }

    // ━━━ B. 활성 그룹 멤버 검사 (보강) ━━━
    debugPrint('🔍 [정리] 활성 그룹 멤버 검사 시작');
    final activeGroupsSnapshot =
        await db
            .collection('partnerGroups')
            .where('isActive', isEqualTo: true)
            .where('memberUids', arrayContains: uid)
            .get();

    debugPrint('🔍 [정리] 활성 그룹 검색 결과: ${activeGroupsSnapshot.docs.length}개');

    for (final groupDoc in activeGroupsSnapshot.docs) {
      final endsAtTimestamp = groupDoc.data()['endsAt'] as Timestamp?;
      final endsAt = endsAtTimestamp?.toDate().toUtc(); // UTC로 변환!
      debugPrint('🔍 [정리] 그룹 ${groupDoc.id} endsAt (UTC): $endsAt');
      debugPrint('🔍 [정리] 현재 시간 (UTC): $now');

      if (endsAt != null && endsAt.isBefore(now)) {
        debugPrint('⚠️ [정리] 만료된 활성 그룹 발견 → 비활성화');
        await db.collection('partnerGroups').doc(groupDoc.id).update({
          'isActive': false,
        });

        // users 문서에서도 제거
        await db.collection('users').doc(uid).update({
          'partnerGroupId': FieldValue.delete(),
          'partnerGroupEndsAt': FieldValue.delete(),
        });

        debugPrint('✅ [정리] 그룹 ${groupDoc.id} 비활성화 완료');
      } else {
        debugPrint(
          '✅ [정리] 그룹 ${groupDoc.id}은 아직 유효함 (남은 시간: ${endsAt?.difference(now).inHours ?? 0}시간)',
        );
      }
    }

    debugPrint('✅ [정리] 모든 정리 작업 완료');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🔧 개발자 도구')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '테스트 데이터 관리',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _loading ? null : _addTestData,
              icon: const Icon(Icons.add),
              label: const Text('테스트 데이터 추가'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: const Color(0xFF6A5ACD),
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _loading ? null : _clearTestData,
              icon: const Icon(Icons.delete),
              label: const Text('테스트 데이터 삭제'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),

            // ━━━ 파트너 시스템 테스트 섹션 추가 ━━━
            const Text(
              '파트너 시스템 테스트',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💡 테스트 방법',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. 현재 계정에서 "파트너 데이터 삭제" 클릭\n'
                    '2. 다른 SNS로 2개 계정 더 만들기\n'
                    '3. 각 계정에서 프로필 완성 후 "매칭 시작" 클릭\n'
                    '4. 3명이 모이면 자동으로 그룹 생성!',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _loading ? null : _forceDeleteAllPartnerData,
              icon: const Icon(Icons.delete_forever),
              label: const Text('🔥 모든 파트너 데이터 강제 삭제'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _loading ? null : _clearPartnerData,
              icon: const Icon(Icons.group_remove),
              label: const Text('내 파트너 데이터 삭제'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _loading ? null : _startTestMatching,
              icon: const Icon(Icons.group_add),
              label: const Text('테스트 매칭 시작'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 20),

            if (_loading) const Center(child: CircularProgressIndicator()),

            if (_message.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      _message.contains('✅')
                          ? Colors.green.shade50
                          : _message.contains('⏳')
                          ? Colors.orange.shade50
                          : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _message,
                  style: TextStyle(
                    color:
                        _message.contains('✅')
                            ? Colors.green.shade900
                            : _message.contains('⏳')
                            ? Colors.orange.shade900
                            : Colors.red.shade900,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            const Divider(),

            const SizedBox(height: 20),

            const Text(
              'API 테스트',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            // 현재 UID 표시
            FutureBuilder<String?>(
              future: Future.value(FirebaseAuth.instance.currentUser?.uid),
              builder: (context, snapshot) {
                final uid = snapshot.data ?? '로그인 필요';
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '내 UID: $uid',
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: uid));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('UID 복사됨')),
                          );
                        },
                        tooltip: 'UID 복사',
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            const Divider(),

            const SizedBox(height: 20),

            const Text(
              '추가될 데이터:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('• 전광판 게시물 3개 (다양한 파트너 그룹)'),
            const Text('• 오늘을 나누기 게시물 3개 (민지, 지은, 나)'),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
