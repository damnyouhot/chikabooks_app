import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_muted_card.dart';
import '../core/widgets/app_primary_button.dart';
import '../models/user_goal.dart';
import '../services/user_goal_service.dart';

/// 목표 추가 폼 — 「루틴 / 프로젝트」 두 분기를 한 화면에서 받는다.
///
/// 디자인 톤은 다른 모달/입력 화면과 통일:
///   · Scaffold 배경 = AppColors.appBg (크림톤)
///   · 섹션은 AppMutedCard 로 그룹핑
///   · 입력칸은 filled + 밝은 surfaceMuted 배경, border 없음
///   · 선택 칩은 미선택=outline / 선택=AppColors.lime 솔리드 + onCardEmphasis
class GoalAddForm extends StatefulWidget {
  final VoidCallback onAdded;

  const GoalAddForm({super.key, required this.onAdded});

  @override
  State<GoalAddForm> createState() => _GoalAddFormState();
}

class _GoalAddFormState extends State<GoalAddForm> {
  final _titleController = TextEditingController();
  GoalType _selectedType = GoalType.routine;
  PeriodType _selectedPeriod = PeriodType.week;
  int _weeklyTarget = 7;

  /// 프로젝트 — 사용자 지정 마감일.
  /// 비워두면 저장 시 「오늘 + 7일」을 기본값으로 자동 채운다.
  DateTime? _deadline;

  /// 프로젝트 — 체크포인트 1~5개. 빈 텍스트는 저장 시 제외.
  final List<TextEditingController> _checkpointControllers = [];

  static const int _maxCheckpoints = 5;

