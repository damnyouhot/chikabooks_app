import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/widgets/app_modal_scaffold.dart';
import '../../../models/daily_word.dart';
import '../../../models/quiz_pool_item.dart';
import '../../../models/quiz_schedule.dart';
import '../../../services/admin_dashboard_service.dart';
import '../../../services/daily_word_service.dart';
import '../../../services/quiz_content_config_service.dart';
import '../../../services/quiz_pool_service.dart';
import '../widgets/admin_common_widgets.dart';

/// 운영 액션 전담 탭
///
/// Overview 탭에 섞여 있던 「공감투표 운영 / 퀴즈 풀 / 오늘 단어 / 오늘 문제」를
/// 한 탭으로 모은 콘텐츠 운영 허브입니다. 모든 액션은 Cloud Function 콜러블을
/// 거치며, 운영자가 실수로 누르지 않도록 확인 모달을 강제합니다.
///
/// ── 책임 ─────────────────────────────────────────────────────
/// 1. quiz_meta / quiz_schedule / poll / daily_word 풀 상태 표시
/// 2. 슬롯·투표·단어 다음 넘기기 / 삭제 액션
/// 3. 운영 허브(`getContentOpsHub`) 1회 호출로 부수 데이터 묶음 로드
/// ──────────────────────────────────────────────────────────────
class AdminContentOpsTab extends StatefulWidget {
  const AdminContentOpsTab({super.key});

  @override
  State<AdminContentOpsTab> createState() => _AdminContentOpsTabState();
}

