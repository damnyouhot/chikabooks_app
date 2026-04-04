import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_badge.dart';
import '../core/widgets/app_muted_card.dart';
import '../core/widgets/app_primary_card.dart';
import '../core/widgets/glass_card.dart';
import '../models/quiz_pool_item.dart';
import '../models/quiz_schedule.dart';
import '../services/admin_activity_service.dart';
import '../services/funnel_onboarding_service.dart';
import '../services/quiz_content_config_service.dart';
import '../services/quiz_pool_service.dart';
import '../widgets/quiz/quiz_share_capture.dart';

/// 퀴즈 탭 글래스 모드 플래그
const bool kQuizGlassMode = false;

/// 오늘의 퀴즈 페이지
///
/// quiz_schedule/{dateKey} 기반 데이터 연동.
/// - 오늘의 퀴즈 2문제 표시
/// - 지난 3일간 퀴즈 보기 섹션
class QuizTodayPage extends StatefulWidget {
  const QuizTodayPage({super.key});

  @override
  State<QuizTodayPage> createState() => _QuizTodayPageState();
}

class _QuizTodayPageState extends State<QuizTodayPage> {
  // ── 성적 데이터 ──
  int _totalCorrect = 0;
  int _totalWrong = 0;
  int _weekCorrect = 0;
  int _weekWrong = 0;
  int _totalUsers = 1;
  int _myRank = 1;
  bool _statsLoaded = false;
  /// `users/.../quizStats/summary` 의 `countedInGlobal` — 글로벌 집계 반영 여부 (로컬 순위 갱신 규칙용)
  bool _countedInGlobal = false;
  Map<String, int> _scoreDistribution = {};

  // ── 오늘 스케줄 & 유저 기록 ──
  QuizSchedule? _todaySchedule;
  UserQuizHistory? _todayHistory;
  bool _scheduleLoaded = false;

  // ── 지난 3일 ──
  List<QuizSchedule> _recentSchedules = [];
  Map<String, UserQuizHistory> _recentHistories = {};
  bool _recentLoaded = false;