  @override
  void dispose() {
    _titleController.dispose();
    for (final c in _checkpointControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      helpText: '마감일 선택',
      cancelText: '취소',
      confirmText: '선택',
      builder: (context, child) {
        // 캘린더 피커도 앱 라임 톤으로 통일.
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.lime,
                  onPrimary: AppColors.onCardEmphasis,
                ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  void _addCheckpoint() {
    if (_checkpointControllers.length >= _maxCheckpoints) return;
    setState(() => _checkpointControllers.add(TextEditingController()));
  }

  void _removeCheckpoint(int i) {
    final c = _checkpointControllers.removeAt(i);
    c.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        backgroundColor: AppColors.appBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '새 목표',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xxl + AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1) 목표 타입 ───────────────────────────────────
            _SectionCard(
              title: '목표 타입',
              child: Row(
                children: [
                  Expanded(
                    child: _buildTypeChip(
                      title: '루틴',
                      subtitle: '매일/주간 반복 체크',
                      icon: Icons.replay_circle_filled_outlined,
                      type: GoalType.routine,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _buildTypeChip(
                      title: '프로젝트',
                      subtitle: '기한 안에 한 번 완료',
                      icon: Icons.flag_outlined,
                      type: GoalType.project,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── 2) 목표 내용 ───────────────────────────────────
            _SectionCard(
              title: '목표 내용',
              child: TextField(
                controller: _titleController,
                maxLength: 60,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: _selectedType == GoalType.routine
                      ? '예) 잠들기 전 책 5쪽 읽기'
                      : '예) 보험청구 강의 듣기',
                  hintStyle: const TextStyle(
                    color: AppColors.textDisabled,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: AppColors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(
                        color: AppColors.lime, width: 1.5),
                  ),
                  counterText:
                      '${_titleController.text.characters.length}/60',
                  counterStyle: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── 3-R) (루틴 전용) 기간 ─────────────────────────
            if (_selectedType == GoalType.routine) ...[
              _SectionCard(
                title: '기간',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPeriodChip('오늘', PeriodType.day),
                    _buildPeriodChip('주간', PeriodType.week),
                    _buildPeriodChip('월간', PeriodType.month),
                    _buildPeriodChip('연간', PeriodType.year),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ── 3-P) (프로젝트 전용) 마감일 ──────────────────
            if (_selectedType == GoalType.project) ...[
              _SectionCard(
                title: '마감일',
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDeadline,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: _deadline != null
                                  ? AppColors.lime
                                  : AppColors.divider,
                              width: _deadline != null ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: _deadline != null
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _deadline == null
                                    ? '날짜 선택'
                                    : '${_deadline!.year}년 ${_deadline!.month}월 ${_deadline!.day}일',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _deadline == null
                                      ? AppColors.textDisabled
                                      : AppColors.textPrimary,
                                  fontWeight: _deadline == null
                                      ? FontWeight.w400
                                      : FontWeight.w700,
                                ),
                              ),
                              if (_deadline != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  _dDayLabel(_deadline!),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.lime,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_deadline != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: '날짜 비우기',
                        onPressed: () => setState(() => _deadline = null),
                        icon: const Icon(Icons.close,
                            size: 18, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ── 4-R) (루틴 전용) 빈도 ─────────────────────────
            if (_selectedType == GoalType.routine) ...[
              _SectionCard(
                title: '빈도 (주 몇 회?)',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (i) {
                    final target = i + 1;
                    final isSelected = _weeklyTarget == target;
                    return GestureDetector(
                      onTap: () => setState(() => _weeklyTarget = target),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.lime
                              : AppColors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.lime
                                : AppColors.divider,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$target',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? AppColors.onCardEmphasis
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ── 4-P) (프로젝트 전용) 체크포인트 ──────────────
            if (_selectedType == GoalType.project) ...[
              _SectionCard(
                titleWidget: Row(
                  children: [
                    const Text(
                      '체크포인트',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_checkpointControllers.length}/$_maxCheckpoints',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDisabled,
                      ),
                    ),
                    const Spacer(),
                    if (_checkpointControllers.length < _maxCheckpoints)
                      GestureDetector(
                        onTap: _addCheckpoint,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.lime,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add,
                                  size: 14,
                                  color: AppColors.onCardEmphasis),
                              SizedBox(width: 3),
                              Text(
                                '추가',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onCardEmphasis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '"자료 조사 → 초안 → 검토" 처럼 단계로 쪼개면 진행률이 보여요.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textDisabled,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_checkpointControllers.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                              color: AppColors.divider, width: 1),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 14,
                                color: AppColors.textDisabled),
                            SizedBox(width: 6),
                            Text(
                              '아직 단계가 없어요. 우측 「추가」를 눌러주세요.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textDisabled,
                              ),
                            ),
                          ],
                        ),
                      ),
                    for (int i = 0; i < _checkpointControllers.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.lime,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.onCardEmphasis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _checkpointControllers[i],
                                maxLength: 30,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: '단계 ${i + 1}',
                                  counterText: '',
                                  isDense: true,
                                  filled: true,
                                  fillColor: AppColors.white,
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: AppColors.lime, width: 1.5),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: '삭제',
                              onPressed: () => _removeCheckpoint(i),
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ── 5) 추가 버튼 ──────────────────────────────────
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(
              label: '추가하기',
              onPressed: _addGoal,
            ),
          ],
        ),
      ),
    );
  }

  // ── 헬퍼 ────────────────────────────────────────────────────

  Widget _buildTypeChip({
    required String title,
    required String subtitle,
    required IconData icon,
    required GoalType type,
  }) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedType = type;
        // 루틴은 「오늘」 기간을 쓸 수 없음 → 자동으로 「주간」 으로.
        if (type == GoalType.routine && _selectedPeriod == PeriodType.day) {
          _selectedPeriod = PeriodType.week;
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lime : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.lime : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? AppColors.onCardEmphasis
                  : AppColors.textPrimary,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? AppColors.onCardEmphasis
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? AppColors.onCardEmphasis.withValues(alpha: 0.8)
                    : AppColors.textDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String label, PeriodType type) {
    final isSelected = _selectedPeriod == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lime : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.lime : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? AppColors.onCardEmphasis
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  String _dDayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dl = DateTime(d.year, d.month, d.day);
    final diff = dl.difference(today).inDays;
    if (diff == 0) return 'D-DAY';
    if (diff > 0) return 'D-$diff';
    return 'D+${-diff}';
  }

  Future<void> _addGoal() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('목표를 입력해주세요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 프로젝트 체크포인트 — 빈 텍스트는 제외, 입력된 것만 모델로 변환.
    final checkpoints = _selectedType == GoalType.project
        ? [
            for (final c in _checkpointControllers)
              if (c.text.trim().isNotEmpty)
                GoalCheckpoint(
                  id: 'cp_${DateTime.now().microsecondsSinceEpoch}_${c.hashCode}',
                  title: c.text.trim(),
                ),
          ]
        : const <GoalCheckpoint>[];

    // 프로젝트는 「기간」 입력을 받지 않으므로, 마감일이 없으면 +7일을 기본으로
    // 채워 effectiveDeadline 이 항상 의미 있는 값을 갖게 한다.
    DateTime? deadline = _deadline;
    if (_selectedType == GoalType.project && deadline == null) {
      deadline = DateTime.now().add(const Duration(days: 7));
    }

    // 프로젝트는 periodType 의미가 없지만 모델 호환을 위해 month 로 고정.
    final periodType = _selectedType == GoalType.project
        ? PeriodType.month
        : _selectedPeriod;

    final success = await UserGoalService.addGoal(
      title: title,
      type: _selectedType,
      periodType: periodType,
      weeklyTarget: _weeklyTarget,
      deadline: _selectedType == GoalType.project ? deadline : null,
      checkpoints: checkpoints,
    );

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('목표가 추가됐어요'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onAdded();
      }
    }
  }
}

/// 섹션 카드 — 제목 + 본문을 AppMutedCard 로 그룹핑.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    this.title,
    this.titleWidget,
    required this.child,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppMutedCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (titleWidget != null)
            titleWidget!
          else if (title != null)
            Text(
              title!,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
