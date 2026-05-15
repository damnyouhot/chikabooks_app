import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' show DocumentSnapshot;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'poll_share_capture.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_confirm_modal.dart';
import '../../core/widgets/app_modal_scaffold.dart';
import '../../core/widgets/app_muted_card.dart';
import '../../core/widgets/app_badge.dart';
import '../../models/poll.dart';
import '../../models/poll_comment.dart';
import '../../models/poll_comment_reply.dart';
import '../../models/poll_option.dart';
import '../../services/admin_activity_service.dart';
import '../../services/empathy_poll_service.dart';
import '../../services/caring_treat_service.dart';
import '../../services/funnel_onboarding_service.dart';
import '../caring/floating_treat_burst.dart';
import '../../features/senior_qna/data/senior_stickers.dart';
import '../../features/senior_qna/widgets/senior_sticker_widgets.dart';

/// 공감투표 섹션 — 오늘의 투표 + 지난 투표 피드
class BondPollSection extends StatefulWidget {
  const BondPollSection({super.key});

  @override
  State<BondPollSection> createState() => BondPollSectionState();
}

class BondPollSectionState extends State<BondPollSection> {
  // ── 오늘의 투표 ──
  Poll? _activePoll;
  bool _loading = true;
  String? _myVoteOptionId;
  StreamSubscription<List<PollOption>>? _optionsSub;
  StreamSubscription<String?>? _voteSub;
  List<PollOption> _options = [];
  bool _empathizing = false;

  // ── 인라인 보기 추가 ──
  final _addOptionController = TextEditingController();
  bool _addingOption = false;
  bool _hideAuthorNicknameWhenAdding = false;
  String? _addOptionStickerId;

  // ── 지난 투표 (lazy + pagination) ──
  final List<Poll> _closedPolls = [];
  bool _closedLoading = false;
  bool _hasMoreClosed = true;
  DocumentSnapshot? _lastClosedDoc;
  final Map<String, List<PollOption>> _closedTopOptions = {};
  final Set<String> _expandedPollIds = {};
  final Map<String, List<PollOption>> _expandedAllOptions = {};
  static const _closedPageSize = 5;

  /// 종료 투표 댓글 입력 (폴마다 컨트롤러)
  final Map<String, TextEditingController> _closedCommentControllers = {};
  final Map<String, bool> _submittingClosedComment = {};
  /// pollId → 현재 답글 대상 commentId (null이면 일반 댓글 모드)
  final Map<String, String?> _replyingToCommentId = {};
  /// pollId → 현재 입력 중인 스티커 목록
  final Map<String, List<String>> _commentStickerIds = {};

  @override
  void initState() {
    super.initState();
    _loadActivePoll();
  }

  void reload() {
    _loadActivePoll();
    // 지난 투표는 스크롤 시 lazy load
  }

  @override
  void dispose() {
    _optionsSub?.cancel();
    _voteSub?.cancel();
    _addOptionController.dispose();
    for (final c in _closedCommentControllers.values) {
      c.dispose();
    }
    _closedCommentControllers.clear();
    super.dispose();
  }

  TextEditingController _commentControllerFor(String pollId) {
    return _closedCommentControllers.putIfAbsent(
      pollId,
      TextEditingController.new,
    );
  }

