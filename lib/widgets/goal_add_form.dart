import 'package:flutter/material.dart';
import '../models/user_goal.dart';
import '../services/user_goal_service.dart';

/// 목표 추가 폼 (완성형)
class GoalAddForm extends StatefulWidget {
  final VoidCallback onAdded;

  const GoalAddForm({super.key, required this.onAdded});

  @override
  State<GoalAddForm> createState() => _GoalAddFormState();
}

class _GoalAddFormState extends State<GoalAddForm> {
  static const _kAccent = Color(0xFFF7CBCA);
  static const _kText = Color(0xFF5D6B6B);
  static const _kShadow2 = Color(0xFFD5E5E5);

  final _titleController = TextEditingController();
  GoalType _selectedType = GoalType.routine;
  PeriodType _selectedPeriod = PeriodType.week;
  int _weeklyTarget = 7;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: _kText),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '새 목표',
          style: TextStyle(
            color: _kText,
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
                color: _kText,
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
                color: _kText,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              maxLength: 60,
              decoration: InputDecoration(
                hintText: '작고 하찮을수록 성공률이 올라가요.',
                hintStyle: TextStyle(
                  color: _kText.withOpacity(0.4),
                  fontSize: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _kShadow2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _kAccent, width: 2),
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
                color: _kText,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildPeriodChip('주간', PeriodType.week),
                const SizedBox(width: 8),
                _buildPeriodChip('월간', PeriodType.month),
                const SizedBox(width: 8),
                _buildPeriodChip('연간', PeriodType.year),
              ],
            ),

            // 4. (루틴 전용) 주 n회
            if (_selectedType == GoalType.routine) ...[
              const SizedBox(height: 24),
              const Text(
                '빈도 (주 몇 회?)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _kText,
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
                            ? _kAccent.withOpacity(0.3)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? _kAccent : _kShadow2,
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
                          color: _kText,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],

            const SizedBox(height: 40),

            // 5. 추가하기 버튼
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _addGoal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: _kText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '추가하기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, GoalType type, String subtitle) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? _kAccent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _kAccent : _kShadow2,
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
                color: _kText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: _kText.withOpacity(0.5),
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _kAccent.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _kAccent : _kShadow2,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: _kText,
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

    final success = await UserGoalService.addGoal(
      title: title,
      type: _selectedType,
      periodType: _selectedPeriod,
      weeklyTarget: _weeklyTarget,
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

