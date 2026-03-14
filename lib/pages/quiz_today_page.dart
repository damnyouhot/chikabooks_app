import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_muted_card.dart';
import '../core/widgets/app_primary_card.dart';
import '../core/widgets/glass_card.dart';

/// 퀴즈 탭 글래스 모드 플래그
/// true: 검정+블루(우상단)+형광(좌하단) 그라디언트 배경
/// false: 기존 soft gray 배경
const bool kQuizGlassMode = false;

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
    if (!kQuizGlassMode) {
      return ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        children: _buildChildren(),
      );
    }

    // ── 글래스 모드: 검정 + 블루(우상단) + 형광(좌하단) ──
    return Stack(
      children: [
        // 1. 순수 검정 베이스
        Container(color: const Color(0xFF080808)),

        // 2. 우상단 블루 — 큰 글로우
        Positioned(
          top: -60,
          right: -40,
          child: GlowBlob(
            color: AppColors.blue,
            width: 260,
            height: 300,
            opacity: 0.55,
          ),
        ),

        // 3. 우상단 블루 — 집중 하이라이트
        Positioned(
          top: 30,
          right: 20,
          child: GlowBlob(
            color: AppColors.blue,
            width: 120,
            height: 140,
            opacity: 0.35,
          ),
        ),

        // 4. 좌하단 형광 라임 — 큰 글로우
        Positioned(
          bottom: 60,
          left: -60,
          child: GlowBlob(
            color: AppColors.lime,
            width: 260,
            height: 300,
            opacity: 0.50,
          ),
        ),

        // 5. 좌하단 형광 라임 — 집중 하이라이트
        Positioned(
          bottom: 100,
          left: 20,
          child: GlowBlob(
            color: AppColors.lime,
            width: 130,
            height: 150,
            opacity: 0.30,
          ),
        ),

        // 6. 콘텐츠 레이어
        ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          children: _buildChildren(),
        ),
      ],
    );
  }

  /// 리스트 콘텐츠 (글래스/일반 공용)
  List<Widget> _buildChildren() {
    return [
      _QuizStatsCard(
        totalCorrect: _totalCorrect,
        totalWrong: _totalWrong,
        weekCorrect: _weekCorrect,
        weekWrong: _weekWrong,
        myRank: _myRank,
        totalUsers: _totalUsers,
        isLoaded: _statsLoaded,
        glassMode: kQuizGlassMode,
      ),
      const SizedBox(height: AppSpacing.lg),
      _QuizCard(
        index: 1,
        question: '치주낭 측정 시 사용하는 기구는?',
        options: const ['익스플로러', '치주 프로브', '스케일러', '큐렛'],
        correctIndex: 1,
        onAnswered: _onQuizAnswered,
        glassMode: kQuizGlassMode,
      ),
      const SizedBox(height: AppSpacing.lg),
      _QuizCard(
        index: 2,
        question: '치석 제거 후 치근면을 매끄럽게 하는 시술은?',
        options: const ['스케일링', '루트 플레이닝', '폴리싱', '불소 도포'],
        correctIndex: 1,
        onAnswered: _onQuizAnswered,
        glassMode: kQuizGlassMode,
      ),
      const SizedBox(height: AppSpacing.xxl + 8),
      Center(
        child: Text(
          '퀴즈 콘텐츠는 곧 업데이트됩니다.',
          style: TextStyle(
            fontSize: 12,
            color: kQuizGlassMode
                ? AppColors.white.withOpacity(0.35)
                : AppColors.textDisabled,
          ),
        ),
      ),
    ];
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
  final bool glassMode;

  const _QuizStatsCard({
    required this.totalCorrect,
    required this.totalWrong,
    required this.weekCorrect,
    required this.weekWrong,
    required this.myRank,
    required this.totalUsers,
    required this.isLoaded,
    this.glassMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final totalTotal = totalCorrect + totalWrong;
    final weekTotal  = weekCorrect + weekWrong;
    final totalRate  = totalTotal > 0 ? (totalCorrect / totalTotal * 100) : 0.0;
    final weekRate   = weekTotal  > 0 ? (weekCorrect  / weekTotal  * 100) : 0.0;
    final topPercent = totalUsers > 0
        ? (myRank / totalUsers * 100).clamp(1.0, 100.0)
        : 100.0;

    final dividerColor = glassMode
        ? AppColors.white.withOpacity(0.15)
        : AppColors.onCardPrimary.withOpacity(0.2);

    final inner = !isLoaded
        ? SizedBox(
            height: 80,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: glassMode ? AppColors.white : null,
              ),
            ),
          )
        : IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: _statColumn('이번 주', weekCorrect,  weekWrong,  weekRate)),
                VerticalDivider(width: 1, thickness: 1, color: dividerColor),
                Expanded(child: _statColumn('통산',    totalCorrect, totalWrong, totalRate)),
                VerticalDivider(width: 1, thickness: 1, color: dividerColor),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '순위',
                        style: TextStyle(
                          fontSize: 11,
                          color: glassMode
                              ? AppColors.white.withOpacity(0.6)
                              : AppColors.onCardPrimary.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '상위 ${topPercent.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.quizCorrect,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$myRank / $totalUsers명',
                        style: TextStyle(
                          fontSize: 10,
                          color: glassMode
                              ? AppColors.white.withOpacity(0.4)
                              : AppColors.onCardPrimary.withOpacity(0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

    if (glassMode) {
      return GlassCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: inner,
      );
    }

    return AppPrimaryCard(
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: inner,
    );
  }

  Widget _statColumn(String label, int correct, int wrong, double rate) {
    final labelColor = glassMode
        ? AppColors.white.withOpacity(0.6)
        : AppColors.onCardPrimary.withOpacity(0.7);
    final valueColor = glassMode ? AppColors.white : AppColors.onCardPrimary;
    final subColor   = glassMode
        ? AppColors.white.withOpacity(0.4)
        : AppColors.onCardPrimary.withOpacity(0.55);

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: labelColor, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Text(
          '${rate.toStringAsFixed(0)}%',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: valueColor),
        ),
        const SizedBox(height: 2),
        Text(
          '✓$correct / ✗$wrong',
          style: TextStyle(fontSize: 10, color: subColor),
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
  final bool glassMode;

  const _QuizCard({
    required this.index,
    required this.question,
    required this.options,
    required this.correctIndex,
    this.onAnswered,
    this.glassMode = false,
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
    final questionColor = widget.glassMode ? AppColors.white : AppColors.textPrimary;
    final feedbackColor = _selectedIndex == widget.correctIndex
        ? AppColors.quizCorrect
        : (widget.glassMode
            ? AppColors.white.withOpacity(0.7)
            : AppColors.textSecondary);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 문제 번호 + 질문
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (ctx) {
                final badgeSize =
                    (MediaQuery.of(ctx).size.width * 0.07).clamp(24.0, 34.0);
                return Container(
                  width: badgeSize,
                  height: badgeSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.glassMode
                        ? AppColors.white.withOpacity(0.20)
                        : AppColors.accent.withOpacity(0.15),
                  ),
                  child: Center(
                    child: Text(
                      'Q${widget.index}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: widget.glassMode ? AppColors.white : AppColors.accent,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                widget.question,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: questionColor,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // 선택지
        ...List.generate(widget.options.length, (i) {
          final isCorrect  = i == widget.correctIndex;
          final isSelected = i == _selectedIndex;

          Color bgColor   = widget.glassMode
              ? AppColors.white.withOpacity(0.12)
              : AppColors.surfaceMuted;
          Color textColor = widget.glassMode ? AppColors.white : AppColors.textPrimary;

          if (_answered) {
            if (isCorrect) {
              bgColor   = AppColors.quizCorrectBg;
              textColor = AppColors.quizCorrect;
            } else if (isSelected && !isCorrect) {
              bgColor   = AppColors.quizWrongBg;
              textColor = AppColors.quizWrong;
            }
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: GestureDetector(
              onTap: () => _onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  widget.options[i],
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor,
                    fontWeight: (_answered && isCorrect)
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
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              _selectedIndex == widget.correctIndex
                  ? '정답이에요! 👏'
                  : '정답: ${widget.options[widget.correctIndex]}',
              style: TextStyle(
                fontSize: 13,
                color: feedbackColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );

    if (widget.glassMode) {
      return GlassCard(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: content,
      );
    }

    return AppMutedCard(
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: content,
    );
  }
}
