import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';
import '../../core/widgets/app_badge.dart';
import '../../models/poll.dart';
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
  Poll? _activePoll;
  bool _loading = true;
  String? _myVoteOptionId;
  StreamSubscription<List<PollOption>>? _optionsSub;
  StreamSubscription<String?>? _voteSub;
  List<PollOption> _options = [];
  bool _empathizing = false;

  // 지난 투표
  List<Poll> _closedPolls = [];
  bool _closedLoading = false;
  final Map<String, List<PollOption>> _closedTopOptions = {};

  // 마감 카운트다운
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadActivePoll();
    _loadClosedPolls();
  }

  /// 외부에서 탭 전환 시 데이터 갱신
  void reload() {
    _loadActivePoll();
    _loadClosedPolls();
  }

  @override
  void dispose() {
    _optionsSub?.cancel();
    _voteSub?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

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

  Future<void> _loadClosedPolls() async {
    setState(() => _closedLoading = true);
    final polls = await EmpathyPollService.getClosedPolls(limit: 10);
    if (!mounted) return;

    for (final p in polls) {
      final tops = await EmpathyPollService.getTopOptions(p.id, top: 3);
      _closedTopOptions[p.id] = tops;
    }

    if (!mounted) return;
    setState(() {
      _closedPolls = polls;
      _closedLoading = false;
    });
  }

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

  Future<void> _showAddOptionSheet() async {
    if (_activePoll == null) return;
    final controller = TextEditingController();

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.xl,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '내 보기 추가하기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${EmpathyPollService.maxOptionLength}자 이내로 작성해주세요.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLength: EmpathyPollService.maxOptionLength,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '나만의 보기를 적어주세요',
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textDisabled,
                ),
                filled: true,
                fillColor: AppColors.surfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('추가하기'),
              ),
            ),
          ],
        ),
      ),
    );

    if (submitted == true && controller.text.trim().isNotEmpty) {
      final result = await EmpathyPollService.addOption(
        _activePoll!.id,
        controller.text,
      );
      if (!mounted) return;
      if (result.success) {
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
    controller.dispose();
  }

  void _showReportDialog(PollOption option) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('보기 신고', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: Text(
          '"${option.content}" 보기를 신고하시겠습니까?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await EmpathyPollService.reportOption(
                _activePoll!.id,
                option.id,
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result.success ? '신고가 접수되었습니다.' : (result.error ?? '오류가 발생했습니다.'),
                  ),
                ),
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
            Icon(Icons.how_to_vote_outlined, size: 36, color: AppColors.textDisabled),
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
    final totalEmpathy = _options.fold<int>(0, (sum, o) => sum + o.empathyCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 헤더
        Row(
          children: [
            const Icon(Icons.how_to_vote_outlined, size: 16, color: AppColors.textDisabled),
            const SizedBox(width: 6),
            const Text(
              '오늘의 공감 투표',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const Spacer(),
            _buildCountdown(),
          ],
        ),
        const SizedBox(height: 12),

        // 투표 카드
        AppMutedCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 질문
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.lg,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppBadge(
                      label: '오늘',
                      bgColor: AppColors.pollBadgeBg,
                      textColor: AppColors.pollBadgeText,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
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
                  ],
                ),
              ),

              // 보기 목록
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: Column(
                  children: _options.map((option) {
                    return _buildOptionTile(
                      option: option,
                      isSelected: _myVoteOptionId == option.id,
                      hasVoted: hasVoted,
                      totalEmpathy: totalEmpathy,
                    );
                  }).toList(),
                ),
              ),

              // 내 보기 추가 버튼
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: GestureDetector(
                  onTap: _showAddOptionSheet,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.textDisabled.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          '내 보기 추가하기',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 참여 현황
              if (totalEmpathy > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Center(
                    child: Text(
                      '$totalEmpathy명 참여',
                      style: const TextStyle(fontSize: 11, color: AppColors.textDisabled),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required PollOption option,
    required bool isSelected,
    required bool hasVoted,
    required int totalEmpathy,
  }) {
    final percentage = totalEmpathy > 0
        ? (option.empathyCount / totalEmpathy * 100)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: () => _onEmpathize(option.id),
        onLongPress: option.isSystem ? null : () => _showReportDialog(option),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.pollOptionSelectedBg
                : AppColors.pollOptionBg.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              // 라디오 인디케이터
              _buildRadioCircle(isSelected),
              const SizedBox(width: 12),
              // 보기 텍스트
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.content,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        color: isSelected
                            ? AppColors.pollOptionSelectedText
                            : AppColors.pollOptionText,
                      ),
                    ),
                    if (!option.isSystem)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '유저 추가',
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected
                                ? AppColors.pollOptionSelectedText.withValues(alpha: 0.6)
                                : AppColors.textDisabled,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // 공감 수 / 퍼센트
              if (hasVoted) ...[
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppColors.pollOptionSelectedText.withValues(alpha: 0.8)
                            : AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${option.empathyCount}명',
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected
                            ? AppColors.pollOptionSelectedText.withValues(alpha: 0.5)
                            : AppColors.textDisabled,
                      ),
                    ),
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
        color: isSelected
            ? AppColors.pollOptionSelectedText.withValues(alpha: 0.15)
            : Colors.transparent,
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.pollOptionSelectedText,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildCountdown() {
    if (_remaining == Duration.zero) {
      return const Text(
        '마감됨',
        style: TextStyle(fontSize: 11, color: AppColors.textDisabled),
      );
    }
    final h = _remaining.inHours;
    final m = _remaining.inMinutes % 60;
    final s = _remaining.inSeconds % 60;
    final text = h > 0
        ? '${h}시간 ${m}분 남음'
        : m > 0
            ? '${m}분 ${s}초 남음'
            : '${s}초 남음';

    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: _remaining.inMinutes < 60
            ? AppColors.cardEmphasis
            : AppColors.textDisabled,
        fontWeight: _remaining.inMinutes < 60 ? FontWeight.w600 : FontWeight.w400,
      ),
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
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_closedLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_closedPolls.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                '아직 종료된 투표가 없어요.',
                style: TextStyle(fontSize: 13, color: AppColors.textDisabled),
              ),
            ),
          )
        else
          ..._closedPolls.map((poll) => _buildClosedPollCard(poll)),
      ],
    );
  }

  Widget _buildClosedPollCard(Poll poll) {
    final topOptions = _closedTopOptions[poll.id] ?? [];
    final dateStr = _formatDate(poll.closedAt ?? poll.endsAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppMutedCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더: 날짜 + 총 참여 수
            Row(
              children: [
                AppBadge(
                  label: dateStr,
                  bgColor: AppColors.cardPrimary,
                  textColor: AppColors.onCardPrimary,
                ),
                const Spacer(),
                Text(
                  '${poll.totalEmpathyCount}명 참여',
                  style: const TextStyle(fontSize: 11, color: AppColors.textDisabled),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 질문
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
            // 상위 3개 결과
            ...topOptions.asMap().entries.map((entry) {
              final rank = entry.key;
              final opt = entry.value;
              return _buildClosedOptionRow(rank, opt, poll.totalEmpathyCount);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildClosedOptionRow(int rank, PollOption option, int totalEmpathy) {
    const medals = ['🥇', '🥈', '🥉'];
    final medal = rank < medals.length ? medals[rank] : '';
    final pct = totalEmpathy > 0
        ? (option.empathyCount / totalEmpathy * 100).toStringAsFixed(1)
        : '0.0';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(medal, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            child: Text(
              option.content,
              style: TextStyle(
                fontSize: 13,
                fontWeight: rank == 0 ? FontWeight.w600 : FontWeight.w400,
                color: AppColors.textPrimary,
              ),
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

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}';
  }
}
