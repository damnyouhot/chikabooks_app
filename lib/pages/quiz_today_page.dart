import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/tab_theme.dart';

// ── 디자인 팔레트: TabTheme.growth 참조 ──
// 색상 변경 → app_colors.dart Primitive만 수정하면 자동 반영
final _g        = TabTheme.growth;
final _kAccent  = _g.accent;    // Black (Neon bg → Black accent)
final _kText    = _g.onBg;      // Black (Inversion)
final _kShadow1 = _g.border;    // 라임계열 경계선
final _kShadow2 = _g.surface;   // 연한 구분선
final _kCardBg  = _g.cardBg;    // 카드 배경: 흰색
// 퀴즈 정답/오답: 의미 컬러로 AppColors Component Override 사용
const _kCorrect = AppColors.quizCorrect;

/// 오늘의 퀴즈
///
/// 매일 2문제 노출 예정. 현재는 뼈대/placeholder UI.
/// 퀴즈 콘텐츠/데이터 모델은 추후 기획 확정 후 구현.
class QuizTodayPage extends StatefulWidget {
  const QuizTodayPage({super.key});

  @override
  State<QuizTodayPage> createState() => _QuizTodayPageState();
}

class _QuizTodayPageState extends State<QuizTodayPage> {
  // ── 성적 데이터 (Firestore 연동 준비) ──
  int _totalCorrect = 0;
  int _totalWrong = 0;
  int _weekCorrect = 0;
  int _weekWrong = 0;
  int _totalUsers = 1; // 전체 유저 수 (순위 계산용)
  int _myRank = 1; // 내 순위
  bool _statsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _statsLoaded = true);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('quizStats')
          .doc('summary')
          .get();

      if (doc.exists && mounted) {
        final data = doc.data() ?? {};
        setState(() {
          _totalCorrect = (data['totalCorrect'] as int?) ?? 0;
          _totalWrong = (data['totalWrong'] as int?) ?? 0;
          _weekCorrect = (data['weekCorrect'] as int?) ?? 0;
          _weekWrong = (data['weekWrong'] as int?) ?? 0;
          _myRank = (data['rank'] as int?) ?? 1;
          _totalUsers = (data['totalUsers'] as int?) ?? 1;
          _statsLoaded = true;
        });
      } else {
        if (mounted) setState(() => _statsLoaded = true);
      }
    } catch (e) {
      debugPrint('⚠️ 퀴즈 성적 로드 실패: $e');
      if (mounted) setState(() => _statsLoaded = true);
    }
  }

  /// 퀴즈 정답/오답 결과 콜백
  void _onQuizAnswered(bool isCorrect) {
    setState(() {
      if (isCorrect) {
        _totalCorrect++;
        _weekCorrect++;
      } else {
        _totalWrong++;
        _weekWrong++;
      }
    });
    // TODO: Firestore에 결과 저장
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // ── 퀴즈 성적 카드 ──
        _QuizStatsCard(
          totalCorrect: _totalCorrect,
          totalWrong: _totalWrong,
          weekCorrect: _weekCorrect,
          weekWrong: _weekWrong,
          myRank: _myRank,
          totalUsers: _totalUsers,
          isLoaded: _statsLoaded,
        ),
        const SizedBox(height: 16),

        // 퀴즈 카드 1
        _QuizCard(
          index: 1,
          question: '치주낭 측정 시 사용하는 기구는?',
          options: const ['익스플로러', '치주 프로브', '스케일러', '큐렛'],
          correctIndex: 1,
          onAnswered: _onQuizAnswered,
        ),
        const SizedBox(height: 16),

        // 퀴즈 카드 2
        _QuizCard(
          index: 2,
          question: '치석 제거 후 치근면을 매끄럽게 하는 시술은?',
          options: const ['스케일링', '루트 플레이닝', '폴리싱', '불소 도포'],
          correctIndex: 1,
          onAnswered: _onQuizAnswered,
        ),

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

// ── 퀴즈 성적 카드 ──────────────────────────────────────────
class _QuizStatsCard extends StatelessWidget {
  final int totalCorrect;
  final int totalWrong;
  final int weekCorrect;
  final int weekWrong;
  final int myRank;
  final int totalUsers;
  final bool isLoaded;

  const _QuizStatsCard({
    required this.totalCorrect,
    required this.totalWrong,
    required this.weekCorrect,
    required this.weekWrong,
    required this.myRank,
    required this.totalUsers,
    required this.isLoaded,
  });

  @override
  Widget build(BuildContext context) {
    final totalTotal = totalCorrect + totalWrong;
    final weekTotal = weekCorrect + weekWrong;
    final totalRate = totalTotal > 0 ? (totalCorrect / totalTotal * 100) : 0.0;
    final weekRate = weekTotal > 0 ? (weekCorrect / weekTotal * 100) : 0.0;
    final topPercent = totalUsers > 0
        ? (myRank / totalUsers * 100).clamp(1.0, 100.0)
        : 100.0;

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: !isLoaded
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : IntrinsicHeight(
              child: Row(
              children: [
                // 이번 주 성적
                Expanded(
                  child: _statColumn(
                    '이번 주',
                    weekCorrect,
                    weekWrong,
                    weekRate,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: _kShadow2.withOpacity(0.5),
                ),
                // 통산 성적
                Expanded(
                  child: _statColumn(
                    '통산',
                    totalCorrect,
                    totalWrong,
                    totalRate,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: _kShadow2.withOpacity(0.5),
                ),
                // 순위
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '순위',
                        style: TextStyle(
                          fontSize: 11,
                          color: _kText.withOpacity(0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '상위 ${topPercent.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _kCorrect,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$myRank / $totalUsers명',
                        style: TextStyle(
                          fontSize: 10,
                          color: _kText.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
    );
  }

  Widget _statColumn(String label, int correct, int wrong, double rate) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: _kText.withOpacity(0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${rate.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _kText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '✓$correct / ✗$wrong',
          style: TextStyle(
            fontSize: 10,
            color: _kText.withOpacity(0.4),
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
  final ValueChanged<bool>? onAnswered;

  const _QuizCard({
    required this.index,
    required this.question,
    required this.options,
    required this.correctIndex,
    this.onAnswered,
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
    widget.onAnswered?.call(idx == widget.correctIndex);
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
              // Q번호 원형 배지: 화면 너비의 7%, 최소24·최대34 clamp
              Builder(
                builder: (ctx) {
                  final badgeSize = (MediaQuery.of(ctx).size.width * 0.07)
                      .clamp(24.0, 34.0);
                  return Container(
                    width: badgeSize,
                    height: badgeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kAccent.withOpacity(0.3),
                  border: Border.all(color: _kAccent, width: 0.5),
                ),
                child: Center(
                  child: Text(
                    'Q${widget.index}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.question,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
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
                bgColor = AppColors.quizCorrectBg;
                textColor = AppColors.quizCorrect;
                borderColor = AppColors.quizCorrectBorder;
              } else if (isSelected && !isCorrect) {
                bgColor = AppColors.quizWrongBg;
                textColor = AppColors.quizWrong;
                borderColor = AppColors.quizWrongBorder;
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: borderColor,
                      width: borderColor == Colors.transparent ? 0.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    widget.options[i],
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor,
                      fontWeight:
                          (_answered && isCorrect)
                              ? FontWeight.w600
                              : FontWeight.w400,
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
                  color:
                      _selectedIndex == widget.correctIndex
                          ? AppColors.quizCorrect
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
