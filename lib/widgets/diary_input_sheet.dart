import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import '../pages/diary_timeline_page.dart';

/// 나만 보는 한 줄 기록 (BottomSheet)
/// 
/// 디자인 큐:
/// - 아래에서 올라오는 작은 팝업 (BottomSheet)
/// - 제목: "오늘 한마디"
/// - 서브: "나만 보는 기록이에요"
/// - 입력창: 1~2줄, 최대 140자
/// - 버튼: 왼쪽 "취소", 오른쪽 "저장"
class DiaryInputSheet extends StatefulWidget {
  final Function(String) onSaved;
  
  const DiaryInputSheet({super.key, required this.onSaved});

  /// BottomSheet 표시
  static Future<void> show(BuildContext context, Function(String) onSaved) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DiaryInputSheet(onSaved: onSaved),
    );
  }

  @override
  State<DiaryInputSheet> createState() => _DiaryInputSheetState();
}

class _DiaryInputSheetState extends State<DiaryInputSheet> {
  final _controller = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('로그인 필요');

      // Firestore 저장: users/{uid}/notes/{noteId}
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notes')
          .add({
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'visibility': 'private',
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved(text);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목 + 기록 보기 버튼
            Row(
              children: [
                const Text(
                  '오늘, 지금',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5D6B6B),
                  ),
                ),
                const Spacer(),
                // 기록 보기 버튼
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DiaryTimelinePage(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7BA5A5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history,
                          size: 16,
                          color: const Color(0xFF7BA5A5),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '어제',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7BA5A5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 서브타이틀
            Text(
              '나만 보는 기록이에요',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            // 입력창
            TextField(
              controller: _controller,
              maxLength: 140,
              maxLines: 2,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '지금 마음을 한 문장으로 남겨볼까?',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF7BA5A5), // 기존 팔레트 _colorAccent
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 버튼들
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '취소',
                    style: TextStyle(
                      color: Color(0xFF5D6B6B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7BA5A5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('저장'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 저장 후 캐릭터 응답 멘트 선택
/// 
/// 입력 내용 키워드 분석 → 적절한 응답 반환
class DiaryResponseService {
  static final List<String> _responses = [
    "좋아, 이 문장… 오늘의 너를 잘 담았어.",
    "적어줘서 고마워. 마음이 조금은 가벼워졌으면.",
    "그 마음, 내가 기억해둘게.",
    "한 줄이면 충분해. 오늘은 이 정도면 돼.",
    "지금의 너를 있는 그대로 인정해주자.",
    "음… 이 말 속에 '참고 있음'이 보여.",
    "오늘의 기분은 오늘에 두고, 내일은 새로 시작하자.",
    "그 감정, 나한테는 꽤 선명하게 들렸어.",
    "괜찮아. 너는 늘 최선을 다하고 있어.",
    "좋은 날이든 나쁜 날이든, 기록은 힘이 돼.",
    "이 문장 덕분에 너 마음에 의자가 하나 놓인 느낌이야.",
    "오늘은 '버틴 날'로 체크해둘게.",
    "지금까지 온 것만으로도 충분히 멋져.",
    "너는 생각보다 훨씬 단단해.",
    "이 말, 나중에 너에게 위로가 될 거야.",
    "조금 울컥했어… 너 마음이 느껴져서.",
    "좋아! 이 흐름 유지해보자. 아주 작은 것부터.",
    "오늘의 너를 내가 토닥토닥.",
    "내가 옆에서 조용히 응원할게.",
    "완벽한 문장 아니어도 돼. 솔직해서 좋아.",
    "그래… 그랬구나. 그럼 오늘은 쉬운 것만 하자.",
    "너무 세게 자신을 몰아붙이지 마.",
    "한 문장인데, 오늘 하루가 보이는 것 같아.",
    "적어둔 건 사라지지 않아. 너의 편이 되어줄 거야.",
  ];

  /// 입력 텍스트 분석 → 응답 멘트 반환
  static String getRandomResponse(String inputText) {
    final text = inputText.toLowerCase();
    
    // 짧은 문장
    if (inputText.length < 10) {
      return "짧게 말했지만 마음이 느껴져.";
    }
    
    // 스트레스/힘듦 키워드
    if (text.contains('힘들') || 
        text.contains('지쳐') || 
        text.contains('불안') ||
        text.contains('우울') ||
        text.contains('슬프')) {
      final stressedPool = [
        "괜찮아. 너는 늘 최선을 다하고 있어.",
        "오늘은 '버틴 날'로 체크해둘게.",
        "지금까지 온 것만으로도 충분히 멋져.",
        "음… 이 말 속에 '참고 있음'이 보여.",
        "그래… 그랬구나. 그럼 오늘은 쉬운 것만 하자.",
        "너무 세게 자신을 몰아붙이지 마.",
      ];
      return stressedPool[Random().nextInt(stressedPool.length)];
    }
    
    // 긍정 키워드
    if (text.contains('좋아') || 
        text.contains('행복') || 
        text.contains('뿌듯') ||
        text.contains('기쁘') ||
        text.contains('감사')) {
      final positivePool = [
        "좋아! 이 흐름 유지해보자. 아주 작은 것부터.",
        "오늘의 너를 내가 토닥토닥.",
        "내가 옆에서 조용히 응원할게.",
      ];
      return positivePool[Random().nextInt(positivePool.length)];
    }
    
    // 기본 랜덤
    return _responses[Random().nextInt(_responses.length)];
  }
}