  Future<void> _shareActivePollAsImage() async {
    final poll = _activePoll;
    if (poll == null || !mounted) return;
    final totalEmpathy = _options.fold<int>(0, (s, o) => s + o.empathyCount);
    try {
      await PollShareCapture.share(
        context,
        poll: poll,
        options: List<PollOption>.from(_options),
        badgeLabel: '오늘',
        isPastStyle: false,
        totalEmpathy: totalEmpathy,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('공유에 실패했어요. $e')));
      }
    }
  }

  Future<void> _shareClosedPollAsImage(Poll poll) async {
    if (!mounted) return;
    try {
      final options = await EmpathyPollService.getOptionsOrderedForPoll(
        poll.id,
      );
      if (!mounted) return;
      await PollShareCapture.share(
        context,
        poll: poll,
        options: options,
        badgeLabel: _formatPollDateBadge(poll),
        isPastStyle: true,
        totalEmpathy: poll.totalEmpathyCount,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('공유에 실패했어요. $e')));
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 데이터 로딩
  // ═══════════════════════════════════════════════════════════

  Future<void> _loadActivePoll() async {
    final poll = await EmpathyPollService.getActivePoll();
    if (!mounted) return;
    setState(() {
      _activePoll = poll;
      _loading = false;
    });
    if (poll != null) {
      _subscribeToOptions(poll.id);
      _subscribeToMyVote(poll.id);
    }
    // 활성 투표 로드 후 지난 투표 첫 페이지 로드
    if (_closedPolls.isEmpty) _loadMoreClosedPolls();
  }

  void _subscribeToOptions(String pollId) {
    _optionsSub?.cancel();
    _optionsSub = EmpathyPollService.optionsStream(pollId).listen((options) {
      if (mounted) setState(() => _options = options);
    });
  }

  void _subscribeToMyVote(String pollId) {
    _voteSub?.cancel();
    _voteSub = EmpathyPollService.myVoteStream(pollId).listen((optionId) {
      if (mounted) setState(() => _myVoteOptionId = optionId);
    });
  }

  Future<void> _loadMoreClosedPolls() async {
    if (_closedLoading || !_hasMoreClosed) return;
    final isInitialPage = _closedPolls.isEmpty;
    setState(() => _closedLoading = true);

    final page = await EmpathyPollService.getClosedPolls(
      limit: _closedPageSize,
      startAfter: _lastClosedDoc,
    );
    if (!mounted) return;

    if (page.polls.isEmpty) {
      setState(() {
        _hasMoreClosed = false;
        _closedLoading = false;
      });
      return;
    }

    // 첫 페이지는 최근 5개를 기본 펼침으로 보여주고, 이후 페이지는 기존처럼 top 3만 표시한다.
    final results = await Future.wait(
      page.polls.map((p) async {
        final options =
            isInitialPage
                ? await EmpathyPollService.getOptionsOrderedForPoll(p.id)
                : await EmpathyPollService.getTopOptions(p.id, top: 3);
        return MapEntry(p.id, options);
      }),
    );
    if (!mounted) return;

    for (final entry in results) {
      if (isInitialPage) {
        _expandedAllOptions[entry.key] = entry.value;
        _closedTopOptions[entry.key] = entry.value.take(3).toList();
        _expandedPollIds.add(entry.key);
      } else {
        _closedTopOptions[entry.key] = entry.value;
      }
    }

    setState(() {
      _closedPolls.addAll(page.polls);
      _lastClosedDoc = page.lastDoc;
      _hasMoreClosed = page.polls.length >= _closedPageSize;
      _closedLoading = false;
    });
  }

  Future<void> _expandPoll(String pollId) async {
    if (_expandedAllOptions.containsKey(pollId)) {
      setState(() => _expandedPollIds.add(pollId));
      return;
    }

    final allOptions = await EmpathyPollService.getOptions(pollId);
    if (!mounted) return;
    setState(() {
      _expandedAllOptions[pollId] = allOptions;
      _expandedPollIds.add(pollId);
    });
  }

  // ═══════════════════════════════════════════════════════════
  // 액션
  // ═══════════════════════════════════════════════════════════

  Future<void> _onEmpathize(String optionId) async {
    if (_activePoll == null || _empathizing) return;
    setState(() => _empathizing = true);

    final result = await EmpathyPollService.empathize(
      _activePoll!.id,
      optionId,
    );
    if (!mounted) return;
    setState(() => _empathizing = false);

    if (result.success) {
      AdminActivityService.log(
        result.isChange
            ? ActivityEventType.pollChangeEmpathy
            : ActivityEventType.pollEmpathize,
        page: 'bond',
        targetId: optionId,
      );
      // 첫 공감 선택일 때만 온보딩 퍼널 ③ (이미 투표한 유저 재선택은 isChange)
      if (!result.isChange) {
        unawaited(FunnelOnboardingService.tryLogFirstPoll());
        unawaited(() async {
          final ok = await CaringTreatService.tryGrantEmpathyFirstVote(
            _activePoll!.id,
          );
          if (!mounted || !ok) return;
          FloatingTreatBurst.show(context, iconCount: 1);
        }());
      }
    } else if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error ?? '오류가 발생했습니다.')));
    }
  }

  Future<void> _submitAddOption() async {
    if (_activePoll == null || _addingOption) return;
    final text = _addOptionController.text.trim();
    if (text.isEmpty) return;

    final hideNickname = _hideAuthorNicknameWhenAdding;
    final stickerId = _addOptionStickerId;
    setState(() => _addingOption = true);
    final result = await EmpathyPollService.addOption(
      _activePoll!.id,
      text,
      hideAuthorNickname: hideNickname,
      stickerId: stickerId,
    );
    if (!mounted) return;
    setState(() {
      _addingOption = false;
      if (result.success) {
        _hideAuthorNicknameWhenAdding = false;
        _addOptionStickerId = null;
      }
    });

    if (result.success) {
      _addOptionController.clear();
      FocusScope.of(context).unfocus();
      AdminActivityService.log(
        ActivityEventType.pollAddOption,
        page: 'bond',
        targetId: result.optionId,
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error ?? '오류가 발생했습니다.')));
    }
  }

  Future<void> _pickAddOptionSticker() async {
    final picked = await showSeniorStickerPicker(
      context,
      selectedId: _addOptionStickerId,
    );
    if (!mounted || picked == null) return;
    setState(() => _addOptionStickerId = picked);
  }

  void _onPollOptionDeletePressed(
    PollOption option, {
    required bool isAuthor,
    required bool canDeleteAsAuthor,
  }) {
    if (!canDeleteAsAuthor) {
      final msg =
          !isAuthor ? '본인이 추가한 보기만 삭제할 수 있어요.' : '공감 인원이 많아 삭제할 수 없어요. (6명 이상)';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    _showDeleteOptionDialog(option);
  }

  Future<void> _showDeleteOptionDialog(PollOption option) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AppConfirmModal(
            title: '보기 삭제',
            message: '"${option.content}" 보기를 삭제할까요?',
            confirmLabel: '삭제',
            destructive: true,
          ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _options = _options.where((o) => o.id != option.id).toList();
    });
    final result = await EmpathyPollService.deleteMyOption(
      _activePoll!.id,
      option.id,
    );
    if (!mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error ?? '삭제에 실패했습니다.')));
    }
  }

  void _showReportDialog(PollOption option) {
    var selected = EmpathyPollService.pollReportReasonLabels.keys.first;
    showDialog<void>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setSt) {
              return AppModalDialog(
                insetPadding: const EdgeInsets.all(AppSpacing.xl),
                borderOpacity: 0.7,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '보기 신고',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(ctx).height * 0.5,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '신고 사유를 선택해주세요.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                height: 1.45,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              '"${option.content}"',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                height: 1.45,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            ...EmpathyPollService.pollReportReasonLabels.entries
                                .map(
                                  (e) => RadioListTile<String>(
                                    title: Text(
                                      e.value,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    value: e.key,
                                    // TODO: Flutter RadioGroup migration after minimum SDK policy is set.
                                    // ignore: deprecated_member_use
                                    groupValue: selected,
                                    // ignore: deprecated_member_use
                                    onChanged: (v) {
                                      if (v != null) setSt(() => selected = v);
                                    },
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              backgroundColor: AppColors.surfaceMuted,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
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
                            onPressed: () async {
                              final reason = selected;
                              Navigator.pop(ctx);
                              final result =
                                  await EmpathyPollService.reportOption(
                                    _activePoll!.id,
                                    option.id,
                                    reasonKey: reason,
                                  );
                              if (!mounted) return;
                              final msg =
                                  !result.success
                                      ? (result.error ?? '오류')
                                      : result.reachedRemovalThreshold
                                      ? '누적 신고로 해당 보기가 삭제되었습니다.'
                                      : '신고가 접수되었습니다.';
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(msg)));
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.onCardEmphasis,
                              backgroundColor: AppColors.cardEmphasis,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            child: const Text('신고'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActivePollSection(),
          const SizedBox(height: 28),
          _buildClosedPollFeed(),
        ],
      ),
    );
  }

  // ── 오늘의 투표 ────────────────────────────────────────────

  Widget _buildActivePollSection() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_activePoll == null) {
      return AppMutedCard(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Icon(
              Icons.how_to_vote_outlined,
              size: 36,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: 12),
            const Text(
              '오늘의 투표가 아직 등록되지 않았어요.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            const Text(
              '곧 새로운 주제가 올라올 거예요!',
              style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    }

    final poll = _activePoll!;
    final hasVoted = _myVoteOptionId != null;
    final totalEmpathy = _options.fold<int>(
      0,
      (sum, o) => sum + o.empathyCount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.how_to_vote_outlined,
              size: 16,
              color: AppColors.textDisabled,
            ),
            const SizedBox(width: 6),
            const Text(
              '오늘의 공감투표',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppMutedCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 지난 투표 카드와 동일: 첫 줄 — 뱃지 · 남은 시간 · 공유
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AppBadge(
                      label: '오늘',
                      bgColor: AppColors.pollBadgeBg,
                      textColor: AppColors.pollBadgeText,
                    ),
                    const Spacer(),
                    _PollCountdownTicker(
                      key: ValueKey<String>(poll.id),
                      endsAt: poll.endsAt,
                      onExpired: () {
                        if (mounted) _loadActivePoll();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_outlined, size: 20),
                      color: AppColors.textSecondary,
                      tooltip: '공유',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      onPressed: _shareActivePollAsImage,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  10,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: Text(
                  poll.question,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
              // 보기 목록
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: Column(
                  children:
                      _options
                          .map(
                            (o) => _buildOptionTile(
                              option: o,
                              isSelected: _myVoteOptionId == o.id,
                              hasVoted: hasVoted,
                              totalEmpathy: totalEmpathy,
                            ),
                          )
                          .toList(),
                ),
              ),
              // 인라인 보기 추가
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: _buildInlineAddOption(),
              ),
              // 참여 현황
              if (totalEmpathy > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Center(
                    child: Text(
                      '$totalEmpathy명 참여',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 인라인 보기 추가 입력 필드
  Widget _buildInlineAddOption() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.textDisabled.withValues(alpha: 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _addOptionController,
              onTapOutside:
                  (_) => FocusManager.instance.primaryFocus?.unfocus(),
              maxLength: EmpathyPollService.maxOptionLength,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '나만의 보기를 적어주세요',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppColors.textDisabled,
                ),
                counterText: '',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: 12,
                ),
                isDense: true,
              ),
              onSubmitted: (_) => _submitAddOption(),
            ),
          ),
          if (_addOptionStickerId != null)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: SeniorStickerChip(
                stickerId: _addOptionStickerId!,
                onRemove:
                    _addingOption
                        ? null
                        : () => setState(() => _addOptionStickerId = null),
              ),
            ),
          IconButton(
            icon: Icon(
              Icons.add_reaction_outlined,
              size: 20,
              color:
                  _addingOption
                      ? AppColors.textDisabled
                      : AppColors.textSecondary,
            ),
            tooltip: '이모지',
            onPressed: _addingOption ? null : _pickAddOptionSticker,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _hideAuthorNicknameWhenAdding,
                  onChanged:
                      _addingOption
                          ? null
                          : (v) {
                            setState(
                              () => _hideAuthorNicknameWhenAdding = v ?? false,
                            );
                          },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  activeColor: AppColors.accent,
                  side: BorderSide(
                    color: AppColors.textDisabled.withValues(alpha: 0.5),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap:
                      _addingOption
                          ? null
                          : () {
                            setState(
                              () =>
                                  _hideAuthorNicknameWhenAdding =
                                      !_hideAuthorNicknameWhenAdding,
                            );
                          },
                  child: Text(
                    '닉네임 비공개',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color:
                          _addingOption
                              ? AppColors.textDisabled
                              : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _addingOption
              ? const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
              : IconButton(
                icon: Icon(
                  Icons.edit_note_rounded,
                  size: 22,
                  color: AppColors.accent,
                ),
                onPressed: _submitAddOption,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required PollOption option,
    required bool isSelected,
    required bool hasVoted,
    required int totalEmpathy,
  }) {
    final percentage =
        totalEmpathy > 0 ? (option.empathyCount / totalEmpathy * 100) : 0.0;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isAuthor = !option.isSystem && uid != null && option.authorUid == uid;
    final canDeleteAsAuthor = isAuthor && option.empathyCount <= 5;

    final actionIconColor =
        isSelected
            ? AppColors.pollOptionSelectedText.withValues(alpha: 0.95)
            : AppColors.pollOptionText.withValues(alpha: 0.82);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.pollOptionSelectedBg
                  : AppColors.pollOptionBg.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 라디오 + 본문 (공감 탭 영역) ──────────────────
            Expanded(
              child: GestureDetector(
                onTap: () => _onEmpathize(option.id),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: _buildRadioCircle(isSelected),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            option.content,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color:
                                  isSelected
                                      ? AppColors.pollOptionSelectedText
                                      : AppColors.pollOptionText,
                            ),
                          ),
                          if (!option.isSystem)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                option.displayAuthorLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  color:
                                      isSelected
                                          ? AppColors.pollOptionSelectedText
                                              .withValues(alpha: 0.6)
                                          : AppColors.textDisabled,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── 삭제(작성자만)·신고 버튼 ───────────────────────
            if (!option.isSystem)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (option.stickerId != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: SeniorStickerView(
                          stickerId: option.stickerId!,
                          size: 21,
                        ),
                      ),
                    // 삭제 — 작성자만 노출
                    if (isAuthor)
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color:
                              canDeleteAsAuthor
                                  ? actionIconColor
                                  : actionIconColor.withValues(alpha: 0.38),
                        ),
                        tooltip: '삭제',
                        onPressed:
                            () => _onPollOptionDeletePressed(
                              option,
                              isAuthor: isAuthor,
                              canDeleteAsAuthor: canDeleteAsAuthor,
                            ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 28,
                        ),
                      ),
                    // 신고 — 모든 유저 표시
                    IconButton(
                      icon: Icon(
                        Icons.flag_outlined,
                        size: 18,
                        color: actionIconColor,
                      ),
                      tooltip: '신고',
                      onPressed: () => _showReportDialog(option),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 28,
                      ),
                    ),
                  ],
                ),
              ),
            // ── 퍼센트 + 명수 (투표 후 표시, 맨 우측) ──────────
            if (hasVoted)
              GestureDetector(
                onTap: () => _onEmpathize(option.id),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              isSelected
                                  ? AppColors.pollOptionSelectedText.withValues(
                                    alpha: 0.8,
                                  )
                                  : AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${option.empathyCount}명',
                        style: TextStyle(
                          fontSize: 10,
                          color:
                              isSelected
                                  ? AppColors.pollOptionSelectedText.withValues(
                                    alpha: 0.5,
                                  )
                                  : AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioCircle(bool isSelected) {
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

  // ── 지난 투표 피드 ────────────────────────────────────────

  Widget _buildClosedPollFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.history, size: 16, color: AppColors.textDisabled),
            SizedBox(width: 6),
            Text(
              '지난 투표 결과',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_closedPolls.isEmpty && _closedLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_closedPolls.isEmpty && !_closedLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                '아직 종료된 투표가 없어요.',
                style: TextStyle(fontSize: 13, color: AppColors.textDisabled),
              ),
            ),
          )
        else ...[
          ..._closedPolls.map((poll) => _buildClosedPollCard(poll)),
          // 더보기 / 로딩
          if (_closedLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_hasMoreClosed)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                child: TextButton.icon(
                  onPressed: _loadMoreClosedPolls,
                  icon: const Icon(Icons.expand_more, size: 18),
                  label: const Text(
                    '이전 투표 더보기',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildClosedPollCard(Poll poll) {
    final isExpanded = _expandedPollIds.contains(poll.id);
    final topOptions = _closedTopOptions[poll.id] ?? [];
    final allOptions = _expandedAllOptions[poll.id] ?? [];
    final displayOptions = isExpanded ? allOptions : topOptions;
    final dateStr = _formatPollDateBadge(poll);
    final totalEmpathy = poll.totalEmpathyCount;
    // 옵션 개수에 관계없이 댓글 섹션 항상 표시
    final showCommentSection = true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppMutedCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppBadge(
                  label: dateStr,
                  bgColor: AppColors.cardPrimary,
                  textColor: AppColors.onCardPrimary,
                ),
                const Spacer(),
                Text(
                  '$totalEmpathy명 참여',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDisabled,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 20),
                  color: AppColors.textSecondary,
                  tooltip: '공유',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onPressed: () => _shareClosedPollAsImage(poll),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              poll.question,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            ...displayOptions.asMap().entries.map((entry) {
              return _buildClosedOptionRow(
                entry.key,
                entry.value,
                totalEmpathy,
              );
            }),
            // 펼치기/접기 버튼
            if (!isExpanded && topOptions.length >= 3)
              Center(
                child: GestureDetector(
                  onTap: () => _expandPoll(poll.id),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '전체 보기',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
              )
            else if (isExpanded)
              Center(
                child: GestureDetector(
                  onTap: () => setState(() => _expandedPollIds.remove(poll.id)),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '접기',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ),
                ),
              ),
            if (showCommentSection) ...[
              const SizedBox(height: 14),
              _buildClosedPollCommentSection(poll),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClosedPollCommentSection(Poll poll) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 14,
              color: AppColors.textDisabled,
            ),
            SizedBox(width: 6),
            Text(
              '한마디',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _StablePollCommentsList(
          key: ValueKey<String>(poll.id),
          pollId: poll.id,
          buildTile: _buildClosedCommentTile,
        ),
        _buildClosedCommentInput(poll.id),
      ],
    );
  }

  Widget _buildClosedCommentTile(String pollId, PollComment c) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isAuthor = myUid != null && c.uid == myUid;
    final timeStr =
        '${c.createdAt.month}/${c.createdAt.day} ${c.createdAt.hour.toString().padLeft(2, '0')}:${c.createdAt.minute.toString().padLeft(2, '0')}';
    final hasStickers = c.stickerIds.isNotEmpty;
    final expectedFallback = hasStickers
        ? seniorStickerFallbackBodyForIds(c.stickerIds)
        : null;
    final visibleText = (expectedFallback != null &&
            c.text.trim() == expectedFallback.trim())
        ? ''
        : c.text;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 댓글 본문 ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 스티커 + 텍스트
                if (hasStickers || visibleText.isNotEmpty)
                  Text.rich(
                    TextSpan(
                      children: [
                        for (final id in c.stickerIds)
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: SeniorStickerView(stickerId: id, size: 28),
                            ),
                          ),
                        if (visibleText.isNotEmpty)
                          TextSpan(
                            text: hasStickers ? ' $visibleText' : visibleText,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                              color: AppColors.textPrimary,
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textDisabled,
                      ),
                    ),
                    const Spacer(),
                    // 좋아요
                    StreamBuilder<bool>(
                      stream: EmpathyPollService.watchPollCommentLikeSelected(
                        pollId,
                        c.id,
                      ),
                      builder: (_, snap) {
                        final liked = snap.data ?? false;
                        return _TinyPollAction(
                          icon: liked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          iconColor: liked
                              ? AppColors.error
                              : AppColors.textSecondary,
                          label: c.likeCount > 0 ? '${c.likeCount}' : '좋아요',
                          onTap: () =>
                              EmpathyPollService.togglePollCommentLike(
                                pollId,
                                c.id,
                              ),
                        );
                      },
                    ),
                    const SizedBox(width: 2),
                    // 답글
                    _TinyPollAction(
                      icon: Icons.reply,
                      label: c.replyCount > 0 ? '답글 ${c.replyCount}' : '답글',
                      onTap: () {
                        setState(() {
                          if (_replyingToCommentId[pollId] == c.id) {
                            _replyingToCommentId[pollId] = null;
                          } else {
                            _replyingToCommentId[pollId] = c.id;
                            _commentControllerFor(pollId).clear();
                            _commentStickerIds[pollId]?.clear();
                          }
                        });
                      },
                    ),
                    // 신고 / 삭제 메뉴
                    if (isAuthor)
                      SizedBox(
                        width: 24,
                        height: 20,
                        child: PopupMenuButton<String>(
                          color: AppColors.appBg,
                          elevation: 4,
                          position: PopupMenuPosition.under,
                          offset: const Offset(0, 4),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          icon: const Icon(
                            Icons.more_horiz,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          onSelected: (v) {
                            if (v == 'delete') {
                              _confirmDeleteComment(pollId, c.id);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                '삭제',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _TinyPollAction(
                        label: '신고',
                        onTap: () => _reportComment(context, pollId, c.id),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // ── 대댓글 목록 ──
          StreamBuilder<List<PollCommentReply>>(
            stream: EmpathyPollService.pollCommentRepliesStream(pollId, c.id),
            builder: (_, snap) {
              final replies = snap.data ?? [];
              if (replies.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xl, top: 4),
                child: Column(
                  children: replies
                      .map((r) => _buildReplyTile(pollId, c.id, r))
                      .toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteComment(
    String pollId,
    String commentId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => const AppConfirmModal(
        title: '댓글 삭제',
        message: '이 댓글을 삭제할까요?',
        confirmLabel: '삭제',
        destructive: true,
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await EmpathyPollService.deletePollComment(pollId, commentId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '댓글을 삭제했어요.' : '삭제에 실패했어요.'),
      ),
    );
  }

  Future<void> _reportComment(
    BuildContext ctx,
    String pollId,
    String commentId,
  ) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => const AppConfirmModal(
        title: '댓글 신고',
        message: '이 댓글을 신고할까요?\n신고가 누적되면 운영팀이 검토합니다.',
        confirmLabel: '신고',
      ),
    );
    if (confirm != true) return;
    final ok = await EmpathyPollService.reportPollComment(pollId, commentId);
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(ok ? '신고가 접수되었어요.' : '이미 신고했거나 처리에 실패했어요.'),
      ),
    );
  }

  Widget _buildReplyTile(
    String pollId,
    String commentId,
    PollCommentReply r,
  ) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isAuthor = myUid != null && r.uid == myUid;
    final timeStr =
        '${r.createdAt.month}/${r.createdAt.day} ${r.createdAt.hour.toString().padLeft(2, '0')}:${r.createdAt.minute.toString().padLeft(2, '0')}';
    final hasStickers = r.stickerIds.isNotEmpty;
    final expectedFallback = hasStickers
        ? seniorStickerFallbackBodyForIds(r.stickerIds)
        : null;
    final visibleText = (expectedFallback != null &&
            r.text.trim() == expectedFallback.trim())
        ? ''
        : r.text;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasStickers || visibleText.isNotEmpty)
              Text.rich(
                TextSpan(
                  children: [
                    for (final id in r.stickerIds)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: SeniorStickerView(stickerId: id, size: 23),
                        ),
                      ),
                    if (visibleText.isNotEmpty)
                      TextSpan(
                        text: hasStickers ? ' $visibleText' : visibleText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: AppColors.textPrimary,
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 3),
            Row(
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textDisabled,
                  ),
                ),
                const Spacer(),
                StreamBuilder<bool>(
                  stream:
                      EmpathyPollService.watchPollCommentReplyLikeSelected(
                    pollId,
                    commentId,
                    r.id,
                  ),
                  builder: (_, snap) {
                    final liked = snap.data ?? false;
                    return _TinyPollAction(
                      icon: liked ? Icons.favorite : Icons.favorite_border,
                      iconColor:
                          liked ? AppColors.error : AppColors.textSecondary,
                      label: r.likeCount > 0 ? '${r.likeCount}' : '좋아요',
                      onTap: () =>
                          EmpathyPollService.togglePollCommentReplyLike(
                        pollId,
                        commentId,
                        r.id,
                      ),
                    );
                  },
                ),
                if (isAuthor)
                  SizedBox(
                    width: 24,
                    height: 20,
                    child: PopupMenuButton<String>(
                      color: AppColors.appBg,
                      elevation: 4,
                      position: PopupMenuPosition.under,
                      offset: const Offset(0, 4),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      icon: const Icon(
                        Icons.more_horiz,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      onSelected: (v) {
                        if (v == 'delete') {
                          _confirmDeleteReply(pollId, commentId, r.id);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            '삭제',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  _TinyPollAction(
                    label: '신고',
                    onTap: () => _reportReply(context, pollId, commentId, r.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteReply(
    String pollId,
    String commentId,
    String replyId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => const AppConfirmModal(
        title: '답글 삭제',
        message: '이 답글을 삭제할까요?',
        confirmLabel: '삭제',
        destructive: true,
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await EmpathyPollService.deletePollCommentReply(
      pollId,
      commentId,
      replyId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '답글을 삭제했어요.' : '삭제에 실패했어요.')),
    );
  }

  Future<void> _reportReply(
    BuildContext ctx,
    String pollId,
    String commentId,
    String replyId,
  ) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => const AppConfirmModal(
        title: '답글 신고',
        message: '이 답글을 신고할까요?\n신고가 누적되면 운영팀이 검토합니다.',
        confirmLabel: '신고',
      ),
    );
    if (confirm != true) return;
    final ok = await EmpathyPollService.reportPollCommentReply(
      pollId,
      commentId,
      replyId,
    );
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(ok ? '신고가 접수되었어요.' : '이미 신고했거나 처리에 실패했어요.'),
      ),
    );
  }

  Widget _buildClosedCommentInput(String pollId) {
    final busy = _submittingClosedComment[pollId] == true;
    final ctrl = _commentControllerFor(pollId);
    final replyingToId = _replyingToCommentId[pollId];
    final isReplyMode = replyingToId != null;
    final stickerIds = _commentStickerIds[pollId] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isReplyMode)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.reply, size: 13, color: AppColors.accent),
                const SizedBox(width: 4),
                const Text(
                  '답글 작성 중',
                  style: TextStyle(fontSize: 12, color: AppColors.accent),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(
                    () => _replyingToCommentId[pollId] = null,
                  ),
                  child: const Text(
                    '취소',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // 선택된 스티커 미리보기
        if (stickerIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SeniorStickerChipList(
              stickerIds: stickerIds,
              onRemoveAt: (i) => setState(() {
                _commentStickerIds.putIfAbsent(pollId, () => []).removeAt(i);
              }),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.textDisabled.withValues(alpha: 0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      onTapOutside:
                          (_) => FocusManager.instance.primaryFocus?.unfocus(),
                      maxLength: EmpathyPollService.maxPollCommentLength,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            isReplyMode ? '답글을 입력하세요' : '종료된 투표에 한마디 남기기',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: AppColors.textDisabled,
                        ),
                        counterText: '',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _submitClosedPollComment(pollId),
                    ),
                  ),
                  busy
                      ? const Padding(
                        padding: EdgeInsets.only(right: 12, bottom: 8),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                      : IconButton(
                        icon: Icon(
                          Icons.edit_note_rounded,
                          size: 22,
                          color: AppColors.accent,
                        ),
                        onPressed: () => _submitClosedPollComment(pollId),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                ],
              ),
              // 스티커 버튼 툴바
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: busy ? null : () => _pickCommentSticker(pollId),
                      icon: Icon(
                        stickerIds.isEmpty
                            ? Icons.emoji_emotions_outlined
                            : Icons.emoji_emotions,
                        size: 18,
                      ),
                      color: stickerIds.isEmpty
                          ? AppColors.textSecondary
                          : AppColors.cardEmphasis,
                      visualDensity: VisualDensity.compact,
                      tooltip: '스티커',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickCommentSticker(String pollId) async {
    final list = _commentStickerIds.putIfAbsent(pollId, () => []);
    if (list.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('스티커는 최대 5개까지 첨부할 수 있어요.')),
      );
      return;
    }
    final id = await showSeniorStickerPicker(
      context,
      selectedId: list.isEmpty ? null : list.last,
    );
    if (!mounted || id == null) return;
    setState(() => list.add(id));
  }

  Future<void> _submitClosedPollComment(String pollId) async {
    if (_submittingClosedComment[pollId] == true) return;
    final ctrl = _commentControllerFor(pollId);
    final text = ctrl.text.trim();
    final stickerIds = List<String>.from(
      _commentStickerIds[pollId] ?? [],
    );
    if (text.isEmpty && stickerIds.isEmpty) return;

    setState(() => _submittingClosedComment[pollId] = true);

    final replyingTo = _replyingToCommentId[pollId];
    final PollCommentResult result;
    if (replyingTo != null) {
      result = await EmpathyPollService.addPollCommentReply(
        pollId,
        replyingTo,
        text,
        stickerIds: stickerIds,
      );
    } else {
      result = await EmpathyPollService.addPollComment(
        pollId,
        text,
        stickerIds: stickerIds,
      );
    }

    if (!mounted) return;
    setState(() {
      _submittingClosedComment[pollId] = false;
      if (result.success) {
        _replyingToCommentId[pollId] = null;
        _commentStickerIds[pollId]?.clear();
      }
    });

    if (result.success) {
      ctrl.clear();
      FocusScope.of(context).unfocus();
    } else if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error ?? '오류가 발생했습니다.')));
    }
  }

  Widget _buildClosedOptionRow(int rank, PollOption option, int totalEmpathy) {
    final rankLabel = '${rank + 1}위';
    final pct =
        totalEmpathy > 0
            ? (option.empathyCount / totalEmpathy * 100).toStringAsFixed(1)
            : '0.0';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              rankLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: rank < 3 ? FontWeight.w700 : FontWeight.w500,
                color:
                    rank == 0 ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.content,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (!option.isSystem)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      option.displayAuthorLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$pct%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '(${option.empathyCount})',
            style: const TextStyle(fontSize: 11, color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }

  /// 지난 투표 카드 뱃지: 실제 마감일(종료일) 기준, 연도 포함
  String _formatPollDateBadge(Poll poll) {
    final t = poll.closedAt ?? poll.endsAt;
    return '${t.year}/${t.month}/${t.day}';
  }
}

/// 1초마다 이 위젯만 rebuild → 지난 투표·댓글 Stream 전체가 매초 다시 구독되지 않음
class _PollCountdownTicker extends StatefulWidget {
  const _PollCountdownTicker({
    super.key,
    required this.endsAt,
    required this.onExpired,
  });

  final DateTime endsAt;
  final VoidCallback onExpired;

  @override
  State<_PollCountdownTicker> createState() => _PollCountdownTickerState();
}

class _PollCountdownTickerState extends State<_PollCountdownTicker> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _firedExpired = false;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final r = widget.endsAt.difference(DateTime.now());
    final next = r.isNegative ? Duration.zero : r;
    setState(() => _remaining = next);
    if (next == Duration.zero && !_firedExpired) {
      _firedExpired = true;
      widget.onExpired();
    }
  }

  @override
  void didUpdateWidget(covariant _PollCountdownTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt) {
      _firedExpired = false;
      _tick();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) {
      return const Text(
        '마감됨',
        style: TextStyle(fontSize: 11, color: AppColors.textDisabled),
      );
    }
    final h = _remaining.inHours;
    final m = _remaining.inMinutes % 60;
    final s = _remaining.inSeconds % 60;
    final text =
        h > 0
            ? '$h시간 $m분 남음'
            : m > 0
            ? '$m분 $s초 남음'
            : '$s초 남음';

    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color:
            _remaining.inMinutes < 60
                ? AppColors.cardEmphasis
                : AppColors.textDisabled,
        fontWeight:
            _remaining.inMinutes < 60 ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}

typedef _CommentTileBuilder = Widget Function(String pollId, PollComment c);

class _StablePollCommentsList extends StatefulWidget {
  const _StablePollCommentsList({
    super.key,
    required this.pollId,
    required this.buildTile,
  });

  final String pollId;
  final _CommentTileBuilder buildTile;

  @override
  State<_StablePollCommentsList> createState() =>
      _StablePollCommentsListState();
}

class _StablePollCommentsListState extends State<_StablePollCommentsList> {
  late final Stream<List<PollComment>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = EmpathyPollService.pollCommentsStream(widget.pollId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PollComment>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '한마디를 불러오지 못했어요.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.error.withValues(alpha: 0.85),
              ),
            ),
          );
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              '첫 한마디를 남겨보세요.',
              style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...list.map((c) => widget.buildTile(widget.pollId, c)),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

/// 댓글/답글 행동 버튼 (좋아요, 답글 등)
class _TinyPollAction extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String label;
  final VoidCallback onTap;

  const _TinyPollAction({
    this.icon,
    this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: const Size(0, 24),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: iconColor ?? AppColors.textSecondary),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
