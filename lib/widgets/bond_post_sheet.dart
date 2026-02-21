import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/bond_post_service.dart';

/// "오늘을 나누기" BottomSheet
/// 완전 자유 입력 (최대 200자)
class BondPostSheet extends StatefulWidget {
  const BondPostSheet({super.key});

  @override
  State<BondPostSheet> createState() => _BondPostSheetState();
}

class _BondPostSheetState extends State<BondPostSheet> {
  final _controller = TextEditingController();
  final _db = FirebaseFirestore.instance;
  bool _posting = false;
  int _remainingPosts = 2;

  // 욕설 필터링 (간단한 예시)
  final _badWords = [
    '씨발',
    '개새끼',
    '병신',
    '좆',
    '개같',
    '지랄',
    '미친',
    'ㅅㅂ',
    'ㅂㅅ',
    'ㅈㄹ',
  ];

  bool _containsBadWord(String text) {
    final lower = text.toLowerCase();
    return _badWords.any((word) => lower.contains(word));
  }

  @override
  void initState() {
    super.initState();
    _checkPostingStatus();
  }

  Future<void> _checkPostingStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    // 현재 사용자의 파트너 그룹 ID 가져오기
    final userDoc = await _db.collection('users').doc(uid).get();
    final partnerGroupId = userDoc.data()?['partnerGroupId'] as String?;
    
    if (partnerGroupId == null || partnerGroupId.isEmpty) return;
    
    final status = await BondPostService.getPostingStatus(partnerGroupId);
    if (mounted) {
      setState(() {
        _remainingPosts = status['remainingToday'] as int;
      });
    }
  }

  Future<void> _submit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showSnack('로그인이 필요합니다.');
      return;
    }

    debugPrint('🔍 [글쓰기] 1단계: 쿨타임 체크 시작');
    
    // 현재 사용자의 파트너 그룹 ID 가져오기
    final userDoc = await _db.collection('users').doc(uid).get();
    final partnerGroupId = userDoc.data()?['partnerGroupId'] as String?;
    
    if (partnerGroupId == null || partnerGroupId.isEmpty) {
      _showSnack('파트너 그룹에 가입해야 글을 쓸 수 있어요.');
      return;
    }
    
    debugPrint('🔍 [글쓰기] partnerGroupId: $partnerGroupId');

    // 시간대별 제한 체크
    final status = await BondPostService.getPostingStatus(partnerGroupId);
    
    debugPrint('🔍 [글쓰기] 2단계: 쿨타임 결과 = ${status['canPostNow']}');
    debugPrint('🔍 [글쓰기] 메시지 = ${status['message']}');
    
    if (!(status['canPostNow'] as bool)) {
      debugPrint('❌ [글쓰기] 쿨타임으로 리턴됨');
      _showSnack(status['message'] as String);
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty) {
      _showSnack('내용을 입력해 주세요.');
      return;
    }
    if (text.length > 200) {
      _showSnack('200자 이내로 작성해 주세요.');
      return;
    }
    if (_containsBadWord(text)) {
      _showSnack('부적절한 표현이 포함되어 있어요.');
      return;
    }

    setState(() => _posting = true);
    try {
      final currentSlot = BondPostService.getCurrentTimeSlot();
      final now = DateTime.now(); // 클라이언트 타임스탬프
      
      debugPrint('🔍 [글쓰기] 3단계: Firestore 저장 시작');
      debugPrint('🔍 [글쓰기] 경로: partnerGroups/$partnerGroupId/posts');
      
      // partnerGroups/{partnerGroupId}/posts에 저장
      await _db
          .collection('partnerGroups')
          .doc(partnerGroupId)
          .collection('posts')
          .add({
        'uid': uid,
        'text': text,
        'bondGroupId': partnerGroupId,
        'dateKey': BondPostService.todayDateKey(),
        'timeSlot': currentSlot.name,
        'createdAt': FieldValue.serverTimestamp(), // 서버 타임스탬프 (정확도)
        'createdAtClient': Timestamp.fromDate(now), // 클라이언트 타임스탬프 (즉시 정렬 가능)
        'isDeleted': false,
        'publicEligible': true,
        'reports': 0,
      });
      
      debugPrint('✅ [글쓰기] 4단계: Firestore 저장 성공!');
      
      if (mounted) {
        Navigator.pop(context);
        _showSnack('기록되었어요 ✨');
      }
    } catch (e) {
      debugPrint('❌ [글쓰기] Firestore 저장 실패: $e');
      _showSnack('오류가 발생했어요: $e');
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 키보드 높이 가져오기
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    return GestureDetector(
      onTap: () => Navigator.pop(context), // 팝업 바깥 터치 시 닫기
      child: Container(
        color: Colors.transparent,
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollCtrl) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 24 + keyboardHeight, // 키보드 높이만큼 하단 패딩 추가
              ),
              child: SingleChildScrollView(
                controller: scrollCtrl,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 제목
                    const Text(
                      '오늘을 나누기',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6A5ACD),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _remainingPosts > 0 
                          ? '오늘 $_remainingPosts번 더 나눌 수 있어요'
                          : '오늘은 이미 2번 나눴어요',
                      style: TextStyle(
                        fontSize: 12,
                        color: _remainingPosts > 0 ? Colors.grey[600] : Colors.red[400],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '기분을 나누면 더 기쁘고 덜 힘들어요',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),

                    // 입력창
                    TextField(
                      controller: _controller,
                      maxLength: 200,
                      maxLines: 5,
                      autofocus: true, // 자동 포커스
                      decoration: InputDecoration(
                        hintText: '오늘 느낀 감정, 고민, 기쁨을 편하게 나눠주세요.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF6A5ACD),
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _posting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF7CBCA), // _kAccent
                          foregroundColor: const Color(0xFF5D6B6B), // _kText
                          disabledBackgroundColor: Colors.grey[300],
                          disabledForegroundColor: Colors.grey[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _posting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: const Color(0xFF5D6B6B), // _kText
                                ),
                              )
                            : const Text(
                                '남기기',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