  // ── 지난 퀴즈 펼치기 여부 ──
  bool _recentExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadStats(), _loadTodaySchedule()]);
  }

  Future<void> _loadStats() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _statsLoaded = true);
        return;
      }

      // 유저 개인 통계 + 글로벌 집계 병렬 로드 (서버 우선 → 최신 순위 보장)
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('quizStats')
            .doc('summary')
            .get(const GetOptions(source: Source.server)),
        FirebaseFirestore.instance
            .collection('quiz_global')
            .doc('stats')
            .get(const GetOptions(source: Source.server)),
      ]);

      final userDoc = results[0];
      final globalDoc = results[1];
      if (!mounted) return;

      // 글로벌 집계에서 참여자 수 · 점수 분포 추출
      int totalParticipants = 1;
      Map<String, dynamic> distribution = {};
      if (globalDoc.exists) {
        final gData = globalDoc.data() ?? {};
        totalParticipants = (gData['totalParticipants'] as num?)?.toInt() ?? 1;
        if (totalParticipants < 1) totalParticipants = 1;
        distribution = Map<String, dynamic>.from(
          gData['scoreDistribution'] as Map<String, dynamic>? ?? {},
        );
        debugPrint(
          '📊 [LoadStats] global exists: participants=$totalParticipants, dist=$distribution',
        );
      } else {
        debugPrint('📊 [LoadStats] quiz_global/stats 문서 없음');
      }

      if (userDoc.exists) {
        final data = userDoc.data() ?? {};

        // 이번 주 월요일 dateKey (KST 기준)
        final nowKst = DateTime.now().toUtc().add(const Duration(hours: 9));
        final monday = nowKst.subtract(Duration(days: nowKst.weekday - 1));
        final thisWeekKey =
            '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
        final storedWeekKey = data['weekKey'] as String?;
        final isSameWeek = storedWeekKey == thisWeekKey;

        final totalCorrect = (data['totalCorrect'] as num?)?.toInt() ?? 0;

        // 순위 계산: 내 totalCorrect보다 높은 사람 수 + 1
        int peopleAboveMe = 0;
        for (final entry in distribution.entries) {
          final score = int.tryParse(entry.key) ?? 0;
          if (score > totalCorrect) {
            peopleAboveMe += (entry.value as num?)?.toInt() ?? 0;
          }
        }

        debugPrint(
          '📊 [LoadStats] myTotalCorrect=$totalCorrect, '
          'peopleAboveMe=$peopleAboveMe, '
          'rank=${peopleAboveMe + 1}/$totalParticipants',
        );

        setState(() {
          _totalCorrect = totalCorrect;
          _totalWrong = (data['totalWrong'] as num?)?.toInt() ?? 0;
          _weekCorrect =
              isSameWeek ? ((data['weekCorrect'] as num?)?.toInt() ?? 0) : 0;
          _weekWrong =
              isSameWeek ? ((data['weekWrong'] as num?)?.toInt() ?? 0) : 0;
          _myRank = peopleAboveMe + 1;
          _totalUsers = totalParticipants;
          _countedInGlobal = data['countedInGlobal'] == true;
          _scoreDistribution = distribution.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          );
          _statsLoaded = true;
        });
      } else {
        // 퀴즈 미참여자: summary 없음 — 글로벌 분포는 그대로 두어 첫 답 시 로컬 순위 보정 가능
        setState(() {
          _totalCorrect = 0;
          _totalWrong = 0;
          _weekCorrect = 0;
          _weekWrong = 0;
          _myRank = totalParticipants;
          _totalUsers = totalParticipants;
          _countedInGlobal = false;
          _scoreDistribution = distribution.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          );
          _statsLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('⚠️ 퀴즈 성적 로드 실패: $e');
      if (mounted) setState(() => _statsLoaded = true);
    }
  }

  Future<void> _loadTodaySchedule() async {
    try {
      final dateKey = QuizPoolService.todayKey;
      final cfgF = QuizContentConfigService.getConfig();
      final results = await Future.wait([
        cfgF.then((c) => QuizPoolService.getTodaySchedule(contentConfig: c)),
        QuizPoolService.getHistory(dateKey),
      ]);

      if (mounted) {
        setState(() {
          _todaySchedule = results[0] as QuizSchedule?;
          _todayHistory = results[1] as UserQuizHistory?;
          _scheduleLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('⚠️ 오늘 퀴즈 로드 실패: $e');
      if (mounted) setState(() => _scheduleLoaded = true);
    }
  }

  Future<void> _loadRecentSchedules() async {
    if (_recentLoaded) return;
    try {
      final cfg = await QuizContentConfigService.getConfig();
      final results = await Future.wait([
        QuizPoolService.getRecentSchedules(days: 3, contentConfig: cfg),
        QuizPoolService.getRecentHistories(days: 4),
      ]);

      if (mounted) {
        setState(() {
          _recentSchedules = results[0] as List<QuizSchedule>;
          _recentHistories = results[1] as Map<String, UserQuizHistory>;
          _recentLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('⚠️ 지난 퀴즈 로드 실패: $e');
      if (mounted) setState(() => _recentLoaded = true);
    }
  }

  /// [QuizPoolService.saveAnswer] 트랜잭션과 동일한 규칙으로 `_myRank` 갱신
  void _recomputeLocalRank() {
    if (_scoreDistribution.isEmpty) return;
    var peopleAboveMe = 0;
    for (final entry in _scoreDistribution.entries) {
      final score = int.tryParse(entry.key) ?? 0;
      if (score > _totalCorrect) {
        peopleAboveMe += entry.value;
      }
    }
    _myRank = peopleAboveMe + 1;
  }

  void _onQuizAnswered({
    required String dateKey,
    required String quizId,
    required int selectedIndex,
    required bool isCorrect,
    required List<String> allIds,
  }) {
    final prevTotalCorrect = _totalCorrect;
    final wasCountedInGlobal = _countedInGlobal;

    setState(() {
      if (isCorrect) {
        _totalCorrect++;
        _weekCorrect++;
      } else {
        _totalWrong++;
        _weekWrong++;
      }

      // 로컬 history 즉시 반영
      final prev = _todayHistory;
      final prevAnswers = Map<String, int>.from(prev?.answers ?? {});
      prevAnswers[quizId] = selectedIndex;
      _todayHistory = UserQuizHistory(
        dateKey: dateKey,
        quizIds: allIds,
        answers: prevAnswers,
        correctCount: (prev?.correctCount ?? 0) + (isCorrect ? 1 : 0),
        rewardGranted: prev?.rewardGranted ?? false,
      );

      // 로컬 순위 즉시 반영 (saveAnswer 트랜잭션과 동일)
      if (!wasCountedInGlobal) {
        _totalUsers += 1;
        final bucketKey = _totalCorrect.toString();
        _scoreDistribution[bucketKey] = (_scoreDistribution[bucketKey] ?? 0) + 1;
        _countedInGlobal = true;
        _recomputeLocalRank();
      } else if (isCorrect && _scoreDistribution.isNotEmpty) {
        final oldKey = prevTotalCorrect.toString();
        final newKey = _totalCorrect.toString();
        final prevBucketCount = _scoreDistribution[oldKey] ?? 0;
        if (prevBucketCount <= 0) {
          // 팬텀 유저: 분포에 이전 구간 없음 → 신규 등록과 동일하게 처리
          _totalUsers += 1;
          _scoreDistribution[newKey] = (_scoreDistribution[newKey] ?? 0) + 1;
        } else {
          final oldCount = prevBucketCount - 1;
          if (oldCount > 0) {
            _scoreDistribution[oldKey] = oldCount;
          } else {
            _scoreDistribution.remove(oldKey);
          }
          _scoreDistribution[newKey] = (_scoreDistribution[newKey] ?? 0) + 1;
        }
        _recomputeLocalRank();
      }
    });

    AdminActivityService.log(ActivityEventType.quizCompleted, page: 'growth');
    unawaited(FunnelOnboardingService.tryLogFirstQuiz());

    QuizPoolService.saveAnswer(
      dateKey: dateKey,
      quizId: quizId,
      selectedIndex: selectedIndex,
      allQuizIds: allIds,
      isCorrect: isCorrect,
    ).then((_) => _loadStats());
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

    return Stack(
      children: [
        Container(color: const Color(0xFF080808)),
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

  List<Widget> _buildChildren() {
    return [
      // ── 성적 카드 ──
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

      // ── 오늘의 퀴즈 ──
      if (!_scheduleLoaded)
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        )
      else if (_todaySchedule == null)
        _buildNoScheduleBanner()
      else
        ..._buildTodayQuizCards(),

      const SizedBox(height: AppSpacing.xl),

      // ── 지난 3일간 퀴즈보기 ──
      _RecentQuizSection(
        expanded: _recentExpanded,
        loaded: _recentLoaded,
        schedules: _recentSchedules,
        histories: _recentHistories,
        glassMode: kQuizGlassMode,
        onToggle: () async {
          if (!_recentExpanded) await _loadRecentSchedules();
          if (mounted) setState(() => _recentExpanded = !_recentExpanded);
        },
      ),

      const SizedBox(height: AppSpacing.xxl + 8),
    ];
  }

  Widget _buildNoScheduleBanner() {
    return AppMutedCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Icon(Icons.quiz_outlined, size: 40, color: AppColors.textDisabled),
          const SizedBox(height: AppSpacing.md),
          const Text(
            '오늘의 퀴즈 준비 중',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            '매일 자정에 새로운 문제가 업데이트됩니다.',
            style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTodayQuizCards() {
    final schedule = _todaySchedule!;
    final dateKey = schedule.dateKey;
    final allIds = schedule.quizIds;

    return List.generate(schedule.items.length, (i) {
      final item = schedule.items[i];
      final savedAnswer = _todayHistory?.answers[item.id];

      return Padding(
        padding: EdgeInsets.only(
          bottom: i < schedule.items.length - 1 ? AppSpacing.lg : 0,
        ),
        child: _QuizCard(
          index: i + 1,
          quizId: item.id,
          question: item.question,
          options: item.options,
          correctIndex: item.correctIndex,
          explanation: item.explanation,
          questionType: item.questionType,
          sourceBook: item.sourceBook,
          sourceFileName: item.sourceFileName,
          sourcePage: item.sourcePage,
          sourceName: item.sourceName,
          savedAnswer: savedAnswer,
          glassMode: kQuizGlassMode,
          onAnswered:
              (idx, isCorrect) => _onQuizAnswered(
                dateKey: dateKey,
                quizId: item.id,
                selectedIndex: idx,
                isCorrect: isCorrect,
                allIds: allIds,
              ),
        ),
      );
    });
  }
}

// ══════════════════════════════════════════════════════════════
// 성적 카드
// ══════════════════════════════════════════════════════════════
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
    final weekTotal = weekCorrect + weekWrong;
    final totalRate = totalTotal > 0 ? (totalCorrect / totalTotal * 100) : 0.0;
    final weekRate = weekTotal > 0 ? (weekCorrect / weekTotal * 100) : 0.0;
    final rawTopPct =
        totalUsers > 0 ? (myRank / totalUsers * 100).clamp(0.0, 100.0) : 0.0;
    final topPctStr =
        rawTopPct >= 10
            ? rawTopPct.toStringAsFixed(1)
            : rawTopPct.toStringAsFixed(2);

    final dividerColor =
        glassMode
            ? AppColors.white.withValues(alpha: 0.15)
            : AppColors.onCardPrimary.withValues(alpha: 0.2);

    final inner =
        !isLoaded
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
                  Expanded(
                    child: _statColumn(
                      '이번 주',
                      weekCorrect,
                      weekWrong,
                      weekRate,
                    ),
                  ),
                  VerticalDivider(width: 1, thickness: 1, color: dividerColor),
                  Expanded(
                    child: _statColumn(
                      '통산',
                      totalCorrect,
                      totalWrong,
                      totalRate,
                    ),
                  ),
                  VerticalDivider(width: 1, thickness: 1, color: dividerColor),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '상위',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                glassMode
                                    ? AppColors.white.withValues(alpha: 0.6)
                                    : AppColors.onCardPrimary.withValues(
                                      alpha: 0.7,
                                    ),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$topPctStr%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color:
                                glassMode
                                    ? AppColors.white
                                    : AppColors.creamWhite,
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
    final labelColor =
        glassMode
            ? AppColors.white.withValues(alpha: 0.6)
            : AppColors.onCardPrimary.withValues(alpha: 0.7);
    final valueColor = glassMode ? AppColors.white : AppColors.onCardPrimary;
    final subColor =
        glassMode
            ? AppColors.white.withValues(alpha: 0.4)
            : AppColors.onCardPrimary.withValues(alpha: 0.55);

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: labelColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${rate.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '✓$correct / ✗$wrong',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: subColor,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 지난 3일간 퀴즈보기 섹션
// ══════════════════════════════════════════════════════════════
class _RecentQuizSection extends StatelessWidget {
  final bool expanded;
  final bool loaded;
  final List<QuizSchedule> schedules;
  final Map<String, UserQuizHistory> histories;
  final bool glassMode;
  final VoidCallback onToggle;

  const _RecentQuizSection({
    required this.expanded,
    required this.loaded,
    required this.schedules,
    required this.histories,
    required this.glassMode,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 헤더 탭 ──
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color:
                  glassMode
                      ? AppColors.white.withValues(alpha: 0.06)
                      : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 18,
                  color:
                      glassMode
                          ? AppColors.white.withValues(alpha: 0.7)
                          : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  '지난 3일간 퀴즈보기',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color:
                        glassMode
                            ? AppColors.white.withValues(alpha: 0.85)
                            : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color:
                        glassMode
                            ? AppColors.white.withValues(alpha: 0.5)
                            : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── 펼쳐진 내용 ──
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child:
              expanded
                  ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: _buildContent(context),
                  )
                  : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (!loaded) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (schedules.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            '지난 퀴즈 기록이 없습니다.',
            style: TextStyle(
              fontSize: 13,
              color:
                  glassMode
                      ? AppColors.white.withValues(alpha: 0.4)
                      : AppColors.textDisabled,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          schedules.map((schedule) {
            final history = histories[schedule.dateKey];
            return _RecentDayQuizGroup(
              schedule: schedule,
              history: history,
              glassMode: glassMode,
            );
          }).toList(),
    );
  }
}

// ── 날짜별 퀴즈 그룹 ──
class _RecentDayQuizGroup extends StatelessWidget {
  final QuizSchedule schedule;
  final UserQuizHistory? history;
  final bool glassMode;

  const _RecentDayQuizGroup({
    required this.schedule,
    required this.history,
    required this.glassMode,
  });

  String _formatDateLabel(String dateKey) {
    // '2026-03-15' → '3월 15일'
    final parts = dateKey.split('-');
    if (parts.length != 3) return dateKey;
    return '${int.tryParse(parts[1]) ?? parts[1]}월 ${int.tryParse(parts[2]) ?? parts[2]}일';
  }

  @override
  Widget build(BuildContext context) {
    final correctCount = history?.correctCount ?? 0;
    final answered = history?.answers.length ?? 0;
    final total = schedule.items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 날짜 헤더 ──
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Text(
                _formatDateLabel(schedule.dateKey),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color:
                      glassMode
                          ? AppColors.white.withValues(alpha: 0.7)
                          : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              if (answered >= total && total > 0)
                _ScoreBadge(
                  correct: correctCount,
                  total: total,
                  glassMode: glassMode,
                )
              else if (answered > 0)
                Text(
                  '$answered/$total 풀이',
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        glassMode
                            ? AppColors.white.withValues(alpha: 0.4)
                            : AppColors.textDisabled,
                  ),
                )
              else
                Text(
                  '미풀이',
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        glassMode
                            ? AppColors.white.withValues(alpha: 0.3)
                            : AppColors.textDisabled,
                  ),
                ),
            ],
          ),
        ),

        // ── 퀴즈 카드들 (읽기 전용) ──
        ...List.generate(schedule.items.length, (i) {
          final item = schedule.items[i];
          final savedAnswer = history?.answers[item.id];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _QuizCard(
              index: i + 1,
              quizId: item.id,
              question: item.question,
              options: item.options,
              correctIndex: item.correctIndex,
              explanation: item.explanation,
              questionType: item.questionType,
              sourceBook: item.sourceBook,
              sourceFileName: item.sourceFileName,
              sourcePage: item.sourcePage,
              sourceName: item.sourceName,
              savedAnswer: savedAnswer,
              readOnly: true, // 지난 퀴즈: 답 변경 불가
              glassMode: glassMode,
            ),
          );
        }),

        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

// ── 점수 배지 ──
class _ScoreBadge extends StatelessWidget {
  final int correct;
  final int total;
  final bool glassMode;

  const _ScoreBadge({
    required this.correct,
    required this.total,
    required this.glassMode,
  });

  @override
  Widget build(BuildContext context) {
    final allCorrect = correct == total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: allCorrect ? AppColors.quizCorrectBg : AppColors.quizWrongBg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        '$correct/$total 정답',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: allCorrect ? AppColors.quizCorrect : AppColors.quizWrongText,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 퀴즈 카드
// ══════════════════════════════════════════════════════════════

/// 퀴즈 카드 위젯
///
/// - [readOnly]: true면 이미 선택된 답을 보여주기만 함 (지난 퀴즈)
/// - [savedAnswer]: 이전에 저장된 답 인덱스
/// - 색상은 AppColors.quiz* / AppColors.poll* 시맨틱 토큰 사용
class _QuizCard extends StatefulWidget {
  final int index;
  final String quizId;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String questionType;
  final String sourceBook;     // 출처 책 이름
  final String sourceFileName; // 출처 파일명 (e.g. 치과책방_…pdf — 스토리지 파일명 접두 유지)
  final String sourcePage;     // 출처 페이지
  final String sourceName;    // 국시 등 책 외 출처 한 줄
  final int? savedAnswer;
  final bool readOnly;
  final bool glassMode;
  final void Function(int selectedIndex, bool isCorrect)? onAnswered;

  const _QuizCard({
    required this.index,
    required this.quizId,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.questionType = QuizPoolItem.kClinical,
    this.sourceBook = '',
    this.sourceFileName = '',
    this.sourcePage = '',
    this.sourceName = '',
    this.savedAnswer,
    this.readOnly = false,
    this.glassMode = false,
    this.onAnswered,
  });

  @override
  State<_QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<_QuizCard> {
  int? _selectedIndex;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    // 이전에 저장된 답 복원 (readOnly 또는 앱 재시작 후 복구)
    if (widget.savedAnswer != null) {
      _selectedIndex = widget.savedAnswer;
      _answered = true;
    }
  }

  void _onSelect(int idx) {
    if (_answered || widget.readOnly) return;
    setState(() {
      _selectedIndex = idx;
      _answered = true;
    });
    widget.onAnswered?.call(idx, idx == widget.correctIndex);
  }

  Future<void> _shareQuizAsImage() async {
    try {
      await QuizShareCapture.share(
        context,
        qIndex: widget.index,
        question: widget.question,
        questionType: widget.questionType,
        quizId: widget.quizId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('공유에 실패했어요. $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final questionColor =
        widget.glassMode ? AppColors.white : AppColors.textPrimary;

    final feedbackColor =
        _selectedIndex == widget.correctIndex
            ? AppColors.quizCorrect
            : (widget.glassMode
                ? AppColors.white.withValues(alpha: 0.7)
                : AppColors.textSecondary);

    final optionList = Column(
      children: List.generate(widget.options.length, (i) {
        final isCorrect = i == widget.correctIndex;
        final isSelected = i == _selectedIndex;

        Color bgColor;
        Color textColor;

        if (_answered) {
          if (isCorrect) {
            bgColor = AppColors.quizCorrectBg;
            textColor = AppColors.quizCorrect;
          } else if (isSelected) {
            bgColor = AppColors.quizWrongBg;
            textColor = AppColors.quizWrong;
          } else {
            bgColor =
                widget.glassMode
                    ? AppColors.white.withValues(alpha: 0.12)
                    : AppColors.pollOptionBg;
            textColor =
                widget.glassMode ? AppColors.white : AppColors.pollOptionText;
          }
        } else if (isSelected) {
          bgColor =
              widget.glassMode
                  ? AppColors.white.withValues(alpha: 0.25)
                  : AppColors.pollOptionSelectedBg;
          textColor =
              widget.glassMode
                  ? AppColors.white
                  : AppColors.pollOptionSelectedText;
        } else {
          bgColor =
              widget.glassMode
                  ? AppColors.white.withValues(alpha: 0.12)
                  : AppColors.pollOptionBg;
          textColor =
              widget.glassMode ? AppColors.white : AppColors.pollOptionText;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: GestureDetector(
            onTap: () => _onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  // 라디오 아이콘 또는 정오답 아이콘
                  _buildOptionIcon(i, isCorrect, isSelected),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.options[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            (!_answered && isSelected) ||
                                    (_answered && isCorrect)
                                ? FontWeight.w700
                                : FontWeight.w400,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );

    final typeBadgeBg =
        widget.glassMode
            ? AppColors.white.withValues(alpha: 0.14)
            : (widget.questionType == QuizPoolItem.kNationalExam
                ? AppColors.accent.withValues(alpha: 0.14)
                : AppColors.disabledBg);
    final typeBadgeText =
        widget.glassMode
            ? AppColors.white.withValues(alpha: 0.95)
            : (widget.questionType == QuizPoolItem.kNationalExam
                ? AppColors.accent
                : AppColors.textSecondary);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 공감 투표 카드와 동일: 첫 줄 Q · 국시/임상 · 공유, 질문은 그 아래
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppBadge(
                label: 'Q${widget.index}',
                bgColor:
                    widget.glassMode
                        ? AppColors.white.withValues(alpha: 0.20)
                        : AppColors.pollBadgeBg,
                textColor:
                    widget.glassMode
                        ? AppColors.white
                        : AppColors.pollBadgeText,
              ),
              const SizedBox(width: 8),
              AppBadge(
                label: QuizPoolItem.badgeLabelForType(widget.questionType),
                bgColor: typeBadgeBg,
                textColor: typeBadgeText,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.share_outlined, size: 20),
                color:
                    widget.glassMode
                        ? AppColors.white.withValues(alpha: 0.85)
                        : AppColors.textSecondary,
                tooltip: '공유',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: _shareQuizAsImage,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 10, AppSpacing.xl, AppSpacing.lg),
          child: Text(
            widget.question,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: questionColor,
              height: 1.45,
            ),
          ),
        ),

        // 선택지 목록
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: optionList,
        ),

        // 임상 문제 참고 안내 (보기 아래)
        if (widget.questionType == QuizPoolItem.kClinical)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
            child: Text(
              '참고: 임상 문제는 노하우나 적용의 유연성에 대한 내용으로 상황에 따라 해석이 달라질 수 있습니다.',
              style: TextStyle(
                fontSize: 11,
                height: 1.45,
                color:
                    widget.glassMode
                        ? AppColors.white.withValues(alpha: 0.45)
                        : AppColors.textDisabled,
              ),
            ),
          ),

        // 정답 피드백 + 해설
        if (_answered)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedIndex == widget.correctIndex
                      ? '정답이에요! 👏'
                      : '정답: ${widget.options[widget.correctIndex]}',
                  style: TextStyle(
                    fontSize: 13,
                    color: feedbackColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.explanation.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.explanation,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          widget.glassMode
                              ? AppColors.white.withValues(alpha: 0.55)
                              : AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
                // 출처 표시 (임상만 — 국시는 표시하지 않음)
                if (widget.questionType == QuizPoolItem.kClinical &&
                    (widget.sourceBook.isNotEmpty ||
                        widget.sourceFileName.isNotEmpty)) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 11,
                        color:
                            widget.glassMode
                                ? AppColors.white.withValues(alpha: 0.35)
                                : AppColors.textDisabled,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          () {
                            // sourceFileName에서 .pdf 제거 후 '_' → 공백 (표시용)
                            // 출처 브랜드: 이미 '치과책방'이면 유지, 없으면 접두(구 '하이진랩' 접두는 치과책방으로 치환)
                            String bookName = widget.sourceFileName.isNotEmpty
                                ? widget.sourceFileName.replaceAll(
                                    RegExp(r'\.pdf$', caseSensitive: false), '')
                                : widget.sourceBook;

                            if (bookName.isNotEmpty) {
                              bookName = bookName.replaceAll('_', ' ');
                              const kChikabooks = '치과책방';
                              const kHygieneLab = '하이진랩';
                              if (!bookName.startsWith(kChikabooks)) {
                                if (bookName.startsWith(kHygieneLab)) {
                                  bookName =
                                      '$kChikabooks${bookName.substring(kHygieneLab.length)}';
                                } else {
                                  bookName = '$kChikabooks $bookName';
                                }
                              }
                            }

                            return widget.sourcePage.isNotEmpty
                                ? '출처: $bookName p.${widget.sourcePage}'
                                : '출처: $bookName';
                          }(),
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                widget.glassMode
                                    ? AppColors.white.withValues(alpha: 0.35)
                                    : AppColors.textDisabled,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
      ],
    );

    if (widget.glassMode) {
      return GlassCard(padding: EdgeInsets.zero, child: content);
    }
    return AppMutedCard(
      radius: AppRadius.xl,
      padding: EdgeInsets.zero,
      child: content,
    );
  }

  Widget _buildOptionIcon(int i, bool isCorrect, bool isSelected) {
    if (_answered) {
      if (isCorrect) {
        return const Icon(
          Icons.check_circle_rounded,
          size: 18,
          color: AppColors.quizCorrect,
        );
      } else if (isSelected) {
        return Icon(Icons.cancel_rounded, size: 18, color: AppColors.quizWrong);
      } else {
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.textDisabled.withValues(alpha: 0.4),
              width: 0.8,
            ),
          ),
        );
      }
    }

    // 미응답 상태
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            isSelected
                ? AppColors.pollOptionSelectedText.withValues(alpha: 0.15)
                : Colors.transparent,
        border: Border.all(
          color:
              isSelected
                  ? AppColors.pollOptionSelectedText.withValues(alpha: 0.6)
                  : AppColors.textDisabled.withValues(alpha: 0.5),
          width: isSelected ? 1.5 : 0.8,
        ),
      ),
      child:
          isSelected
              ? Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.pollOptionSelectedText,
                  ),
                ),
              )
              : null,
    );
  }
}