class _AdminContentOpsTabState extends State<AdminContentOpsTab>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => false;

  bool _loading = true;
  String? _error;
  DateTime? _lastSync;

  QuizMetaState? _quizMeta;
  QuizSchedule? _todaySchedule;
  bool _syncingQuizMeta = false;
  bool _reschedulingTodayQuiz = false;
  bool _previewingNextQuiz = false;
  bool _mutatingNationalSlot = false;
  bool _mutatingClinicalSlot = false;
  DailyWordOpsSummary? _dailyWordOps;
  bool _advancingDailyWordTurn = false;

  Map<String, dynamic>? _pollOps;
  Map<String, dynamic>? _quizSlotNextPreviews;
  bool _advancingPollQueue = false;
  bool _deletingCurrentPoll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _load();
    }
  }

  /// 콘텐츠 운영 패널은 액션 호출 후 즉시 최신 상태를 봐야 하므로,
  /// 한 번에 모든 소스를 다시 읽는다. Overview처럼 KPI 11개를 묶지 않기 때문에
  /// 부분 실패가 발생해도 다른 카드 표시는 유지되도록 try/catch를 카드 단위로 분리.
  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    QuizMetaState? quizMeta;
    QuizSchedule? todaySchedule;
    Map<String, dynamic>? pollOps;
    Map<String, dynamic>? slotPreviews;
    DailyWordOpsSummary? dailyOps;
    final partialErrors = <String>[];

    try {
      quizMeta = await AdminDashboardService.getQuizMetaState();
    } catch (e) {
      partialErrors.add('퀴즈 메타: $e');
    }

    try {
      final cfg = await QuizContentConfigService.getConfig();
      todaySchedule = await QuizPoolService.getTodaySchedule(
        contentConfig: cfg,
      );
    } catch (e) {
      partialErrors.add('오늘 스케줄: $e');
    }

    try {
      final hub = await AdminDashboardService.getContentOpsHub(
        schedulePreviewDays: 21,
      );
      if (hub != null && hub['success'] == true) {
        pollOps = _coerceMap(hub['pollOps']);
        final quiz = _coerceMap(hub['quiz']);
        slotPreviews = _coerceMap(quiz?['todaySlotNextPreviews']);
      }
    } catch (e) {
      partialErrors.add('운영 허브: $e');
    }

    try {
      dailyOps = await DailyWordService.loadOpsSummary();
    } catch (e) {
      partialErrors.add('오늘 단어: $e');
    }

    if (!mounted) return;
    setState(() {
      _quizMeta = quizMeta;
      _todaySchedule = todaySchedule;
      _pollOps = pollOps;
      _quizSlotNextPreviews = slotPreviews;
      _dailyWordOps = dailyOps;
      _lastSync = DateTime.now();
      _loading = false;
      // 일부만 실패하면 화면은 보여주되, 상단에 안내만 노출.
      _error = partialErrors.isNotEmpty ? partialErrors.join('\n') : null;
    });
  }

  Map<String, dynamic>? _coerceMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  Future<void> _syncQuizMetaFromSchedules() async {
    setState(() => _syncingQuizMeta = true);
    try {
      await AdminDashboardService.rebuildQuizMetaFromSchedules();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('퀴즈 메타가 스케줄과 동기화되었습니다.')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('동기화 실패: $e')));
    } finally {
      if (mounted) setState(() => _syncingQuizMeta = false);
    }
  }

  Future<void> _rescheduleTodayQuiz() async {
    final today = QuizPoolService.todayKey;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AppConfirmModal(
            title: '오늘 퀴즈 스케줄 다시 만들기',
            message:
                '날짜 $today 의 quiz_schedule을 덮어씁니다.\n'
                '모든 사용자의 오늘 퀴즈가 새로 선정된 문항으로 바뀝니다. 진행할까요?',
            confirmLabel: '덮어쓰기',
          ),
    );
    if (ok != true || !mounted) return;

    setState(() => _reschedulingTodayQuiz = true);
    try {
      final data = await AdminDashboardService.manualScheduleQuiz(
        targetDate: today,
        forceReplace: true,
      );
      if (!mounted) return;
      final success = data?['success'] == true;
      final msg =
          data?['message'] as String? ??
          (success ? '스케줄을 갱신했습니다.' : '스케줄 갱신에 실패했습니다.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('오류: $e')));
    } finally {
      if (mounted) setState(() => _reschedulingTodayQuiz = false);
    }
  }

  Future<void> _runPreviewNextQuiz() async {
    setState(() => _previewingNextQuiz = true);
    try {
      final m = await AdminDashboardService.previewNextQuizSelection();
      if (!mounted) return;
      if (m == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('시뮬 응답이 비어 있습니다.')));
        return;
      }
      if (m['success'] != true) {
        final msg = m['message'] as String? ?? '시뮬에 실패했습니다.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
        return;
      }

      final disclaimer = m['disclaimer'] as String? ?? '';
      final wasReset = m['wasReset'] == true;
      final cycle = m['cycleCountUsed'];
      final usedN = m['hypotheticalUsedQuizIdsCount'];
      final itemsRaw = m['items'] as List<dynamic>? ?? [];
      Map<String, dynamic>? cfg;
      final cfgRaw = m['contentConfig'];
      if (cfgRaw is Map) {
        cfg = Map<String, dynamic>.from(cfgRaw);
      }

      String packLine(String label, String id, bool includeLoose) {
        final idStr = id.trim();
        final tail = includeLoose ? ' · 묶음 없음 포함' : ' · 묶음 없음 제외';
        if (idStr.isEmpty) return '$label: (전체)';
        return '$label: $idStr$tail';
      }

      final clinId = cfg?['currentClinicalPackId'] as String? ?? '';
      final natId = cfg?['currentNationalPackId'] as String? ?? '';
      final clinLoose = cfg?['includeClinicalWithoutPack'] != false;
      final natLoose = cfg?['includeNationalWithoutPack'] != false;

      await showDialog<void>(
        context: context,
        builder:
            (dialogCtx) => AppModalDialog(
              insetPadding: const EdgeInsets.all(AppSpacing.xl),
              borderOpacity: 0.7,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '예상 다음 문제 (시뮬)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(dialogCtx).height * 0.55,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            disclaimer,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.95,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '가정 사이클: $cycle · 이 선정까지 사이클 초기화 경로: ${wasReset ? "예" : "아니오"} · '
                            '가정 usedQuizIds 길이: $usedN',
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            packLine('임상 패크', clinId, clinLoose),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textDisabled,
                            ),
                          ),
                          Text(
                            packLine('국시 패크', natId, natLoose),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textDisabled,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '이번 호출에서 뽑힌 문항',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...itemsRaw.map((raw) {
                            if (raw is! Map) {
                              return const SizedBox.shrink();
                            }
                            final e = Map<String, dynamic>.from(raw);
                            final qt = e['questionType'] as String? ?? '';
                            final id = e['id'] as String? ?? '';
                            final q = e['questionPreview'] as String? ?? '';
                            final book = e['sourceBook'] as String? ?? '';
                            final fn = e['sourceFileName'] as String? ?? '';
                            final pack = e['packId'] as String? ?? '';
                            final typeKo =
                                qt == 'national_exam'
                                    ? '국시'
                                    : (qt == 'clinical' ? '임상' : qt);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$typeKo · $id',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    q,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.35,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (book.isNotEmpty ||
                                      fn.isNotEmpty ||
                                      pack.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        [
                                          if (book.isNotEmpty) book,
                                          if (fn.isNotEmpty) fn,
                                          if (pack.isNotEmpty) 'pack: $pack',
                                        ].join(' · '),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textDisabled,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        backgroundColor: AppColors.surfaceMuted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: const Text('닫기'),
                    ),
                  ),
                ],
              ),
            ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('시뮬 오류: $e')));
    } finally {
      if (mounted) setState(() => _previewingNextQuiz = false);
    }
  }

  Future<void> _advanceDailyWordTurn() async {
    final ops = _dailyWordOps;
    final currentWords = ops?.currentWords ?? const <DailyWord>[];
    if (currentWords.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('넘길 오늘 단어가 없습니다.')));
      return;
    }

    final wordList = currentWords.map((word) => word.english).join(', ');
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AppConfirmModal(
            title: '오늘 단어 다음턴으로 넘기기',
            message:
                '현재 운영 기준 오늘 단어 ${currentWords.length}개를 전역 제외 처리합니다.\n\n'
                '$wordList\n\n'
                '이 단어들은 앞으로 오늘 단어 후보에서 빠지고, 기존 사용자별 오늘 배정 문서에 포함되어 있으면 다음 로드 때 새 단어로 재생성됩니다.\n'
                '원본 단어풀과 사용자별 아는 단어/저장 기록은 삭제하지 않습니다.',
            confirmLabel: '다음턴으로 넘기기',
          ),
    );
    if (ok != true || !mounted) return;

    setState(() => _advancingDailyWordTurn = true);
    try {
      final nextOps = await DailyWordService.skipCurrentTurn();
      if (!mounted) return;
      setState(() => _dailyWordOps = nextOps);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('오늘 단어를 다음턴으로 넘겼습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('오늘 단어 넘기기 실패: $e')));
    } finally {
      if (mounted) setState(() => _advancingDailyWordTurn = false);
    }
  }

  Future<void> _mutateTodayScheduleSlot(String action, String slotType) async {
    final today = QuizPoolService.todayKey;
    final typeKo = slotType == QuizPoolItem.kNationalExam ? '국시' : '임상';

    if (action == 'remove') {
      final ok = await showDialog<bool>(
        context: context,
        builder:
            (_) => AppConfirmModal(
              title: '$typeKo 문항 삭제',
              message:
                  '현재 $typeKo 문항을 quiz_pool에서 영구 삭제하고,\n'
                  '같은 타입의 다음 문항으로 자동 교체합니다.\n\n'
                  '사용자 풀이 기록·quiz_meta·전역 통계는 변경되지 않습니다.',
              confirmLabel: '제거',
              destructive: true,
            ),
      );
      if (ok != true || !mounted) return;
    }

    final isNational = slotType == QuizPoolItem.kNationalExam;
    setState(() {
      if (isNational) {
        _mutatingNationalSlot = true;
      } else {
        _mutatingClinicalSlot = true;
      }
    });
    try {
      final data = await AdminDashboardService.adminMutateQuizScheduleSlot(
        dateKey: today,
        action: action,
        slotType: slotType,
      );
      if (!mounted) return;
      final success = data?['success'] == true;
      final msg =
          data?['message'] as String? ?? (success ? '반영되었습니다.' : '요청에 실패했습니다.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (success) await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('오류: $e')));
    } finally {
      if (mounted) {
        setState(() {
          if (isNational) {
            _mutatingNationalSlot = false;
          } else {
            _mutatingClinicalSlot = false;
          }
        });
      }
    }
  }

  Future<void> _advancePollQueue() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => const AppConfirmModal(
            title: '다음 공감투표로 넘기기',
            message:
                '현재 진행 중인 투표를 종료(순위 확정)하고, '
                'displayOrder 기준 다음 미종료 투표를 지금 시작합니다.',
            confirmLabel: '진행',
          ),
    );
    if (ok != true || !mounted) return;

    setState(() => _advancingPollQueue = true);
    try {
      final data = await AdminDashboardService.adminAdvancePollQueue();
      if (!mounted) return;
      final success = data?['success'] == true;
      final msg =
          data?['message'] as String? ?? (success ? '처리했습니다.' : '실패했습니다.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (success) await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('오류: $e')));
    } finally {
      if (mounted) setState(() => _advancingPollQueue = false);
    }
  }

  Future<void> _deleteCurrentPoll() async {
    final current = _pollOps?['current'];
    if (current is! Map) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('삭제할 현재 투표 정보가 없습니다.')));
      return;
    }
    final pollId = current['id'] as String? ?? '';
    if (pollId.isEmpty) return;

    final step1 = await showDialog<bool>(
      context: context,
      builder:
          (_) => AppConfirmModal(
            title: '현재 투표 완전 삭제',
            message:
                '투표 $pollId 및 보기·공감·댓글 등 하위 데이터가 영구 삭제됩니다.\n'
                '삭제 후 다음 대기 투표가 자동으로 활성화됩니다.\n\n'
                '계속할까요?',
            confirmLabel: '다음',
            destructive: true,
          ),
    );
    if (step1 != true || !mounted) return;

    final ctrl = TextEditingController();
    final step2 = await showDialog<bool>(
      context: context,
      builder:
          (dialogCtx) => AppModalDialog(
            insetPadding: const EdgeInsets.all(AppSpacing.xl),
            borderOpacity: 0.7,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '문서 ID 확인',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '삭제할 문서 ID를 정확히 입력하세요.\n대상: $pollId',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                    labelText: '문서 ID',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  autocorrect: false,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          backgroundColor: AppColors.surfaceMuted,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.onCardEmphasis,
                          backgroundColor: AppColors.cardEmphasis,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('삭제 실행'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
    final typed = ctrl.text.trim();
    ctrl.dispose();
    if (step2 != true || !mounted) return;

    setState(() => _deletingCurrentPoll = true);
    try {
      final r = await AdminDashboardService.adminDeletePoll(
        pollId: pollId,
        confirmPollId: typed,
      );
      if (!mounted) return;
      final success = r?['success'] == true;
      final msg =
          r?['message'] as String? ?? (success ? '삭제했습니다.' : '삭제에 실패했습니다.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (success) await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('오류: $e')));
    } finally {
      if (mounted) setState(() => _deletingCurrentPoll = false);
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.month}/${dt.day} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const AdminLoadingState();

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_lastSync != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '마지막 동기화: ${_formatTime(_lastSync!)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textDisabled,
                ),
              ),
            ),

          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '일부 카드만 불러왔어요:\n$_error',
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const AdminSectionTitle('공감투표 운영'),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '앱 노출과 동일하게「현재」= 진행 시간 창 + displayOrder 최소. '
              '「다음」= 미종료 투표 중 순서상 다음 1건.',
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: AppColors.textDisabled.withValues(alpha: 0.95),
              ),
            ),
          ),
          _EmpathyPollOpsSection(
            pollOps: _pollOps,
            advancing: _advancingPollQueue,
            deleting: _deletingCurrentPoll,
            globalLocked: _syncingQuizMeta || _reschedulingTodayQuiz,
            onAdvance: _advancePollQueue,
            onDeleteCurrent: _deleteCurrentPoll,
          ),

          const SizedBox(height: 20),

          const AdminSectionTitle('퀴즈 풀 현황'),
          _QuizPoolCard(
            meta: _quizMeta,
            syncing: _syncingQuizMeta,
            onSyncFromSchedules: _syncQuizMetaFromSchedules,
            reschedulingToday: _reschedulingTodayQuiz,
            onRescheduleToday: _rescheduleTodayQuiz,
            previewingNext: _previewingNextQuiz,
            onPreviewNext: _runPreviewNextQuiz,
          ),

          const SizedBox(height: 20),

          const AdminSectionTitle('오늘 단어 풀 현황'),
          _DailyWordPoolCard(
            ops: _dailyWordOps,
            advancing: _advancingDailyWordTurn,
            onAdvanceTurn: _advanceDailyWordTurn,
          ),

          const SizedBox(height: 20),

          const AdminSectionTitle('오늘 문제 (quiz_schedule)'),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '날짜: ${QuizPoolService.todayKey} · 버튼은 해당 날짜 스케줄의 국시/임상 각 첫 슬롯만 변경합니다.',
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: AppColors.textDisabled.withValues(alpha: 0.95),
              ),
            ),
          ),
          _TodayQuizScheduleSection(
            schedule: _todaySchedule,
            mutatingNational: _mutatingNationalSlot,
            mutatingClinical: _mutatingClinicalSlot,
            operationsLocked: _syncingQuizMeta || _reschedulingTodayQuiz,
            onSlotAction: _mutateTodayScheduleSlot,
            nextNationalPreview: _coerceMap(_quizSlotNextPreviews?['national']),
            nextClinicalPreview: _coerceMap(_quizSlotNextPreviews?['clinical']),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _EmpathyPollOpsSection extends StatelessWidget {
  final Map<String, dynamic>? pollOps;
  final bool advancing;
  final bool deleting;
  final bool globalLocked;
  final VoidCallback onAdvance;
  final VoidCallback onDeleteCurrent;

  const _EmpathyPollOpsSection({
    required this.pollOps,
    required this.advancing,
    required this.deleting,
    required this.globalLocked,
    required this.onAdvance,
    required this.onDeleteCurrent,
  });

  static String _shortIso(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    if (iso.length >= 16) return iso.substring(0, 16).replaceFirst('T', ' ');
    return iso;
  }

  static Widget _pollMiniCard({
    required String label,
    required Map<String, dynamic>? row,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child:
          row == null
              ? Text(
                '$label 없음',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    row['id'] as String? ?? '',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textDisabled,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (row['question'] as String? ?? '').trim().isEmpty
                        ? '(질문 없음)'
                        : (row['question'] as String),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '#${row['displayOrder']} · ${row['status']} · '
                    '시작 ${_shortIso(row['startsAt'] as String?)} · '
                    '종료 ${_shortIso(row['endsAt'] as String?)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ],
              ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (pollOps == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          '운영 허브 데이터를 불러오지 못했습니다. 당겨서 새로고침하세요.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      );
    }

    final total = (pollOps!['totalPolls'] as num?)?.toInt() ?? 0;
    final closed = (pollOps!['closedPolls'] as num?)?.toInt() ?? 0;
    final remaining = (pollOps!['remainingNotClosed'] as num?)?.toInt() ?? 0;
    final current =
        pollOps!['current'] is Map
            ? Map<String, dynamic>.from(pollOps!['current'] as Map)
            : null;
    final next =
        pollOps!['next'] is Map
            ? Map<String, dynamic>.from(pollOps!['next'] as Map)
            : null;

    final busy = advancing || deleting;
    final canOps = current != null && !busy && !globalLocked;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '풀 요약 · 전체 $total건 · 종료 $closed건 · 미종료(남은) $remaining건',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _pollMiniCard(label: '현재 (앱 노출)', row: current),
          const SizedBox(height: 10),
          _pollMiniCard(label: '다음 (순서 기준)', row: next),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: canOps ? onAdvance : null,
                icon:
                    advancing
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.skip_next_outlined, size: 18),
                label: Text(advancing ? '처리 중…' : '다음'),
              ),
              OutlinedButton.icon(
                onPressed: canOps ? onDeleteCurrent : null,
                icon:
                    deleting
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.delete_outline, size: 18),
                label: Text(deleting ? '삭제 중…' : '삭제'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                ),
              ),
            ],
          ),
          if (!canOps && current != null && !busy)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                globalLocked
                    ? '퀴즈 메타 동기화 또는 전체 스케줄 재생성 중에는 공감투표 버튼을 쓸 수 없습니다.'
                    : '다른 작업이 끝난 뒤 다시 시도하세요.',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textDisabled.withValues(alpha: 0.9),
                ),
              ),
            ),
          if (current == null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '진행 중인 투표가 없으면「다음」은 비활성입니다. '
                '「삭제」도 현재 칸이 비어 있으면 사용할 수 없습니다.',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.35,
                  color: AppColors.textDisabled,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuizPoolCard extends StatelessWidget {
  final QuizMetaState? meta;
  final bool syncing;
  final VoidCallback onSyncFromSchedules;
  final bool reschedulingToday;
  final VoidCallback onRescheduleToday;
  final bool previewingNext;
  final VoidCallback onPreviewNext;

  const _QuizPoolCard({
    required this.meta,
    required this.syncing,
    required this.onSyncFromSchedules,
    required this.reschedulingToday,
    required this.onRescheduleToday,
    required this.previewingNext,
    required this.onPreviewNext,
  });

  @override
  Widget build(BuildContext context) {
    if (meta == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          '퀴즈 풀 데이터 없음',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      );
    }

    final total = meta!.totalActiveCount;
    final served = meta!.usedCount;
    final remaining = (total - served).clamp(0, total);
    final cycle = meta!.cycleCount;
    final daily = meta!.dailyCount;
    final daysLeft = daily > 0 ? (remaining / daily).ceil() : 0;

    final natTotal = meta!.totalNationalActiveCount;
    final clinTotal = meta!.totalClinicalActiveCount;
    final natUsed = meta!.usedNationalCount;
    final clinUsed = meta!.usedClinicalCount;
    final natRem = (natTotal - natUsed).clamp(0, natTotal);
    final clinRem = (clinTotal - clinUsed).clamp(0, clinTotal);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$cycle사이클 · quiz_meta 집계 (읽기 전용)',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '합산 $served / $total',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '남은 문항 약 $remaining문제 (하루 $daily문제 기준 약 $daysLeft일치)',
            style: const TextStyle(fontSize: 11, color: AppColors.textDisabled),
          ),
          const SizedBox(height: 14),
          _QuizDepletionGauge(
            label: '국시 풀',
            used: natUsed,
            total: natTotal,
            remaining: natRem,
            barColor: AppColors.cardEmphasis,
          ),
          const SizedBox(height: 12),
          _QuizDepletionGauge(
            label: '임상 풀',
            used: clinUsed,
            total: clinTotal,
            remaining: clinRem,
            barColor: AppColors.blue,
          ),
          const SizedBox(height: 12),
          _QuizDepletionGauge(
            label: '합산 (국시+임상)',
            used: served,
            total: total,
            remaining: remaining,
            barColor: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            '마지막 스케줄: ${meta!.lastScheduledDate}  ·  하루 $daily문제 배포',
            style: const TextStyle(fontSize: 11, color: AppColors.textDisabled),
          ),
          const SizedBox(height: 8),
          Text(
            '위 게이지는 이번 사이클 배포 누적(usedQuizIds)과 활성 풀 메타입니다. '
            '오늘 노출 문항을 바꾸려면 아래「오늘 문제」카드의 다음/삭제를 사용하세요.',
            style: TextStyle(
              fontSize: 10,
              height: 1.35,
              color: AppColors.textDisabled.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: syncing ? null : onSyncFromSchedules,
                icon:
                    syncing
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.sync, size: 18),
                label: Text(syncing ? '동기화 중…' : '스케줄 기준으로 메타 동기화'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed:
                    (syncing || reschedulingToday) ? null : onRescheduleToday,
                icon:
                    reschedulingToday
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.event_repeat, size: 18),
                label: Text(
                  reschedulingToday ? '오늘 스케줄 재생성 중…' : '오늘 스케줄 다시 만들기',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed:
                    (syncing || reschedulingToday || previewingNext)
                        ? null
                        : onPreviewNext,
                icon:
                    previewingNext
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.visibility_outlined, size: 18),
                label: Text(previewingNext ? '시뮬 실행 중…' : '예상 다음 문제 (시뮬)'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyWordPoolCard extends StatelessWidget {
  final DailyWordOpsSummary? ops;
  final bool advancing;
  final VoidCallback onAdvanceTurn;

  const _DailyWordPoolCard({
    required this.ops,
    required this.advancing,
    required this.onAdvanceTurn,
  });

  @override
  Widget build(BuildContext context) {
    if (ops == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          '오늘 단어 풀 데이터 없음',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      );
    }

    final total = ops!.totalActiveCount;
    final used = ops!.skippedCount;
    final remaining = ops!.remainingCount;
    final daysLeft =
        DailyWordService.dailyCount > 0
            ? (remaining / DailyWordService.dailyCount).ceil()
            : 0;
    final currentWords = ops!.currentWords;
    final canAdvance = currentWords.isNotEmpty && !advancing;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '단어 소모 집계',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              Text(
                '$used / $total',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '남은 단어 약 $remaining개 (하루 ${DailyWordService.dailyCount}개 기준 약 $daysLeft일치)',
            style: const TextStyle(fontSize: 11, color: AppColors.textDisabled),
          ),
          const SizedBox(height: 14),
          _QuizDepletionGauge(
            label: '오늘 단어 풀',
            used: used,
            total: total,
            remaining: remaining,
            barColor: AppColors.accent,
            unit: '개',
          ),
          const SizedBox(height: 12),
          Text(
            currentWords.isEmpty
                ? '현재 노출 후보가 없습니다.'
                : '현재 노출 후보: ${currentWords.map((word) => word.english).join(' · ')}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '소모 수에는 전역 제외 단어와 현재 노출 후보가 함께 포함됩니다. '
            '다음턴으로 넘기면 현재 후보가 전역 제외 목록에 추가되어 앞으로 노출 후보에서 빠집니다. '
            '원본 JSON과 사용자별 저장/아는 단어 기록은 유지됩니다.',
            style: TextStyle(
              fontSize: 10,
              height: 1.35,
              color: AppColors.textDisabled.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: canAdvance ? onAdvanceTurn : null,
            icon:
                advancing
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.skip_next_outlined, size: 18),
            label: Text(advancing ? '넘기는 중…' : '현재 단어 다음턴으로 넘기기'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizDepletionGauge extends StatelessWidget {
  final String label;
  final int used;
  final int total;
  final int remaining;
  final Color barColor;
  final String unit;

  const _QuizDepletionGauge({
    required this.label,
    required this.used,
    required this.total,
    required this.remaining,
    required this.barColor,
    this.unit = '문제',
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              total > 0 ? '$used / $total' : '후보 0',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: AppColors.surfaceMuted,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          total > 0 ? '남음 $remaining$unit' : '활성 후보 없음',
          style: const TextStyle(fontSize: 10, color: AppColors.textDisabled),
        ),
      ],
    );
  }
}

class _TodayQuizScheduleSection extends StatelessWidget {
  final QuizSchedule? schedule;
  final bool mutatingNational;
  final bool mutatingClinical;
  final bool operationsLocked;
  final Future<void> Function(String action, String slotType) onSlotAction;
  final Map<String, dynamic>? nextNationalPreview;
  final Map<String, dynamic>? nextClinicalPreview;

  const _TodayQuizScheduleSection({
    required this.schedule,
    required this.mutatingNational,
    required this.mutatingClinical,
    required this.operationsLocked,
    required this.onSlotAction,
    this.nextNationalPreview,
    this.nextClinicalPreview,
  });

  static QuizPoolItem? _firstOfType(QuizSchedule? s, String type) {
    if (s == null) return null;
    for (final i in s.items) {
      if (i.questionType == type) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (schedule == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          '오늘 날짜의 quiz_schedule 문서가 없습니다.\n'
          '「오늘 스케줄 다시 만들기」로 생성하거나 자정 배치를 기다려 주세요.',
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    final national = _firstOfType(schedule, QuizPoolItem.kNationalExam);
    final clinical = _firstOfType(schedule, QuizPoolItem.kClinical);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScheduleSlotCard(
          title: '국시 (national_exam)',
          item: national,
          busy: mutatingNational,
          globalOpsLocked: operationsLocked,
          siblingBusy: mutatingClinical,
          onReplace: () => onSlotAction('replace', QuizPoolItem.kNationalExam),
          onRemove: () => onSlotAction('remove', QuizPoolItem.kNationalExam),
          slotNextPreview: nextNationalPreview,
        ),
        const SizedBox(height: 10),
        _ScheduleSlotCard(
          title: '임상 (clinical)',
          item: clinical,
          busy: mutatingClinical,
          globalOpsLocked: operationsLocked,
          siblingBusy: mutatingNational,
          onReplace: () => onSlotAction('replace', QuizPoolItem.kClinical),
          onRemove: () => onSlotAction('remove', QuizPoolItem.kClinical),
          slotNextPreview: nextClinicalPreview,
        ),
      ],
    );
  }
}

class _ScheduleSlotCard extends StatelessWidget {
  final String title;
  final QuizPoolItem? item;
  final bool busy;
  final bool globalOpsLocked;
  final bool siblingBusy;
  final VoidCallback onReplace;
  final VoidCallback onRemove;
  final Map<String, dynamic>? slotNextPreview;

  const _ScheduleSlotCard({
    required this.title,
    required this.item,
    required this.busy,
    required this.globalOpsLocked,
    required this.siblingBusy,
    required this.onReplace,
    required this.onRemove,
    this.slotNextPreview,
  });

  @override
  Widget build(BuildContext context) {
    final canTap = item != null && !busy && !globalOpsLocked && !siblingBusy;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 8),
          if (item == null)
            const Text(
              '이 날짜 스케줄에 해당 타입 슬롯이 없습니다.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            )
          else ...[
            Text(
              item!.id,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item!.question.trim().isEmpty
                  ? '(질문 텍스트 없음)'
                  : item!.question.trim(),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.textPrimary,
              ),
            ),
            if (item!.sourceBook.isNotEmpty ||
                item!.sourceFileName.isNotEmpty ||
                item!.packId.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  [
                    if (item!.sourceBook.isNotEmpty) item!.sourceBook,
                    if (item!.sourceFileName.isNotEmpty) item!.sourceFileName,
                    if (item!.packId.isNotEmpty) 'pack: ${item!.packId}',
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
          ],
          if (slotNextPreview != null) ...[
            const SizedBox(height: 10),
            const Text(
              '다음 후보 (「다음」클릭 시 셔플·패크 조건에 따라 달라질 수 있음)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              slotNextPreview!['id'] as String? ?? '',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textDisabled,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              slotNextPreview!['questionPreview'] as String? ?? '',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                height: 1.3,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: canTap ? onReplace : null,
                icon:
                    busy
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.skip_next_outlined, size: 18),
                label: Text(busy ? '처리 중…' : '다음'),
              ),
              OutlinedButton.icon(
                onPressed: canTap ? onRemove : null,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('삭제'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                ),
              ),
            ],
          ),
          if (item != null && !busy && !canTap)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                globalOpsLocked
                    ? '메타 동기화 또는 전체 스케줄 재생성 중에는 슬롯 버튼을 사용할 수 없습니다.'
                    : '다른 슬롯을 처리하는 동안에는 잠시 대기해 주세요.',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textDisabled.withValues(alpha: 0.9),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
