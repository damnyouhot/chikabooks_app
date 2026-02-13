import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// "결을 같이하기" BottomSheet
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

  Future<void> _submit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showSnack('로그인이 필요합니다.');
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
      await _db.collection('bondPosts').add({
        'uid': uid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'reports': 0,
      });
      if (mounted) {
        Navigator.pop(context);
        _showSnack('기록되었어요 ✨');
      }
    } catch (e) {
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
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // 제목
              const Text(
                '✍️ 결을 같이하기',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6A5ACD),
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

              const Spacer(),

              // 버튼
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _posting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A5ACD),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _posting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
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
        );
      },
    );
  }
}

