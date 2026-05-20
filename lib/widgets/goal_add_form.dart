import 'package:flutter/material.dart';
import '../models/user_goal.dart';
import '../services/user_goal_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_primary_button.dart';

/// 목표 추가 폼 (완성형)
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

  /// 프로젝트 — 사용자 지정 마감일(선택). null 이면 periodType 기본값 사용.
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
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '새 목표',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 타입 선택
            const Text(
              '목표 타입',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTypeChip(
                    '루틴 (매일)',
                    GoalType.routine,
                    '반복 체크',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTypeChip(
                    '프로젝트',
                    GoalType.project,
                    '한 번 완료',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 2. 목표 내용
            const Text(
              '목표 내용',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              maxLength: 60,
              decoration: InputDecoration(
                hintText: '작고 하찮을수록 성공률이 올라가요.',
                hintStyle: const TextStyle(
                  color: AppColors.textDisabled,
                  fontSize: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: AppColors.accent, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 3. 기간 선택
            const Text(
              '기간',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPeriodChip('오늘', PeriodType.day),
                _buildPeriodChip('주간', PeriodType.week),
                _buildPeriodChip('월간', PeriodType.month),
                _buildPeriodChip('연간', PeriodType.year),
              ],
            ),

            // 4-P. (프로젝트 전용) 마감일 + 체크포인트
            if (_selectedType == GoalType.project) ...[
              const SizedBox(height: 24),
              const Text(
                '마감일 (선택)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '비워두면 위에서 고른 기간(주말/월말 등)을 마감으로 사용합니다.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textDisabled,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickDeadline,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: _deadline != null
                                ? AppColors.accent
                                : AppColors.divider,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              _deadline == null
                                  ? '날짜 선택'
                                  : '${_deadline!.year}년 ${_deadline!.month}월 ${_deadline!.day}일',
                              style: TextStyle(
                                fontSize: 13,
                                color: _deadline == null
                                    ? AppColors.textDisabled
                                    : AppColors.textPrimary,
                                fontWeight: _deadline == null
                                    ? FontWeight.w400
                                    : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_deadline != null) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: '날짜 비우기',
                      onPressed: () => setState(() => _deadline = null),
                      icon: const Icon(Icons.close,
                          size: 18, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  const Text(
                    '체크포인트 (선택, 최대 5개)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (_checkpointControllers.length < _maxCheckpoints)
                    GestureDetector(
                      onTap: _addCheckpoint,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline,
                                size: 16, color: AppColors.textPrimary),
                            SizedBox(width: 4),
                            Text(
                              '추가',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                '"자료 조사 → 초안 → 검토" 같은 단계로 쪼개면 진행률이 보여요.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textDisabled,
                ),
              ),
              const SizedBox(height: 8),
              for (int i = 0; i < _checkpointControllers.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.divider.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _checkpointControllers[i],
                          maxLength: 30,
                          decoration: InputDecoration(
                            hintText: '단계 ${i + 1}',
                            counterText: '',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: AppColors.divider),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '삭제',
                        onPressed: () => _removeCheckpoint(i),
                        icon: const Icon(Icons.close,
                            size: 16, color: AppColors.textDisabled),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            // 4. (루틴 전용) 주 n회
            if (_selectedType == GoalType.routine) ...[
              const SizedBox(height: 24),
              const Text(
                '빈도 (주 몇 회?)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (i) {
                  final target = i + 1;
                  final isSelected = _weeklyTarget == target;
                  return GestureDetector(
                    onTap: () => setState(() => _weeklyTarget = target),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accent.withOpacity(0.3)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppColors.accent : AppColors.divider,
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$target',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],

            const SizedBox(height: 40),

            // 5. 추가하기 버튼
            AppPrimaryButton(
              label: '추가하기',
              onPressed: _addGoal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, GoalType type, String subtitle) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedType = type;
        // 루틴은 「오늘」 기간을 쓸 수 없으므로 자동으로 「주간」으로 옮긴다.
        if (type == GoalType.routine && _selectedPeriod == PeriodType.day) {
          _selectedPeriod = PeriodType.week;
        }
      }),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.divider,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String label, PeriodType type) {
    final isSelected = _selectedPeriod == type;
    // 「오늘」기간은 단발성 — 루틴(매일 반복)과 의미가 어색하므로 비활성.
    final isDisabled =
        type == PeriodType.day && _selectedType == GoalType.routine;
    return GestureDetector(
      onTap: isDisabled
          ? null
          : () => setState(() => _selectedPeriod = type),
      child: Opacity(
        opacity: isDisabled ? 0.4 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accent.withOpacity(0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.divider,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
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

    final success = await UserGoalService.addGoal(
      title: title,
      type: _selectedType,
      periodType: _selectedPeriod,
      weeklyTarget: _weeklyTarget,
      deadline: _selectedType == GoalType.project ? _deadline : null,
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


















