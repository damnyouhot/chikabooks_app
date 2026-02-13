import 'package:flutter/material.dart';
import '../models/user_goal.dart';
import '../services/user_goal_service.dart';

/// 사용자 목표 관리 팝업
/// 
/// 기능:
/// - 목표 목록 보기 (최대 3개)
/// - 목표 추가 (주간/월간/연간 선택)
/// - 목표 완료 토글
/// - 목표 삭제
class UserGoalSheet {
  /// 팝업 표시
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _UserGoalSheetContent(),
    );
  }
}

class _UserGoalSheetContent extends StatefulWidget {
  const _UserGoalSheetContent();

  @override
  State<_UserGoalSheetContent> createState() => _UserGoalSheetContentState();
}

class _UserGoalSheetContentState extends State<_UserGoalSheetContent> {
  // ── 디자인 컬러 팔레트 (CaringPage와 동일) ──
  static const _kAccent = Color(0xFFF7CBCA);
  static const _kText = Color(0xFF5D6B6B);
  static const _kShadow2 = Color(0xFFD5E5E5);

  UserGoals? _goals;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    final goals = await UserGoalService.loadGoals();
    if (mounted) {
      setState(() {
        _goals = goals;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _kText.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Text(
                  '🎯 나의 목표',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
                const Spacer(),
                if (_goals != null && _goals!.canAdd)
                  GestureDetector(
                    onTap: _showAddGoalDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _kAccent.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 16, color: _kText),
                          SizedBox(width: 4),
                          Text(
                            '추가',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _kText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 내용
          Flexible(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_goals == null || _goals!.items.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _goals!.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildGoalCard(_goals!.items[index]);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '아직 목표가 없어요',
            style: TextStyle(
              fontSize: 15,
              color: _kText.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _showAddGoalDialog,
            icon: const Icon(Icons.add_circle_outline, size: 20),
            label: const Text('첫 목표 만들기'),
            style: TextButton.styleFrom(
              foregroundColor: _kText,
              backgroundColor: _kAccent.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(UserGoal goal) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: goal.isDone
            ? _kAccent.withOpacity(0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: goal.isDone
              ? _kAccent.withOpacity(0.4)
              : _kShadow2.withOpacity(0.4),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _kShadow2.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 완료 체크박스
          GestureDetector(
            onTap: () => _toggleDone(goal),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: goal.isDone ? _kAccent : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: goal.isDone ? _kAccent : _kText.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: goal.isDone
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),

          // 목표 내용
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _kText,
                    decoration: goal.isDone
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${goal.periodLabel} · ${goal.periodKey}',
                  style: TextStyle(
                    fontSize: 11,
                    color: _kText.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),

          // 삭제 버튼
          GestureDetector(
            onTap: () => _deleteGoal(goal),
            child: Icon(
              Icons.delete_outline,
              size: 20,
              color: _kText.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  /// 목표 추가 다이얼로그
  void _showAddGoalDialog() {
    final titleCtrl = TextEditingController();
    PeriodType selectedPeriod = PeriodType.week;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                '새 목표',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _kText,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 목표 입력
                  TextField(
                    controller: titleCtrl,
                    autofocus: true,
                    maxLength: 50,
                    decoration: InputDecoration(
                      hintText: '목표를 입력하세요',
                      hintStyle: TextStyle(
                        color: _kText.withOpacity(0.4),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _kAccent, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 기간 선택
                  const Text(
                    '기간',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _kText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildPeriodChip(
                        '주간',
                        PeriodType.week,
                        selectedPeriod,
                        (type) {
                          setDialogState(() => selectedPeriod = type);
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildPeriodChip(
                        '월간',
                        PeriodType.month,
                        selectedPeriod,
                        (type) {
                          setDialogState(() => selectedPeriod = type);
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildPeriodChip(
                        '연간',
                        PeriodType.year,
                        selectedPeriod,
                        (type) {
                          setDialogState(() => selectedPeriod = type);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) return;

                    Navigator.pop(ctx);

                    final success = await UserGoalService.addGoal(
                      title: title,
                      periodType: selectedPeriod,
                    );

                    if (success) {
                      _loadGoals();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('목표가 추가되었어요'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAccent,
                    foregroundColor: _kText,
                  ),
                  child: const Text('추가'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPeriodChip(
    String label,
    PeriodType type,
    PeriodType selected,
    Function(PeriodType) onSelect,
  ) {
    final isSelected = type == selected;
    return GestureDetector(
      onTap: () => onSelect(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: _kText,
          ),
        ),
      ),
    );
  }

  /// 완료 토글
  Future<void> _toggleDone(UserGoal goal) async {
    await UserGoalService.toggleDone(goal.id);
    _loadGoals();
  }

  /// 목표 삭제
  Future<void> _deleteGoal(UserGoal goal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('목표 삭제'),
          content: const Text('이 목표를 삭제할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await UserGoalService.deleteGoal(goal.id);
      _loadGoals();
    }
  }
}

