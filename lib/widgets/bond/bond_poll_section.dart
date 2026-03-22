import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' show DocumentSnapshot;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';
import '../../core/widgets/app_badge.dart';
import '../../models/poll.dart';
import '../../models/poll_comment.dart';
import '../../models/poll_option.dart';
import '../../services/empathy_poll_service.dart';
import '../../services/admin_activity_service.dart';

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
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  // ── 인라인 보기 추가 ──
  final _addOptionController = TextEditingController();
  bool _addingOption = false;

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
    _countdownTimer?.cancel();
    _addOptionController.dispose();
    for (final c in _closedCommentControllers.values) {
      c.dispose();
    }
    _closedCommentControllers.clear();
    super.dispose();
  }

  TextEditingController _commentControllerFor(String pollId) {
    return _closedCommentControllers.putIfAbsent(pollId, TextEditingController.new);
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
      _startCountdown(poll);
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

  void _startCountdown(Poll poll) {
    _remaining = poll.remaining;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final r = poll.endsAt.difference(DateTime.now());
      setState(() => _remaining = r.isNegative ? Duration.zero : r);
      if (_remaining == Duration.zero) {
        _countdownTimer?.cancel();
        _loadActivePoll();
      }
    });
  }

  Future<void> _loadMoreClosedPolls() async {
    if (_closedLoading || !_hasMoreClosed) return;
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

    // top 3 병렬 로드
    final results = await Future.wait(
      page.polls.map((p) async {
        final tops = await EmpathyPollService.getTopOptions(p.id, top: 3);
        return MapEntry(p.id, tops);
      }),
    );
    if (!mounted) return;

    for (final entry in results) {
      _closedTopOptions[entry.key] = entry.value;
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

    final result = await EmpathyPollService.empathize(_activePoll!.id, optionId);
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
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? '오류가 발생했습니다.')),
      );
    }
  }

  Future<void> _submitAddOption() async {
    if (_activePoll == null || _addingOption) return;
    final text = _addOptionController.text.trim();
    if (text.isEmpty) return;

    setState(() => _addingOption = true);
    final result = await EmpathyPollService.addOption(_activePoll!.id, text);
    if (!mounted) return;
    setState(() => _addingOption = false);

    if (result.success) {
      _addOptionController.clear();
      FocusScope.of(context).unfocus();
      AdminActivityService.log(
        ActivityEventType.pollAddOption,
        page: 'bond',
        targetId: result.optionId,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? '오류가 발생했습니다.')),
      );
    }
  }

  void _showReportDialog(PollOption option) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('보기 신고', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: Text('"${option.content}" 보기를 신고하시겠습니까?', style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await EmpathyPollService.reportOption(_activePoll!.id, option.id);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result.success ? '신고가 접수되었습니다.' : (result.error ?? '오류'))),
              );
            },
            child: const Text('신고', style: TextStyle(color: AppColors.error)),
          ),
        ],
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
        child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()),
      );
    }

    if (_activePoll == null) {
      return AppMutedCard(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Icon(Icons.how_to_vote_outlined, size: 36, color: AppColors.textDisabled),
            const SizedBox(height: 12),
            const Text('오늘의 투표가 아직 등록되지 않았어요.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            const Text('곧 새로운 주제가 올라올 거예요!',
                style: TextStyle(fontSize: 12, color: AppColors.textDisabled)),
            const SizedBox(height: 12),
          ],
        ),
      );
    }

    final poll = _activePoll!;
    final hasVoted = _myVoteOptionId != null;
    final totalEmpathy = _options.fold<int>(0, (sum, o) => sum + o.empathyCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.how_to_vote_outlined, size: 16, color: AppColors.textDisabled),
            const SizedBox(width: 6),
            const Text('오늘의 공감 투표',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const Spacer(),
            _buildCountdown(),
          ],
        ),
        const SizedBox(height: 12),
        AppMutedCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 질문
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppBadge(label: '오늘', bgColor: AppColors.pollBadgeBg, textColor: AppColors.pollBadgeText),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(poll.question,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.4)),
                    ),
                  ],
                ),
              ),
              // 보기 목록
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: Column(
                  children: _options
                      .map((o) => _buildOptionTile(
                          option: o, isSelected: _myVoteOptionId == o.id, hasVoted: hasVoted, totalEmpathy: totalEmpathy))
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
                    child: Text('$totalEmpathy명 참여',
                        style: const TextStyle(fontSize: 11, color: AppColors.textDisabled)),
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
        border: Border.all(color: AppColors.textDisabled.withValues(alpha: 0.3), width: 1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _addOptionController,
              maxLength: EmpathyPollService.maxOptionLength,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: '나만의 보기를 적어주세요',
                hintStyle: TextStyle(fontSize: 13, color: AppColors.textDisabled),
                counterText: '',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 12),
                isDense: true,
              ),
              onSubmitted: (_) => _submitAddOption(),
            ),
          ),
          _addingOption
              ? const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: Icon(Icons.edit_note_rounded, size: 22, color: AppColors.accent),
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
    final percentage = totalEmpathy > 0 ? (option.empathyCount / totalEmpathy * 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: () => _onEmpathize(option.id),
        onLongPress: option.isSystem ? null : () => _showReportDialog(option),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 13),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.pollOptionSelectedBg : AppColors.pollOptionBg.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              _buildRadioCircle(isSelected),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.content,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                            color: isSelected ? AppColors.pollOptionSelectedText : AppColors.pollOptionText)),
                    if (!option.isSystem)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('유저 추가',
                            style: TextStyle(
                                fontSize: 10,
                                color: isSelected
                                    ? AppColors.pollOptionSelectedText.withValues(alpha: 0.6)
                                    : AppColors.textDisabled)),
                      ),
                  ],
                ),
              ),
              if (hasVoted) ...[
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppColors.pollOptionSelectedText.withValues(alpha: 0.8)
                                : AppColors.textSecondary)),
                    Text('${option.empathyCount}명',
                        style: TextStyle(
                            fontSize: 10,
                            color: isSelected
                                ? AppColors.pollOptionSelectedText.withValues(alpha: 0.5)
                                : AppColors.textDisabled)),
                  ],
                ),
              ],
            ],
          ),
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
        color: isSelected ? AppColors.pollOptionSelectedText.withValues(alpha: 0.15) : Colors.transparent,
        border: Border.all(
          color: isSelected
              ? AppColors.pollOptionSelectedText.withValues(alpha: 0.6)
              : AppColors.textDisabled.withValues(alpha: 0.5),
          width: isSelected ? 1.5 : 0.8,
        ),
      ),
      child: isSelected
          ? Center(
              child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.pollOptionSelectedText)))
          : null,
    );
  }

  Widget _buildCountdown() {
    if (_remaining == Duration.zero) {
      return const Text('마감됨', style: TextStyle(fontSize: 11, color: AppColors.textDisabled));
    }
    final h = _remaining.inHours;
    final m = _remaining.inMinutes % 60;
    final s = _remaining.inSeconds % 60;
    final text = h > 0
        ? '${h}시간 ${m}분 남음'
        : m > 0
            ? '${m}분 ${s}초 남음'
            : '${s}초 남음';

    return Text(text,
        style: TextStyle(
            fontSize: 11,
            color: _remaining.inMinutes < 60 ? AppColors.cardEmphasis : AppColors.textDisabled,
            fontWeight: _remaining.inMinutes < 60 ? FontWeight.w600 : FontWeight.w400));
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
            Text('지난 투표 결과',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 12),

        if (_closedPolls.isEmpty && _closedLoading)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else if (_closedPolls.isEmpty && !_closedLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('아직 종료된 투표가 없어요.', style: TextStyle(fontSize: 13, color: AppColors.textDisabled)),
            ),
          )
        else ...[
          ..._closedPolls.map((poll) => _buildClosedPollCard(poll)),
          // 더보기 / 로딩
          if (_closedLoading)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_hasMoreClosed)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                child: TextButton.icon(
                  onPressed: _loadMoreClosedPolls,
                  icon: const Icon(Icons.expand_more, size: 18),
                  label: const Text('이전 투표 더보기', style: TextStyle(fontSize: 13)),
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
    final dateStr = _formatDate(poll.closedAt ?? poll.endsAt);
    final totalEmpathy = poll.totalEmpathyCount;
    // 옵션이 3개 미만이면 이미 전체 노출 → 댓글 허용. 그 외에는 펼친 뒤에만.
    final showCommentSection = isExpanded || topOptions.length < 3;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppMutedCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppBadge(label: dateStr, bgColor: AppColors.cardPrimary, textColor: AppColors.onCardPrimary),
                const Spacer(),
                Text('${totalEmpathy}명 참여', style: const TextStyle(fontSize: 11, color: AppColors.textDisabled)),
              ],
            ),
            const SizedBox(height: 10),
            Text(poll.question,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.4)),
            const SizedBox(height: 12),
            ...displayOptions.asMap().entries.map((entry) {
              return _buildClosedOptionRow(entry.key, entry.value, totalEmpathy);
            }),
            // 펼치기/접기 버튼
            if (!isExpanded && topOptions.length >= 3)
              Center(
                child: GestureDetector(
                  onTap: () => _expandPoll(poll.id),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('전체 보기',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.accent)),
                  ),
                ),
              )
            else if (isExpanded)
              Center(
                child: GestureDetector(
                  onTap: () => setState(() => _expandedPollIds.remove(poll.id)),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('접기', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textDisabled)),
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
            Icon(Icons.chat_bubble_outline, size: 14, color: AppColors.textDisabled),
            SizedBox(width: 6),
            Text('한마디',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<PollComment>>(
          stream: EmpathyPollService.pollCommentsStream(poll.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '한마디를 불러오지 못했어요.',
                  style: TextStyle(fontSize: 12, color: AppColors.error.withValues(alpha: 0.85)),
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
                ...list.map(_buildClosedCommentTile),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
        _buildClosedCommentInput(poll.id),
      ],
    );
  }

  Widget _buildClosedCommentTile(PollComment c) {
    final timeStr =
        '${c.createdAt.month}/${c.createdAt.day} ${c.createdAt.hour.toString().padLeft(2, '0')}:${c.createdAt.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              c.text,
              style: const TextStyle(fontSize: 13, height: 1.35, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeStr,
            style: const TextStyle(fontSize: 10, color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }

  Widget _buildClosedCommentInput(String pollId) {
    final busy = _submittingClosedComment[pollId] == true;
    final ctrl = _commentControllerFor(pollId);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.textDisabled.withValues(alpha: 0.3), width: 1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              maxLength: EmpathyPollService.maxPollCommentLength,
              maxLines: 2,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: '종료된 투표에 한마디 남기기',
                hintStyle: TextStyle(fontSize: 13, color: AppColors.textDisabled),
                counterText: '',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
                isDense: true,
              ),
              onSubmitted: (_) => _submitClosedPollComment(pollId),
            ),
          ),
          busy
              ? const Padding(
                  padding: EdgeInsets.only(right: 12, bottom: 8),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: Icon(Icons.edit_note_rounded, size: 22, color: AppColors.accent),
                  onPressed: () => _submitClosedPollComment(pollId),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
        ],
      ),
    );
  }

  Future<void> _submitClosedPollComment(String pollId) async {
    if (_submittingClosedComment[pollId] == true) return;
    final ctrl = _commentControllerFor(pollId);
    final text = ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _submittingClosedComment[pollId] = true);
    final result = await EmpathyPollService.addPollComment(pollId, text);
    if (!mounted) return;
    setState(() => _submittingClosedComment[pollId] = false);

    if (result.success) {
      ctrl.clear();
      FocusScope.of(context).unfocus();
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? '오류가 발생했습니다.')),
      );
    }
  }

  Widget _buildClosedOptionRow(int rank, PollOption option, int totalEmpathy) {
    final rankLabel = '${rank + 1}위';
    final pct = totalEmpathy > 0 ? (option.empathyCount / totalEmpathy * 100).toStringAsFixed(1) : '0.0';

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
                color: rank == 0 ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(option.content,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: rank == 0 ? FontWeight.w600 : FontWeight.w400,
                    color: AppColors.textPrimary)),
          ),
          const SizedBox(width: 8),
          Text('$pct%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(width: 4),
          Text('(${option.empathyCount})', style: const TextStyle(fontSize: 11, color: AppColors.textDisabled)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) => '${dt.month}/${dt.day}';
}
