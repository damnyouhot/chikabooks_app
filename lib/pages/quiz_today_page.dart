import 'package:flutter/material.dart';
import '../widgets/hira_update_section.dart';

// ── 디자인 팔레트 (2탭과 통일) ──
const _kAccent = Color(0xFFF7CBCA);
const _kText = Color(0xFF5D6B6B);
const _kShadow1 = Color(0xFFDDD3D8);
const _kShadow2 = Color(0xFFD5E5E5);
const _kCardBg = Colors.white;

/// 오늘의 퀴즈 (Placeholder)
///
/// 매일 2문제 노출 예정. 현재는 뼈대/placeholder UI만.
/// 퀴즈 콘텐츠/데이터 모델은 추후 기획 확정 후 구현.
class QuizTodayPage extends StatelessWidget {
  const QuizTodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        // 헤더
        const Text(
          '오늘의 퀴즈',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _kText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '매일 2문제, 가볍게 풀어보세요.',
          style: TextStyle(fontSize: 13, color: _kText.withOpacity(0.5)),
        ),
        const SizedBox(height: 24),

        // 퀴즈 카드 1
        _QuizCard(
          index: 1,
          question: '치주낭 측정 시 사용하는 기구는?',
          options: const ['익스플로러', '치주 프로브', '스케일러', '큐렛'],
          correctIndex: 1,
        ),
        const SizedBox(height: 16),

        // 퀴즈 카드 2
        _QuizCard(
          index: 2,
          question: '치석 제거 후 치근면을 매끄럽게 하는 시술은?',
          options: const ['스케일링', '루트 플레이닝', '폴리싱', '불소 도포'],
          correctIndex: 1,
        ),

        const SizedBox(height: 32),

        // HIRA 수가/급여 변경 포인트 섹션
        const HiraUpdateSection(),

        const SizedBox(height: 32),
        Center(
          child: Text(
            '퀴즈 콘텐츠는 곧 업데이트됩니다.',
            style: TextStyle(fontSize: 12, color: _kText.withOpacity(0.4)),
          ),
        ),
      ],
    );
  }
}

/// 퀴즈 카드 위젯
class _QuizCard extends StatefulWidget {
  final int index;
  final String question;
  final List<String> options;
  final int correctIndex;

  const _QuizCard({
    required this.index,
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  @override
  State<_QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<_QuizCard> {
  int? _selectedIndex;
  bool _answered = false;

  void _onSelect(int idx) {
    if (_answered) return;
    setState(() {
      _selectedIndex = idx;
      _answered = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kShadow2, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: _kShadow1.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 문제 번호 + 질문
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kAccent.withOpacity(0.3),
                  border: Border.all(color: _kAccent, width: 0.5),
                ),
                child: Center(
                  child: Text(
                    'Q${widget.index}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.question,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 선택지
          ...List.generate(widget.options.length, (i) {
            final isCorrect = i == widget.correctIndex;
            final isSelected = i == _selectedIndex;

            Color bgColor = _kShadow2.withOpacity(0.3);
            Color textColor = _kText;
            Color borderColor = Colors.transparent;

            if (_answered) {
              if (isCorrect) {
                bgColor = const Color(0xFFE8F5E9);
                textColor = const Color(0xFF2E7D32);
                borderColor = const Color(0xFF66BB6A);
              } else if (isSelected && !isCorrect) {
                bgColor = const Color(0xFFFCE4EC);
                textColor = const Color(0xFFC62828);
                borderColor = const Color(0xFFEF5350);
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: borderColor == Colors.transparent ? 0.5 : 1.0),
                  ),
                  child: Text(
                    widget.options[i],
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor,
                      fontWeight:
                          (_answered && isCorrect) ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            );
          }),

          // 정답 피드백
          if (_answered)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _selectedIndex == widget.correctIndex
                    ? '정답이에요! 👏'
                    : '정답: ${widget.options[widget.correctIndex]}',
                style: TextStyle(
                  fontSize: 13,
                  color: _selectedIndex == widget.correctIndex
                      ? const Color(0xFF2E7D32)
                      : _kText.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}


