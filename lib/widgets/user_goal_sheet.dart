import 'package:flutter/material.dart';
import '../models/user_goal.dart';
import '../models/routine_check.dart';
import '../services/user_goal_service.dart';
import 'goal_add_form.dart';

/// 사용자 목표 허브 (완성형)
class UserGoalSheet {
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

class _UserGoalSheetContentState extends State<_UserGoalSheetContent>
    with SingleTickerProviderStateMixin {
  // ── 디자인 컬러 팔레트 ──
  static const _kAccent = Color(0xFFF7CBCA);
  static const _kText = Color(0xFF5D6B6B);
  static const _kShadow2 = Color(0xFFD5E5E5);
  static const _kSuccess = Color(0xFFB8E6D5);

  UserGoals? _goals;
  RoutineCheck? _todayCheck;
  bool _loading = true;
  
  // 탭 컨트롤러
  late TabController _tabController;
  int _currentTab = 0;  // 0: 루틴, 1: 프로젝트

  // 주간 체크 횟수 캐시 (goalId -> count)
  final Map<String, int> _weeklyCheckCounts = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() => _currentTab = _tabController.index);
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final goals = await UserGoalService.loadGoals();
    final todayCheck = await UserGoalService.loadTodayCheck();
    
    // 루틴별 주간 체크 횟수 로드
    for (var goal in goals.routines) {
      final count = await UserGoalService.getWeeklyCheckCount(goal.id);
      _weeklyCheckCounts[goal.id] = count;
    }

    if (mounted) {
      setState(() {
        _goals = goals;
        _todayCheck = todayCheck;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
          const SizedBox(height: 16),

          // 헤더
          _buildHeader(),
          const SizedBox(height: 8),

          // 상태 요약
          if (!_loading && _goals != null && _goals!.items.isNotEmpty) _buildSummary(),
          if (!_loading && _goals != null && _goals!.items.isNotEmpty) const SizedBox(height: 16),

          // 탭
          if (!_loading && _goals != null && _goals!.items.isNotEmpty) _buildTabs(),
          if (!_loading && _goals != null && _goals!.items.isNotEmpty) const SizedBox(height: 16),

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

  /// 헤더 (제목 + 추가 버튼)
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '나의 목표',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '최대 3개 · 루틴/프로젝트 · 주/월/연',
                style: TextStyle(
                  fontSize: 11,
                  color: _kText.withOpacity(0.5),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (_goals != null && _goals!.canAdd)
            GestureDetector(
              onTap: _showAddGoalForm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 18, color: _kText),
                    SizedBox(width: 4),
                    Text(
                      '추가',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kText,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_goals != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: _kShadow2.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '3/3',
                style: TextStyle(
                  fontSize: 12,
                  color: _kText.withOpacity(0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 상태 요약 (오늘 체크, 이번 주 진행, 칭호)
  Widget _buildSummary() {
    final routines = _goals!.routines;
    
    // 오늘 체크한 루틴 개수
    int todayChecked = 0;
    if (_todayCheck != null) {
      for (var goal in routines) {
        if (_todayCheck!.isChecked(goal.id)) todayChecked++;
      }
    }

    // 이번 주 총 체크 횟수
    int weeklyTotal = 0;
    for (var count in _weeklyCheckCounts.values) {
      weeklyTotal += count;
    }

    // 칭호 계산
    String title = '버티는 중';
    if (weeklyTotal >= 5) {
      title = '이번 주 꽤 잘했다';
    } else if (weeklyTotal >= 2) {
      title = '조금 회복';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _kAccent.withOpacity(0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem(
              icon: '✓',
              label: '오늘 체크',
              value: '$todayChecked/${routines.length}',
            ),
            Container(
              width: 1,
              height: 20,
              color: _kShadow2.withOpacity(0.5),
            ),
            _buildSummaryItem(
              icon: '📊',
              label: '이번 주',
              value: '$weeklyTotal회',
            ),
            Container(
              width: 1,
              height: 20,
              color: _kShadow2.withOpacity(0.5),
            ),
            _buildSummaryItem(
              icon: '🏅',
              label: title,
              value: '',
              isTitle: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required String icon,
    required String label,
    required String value,
    bool isTitle = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: _kText.withOpacity(0.6),
          ),
        ),
        if (!isTitle) ...[
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _kText,
            ),
          ),
        ],
      ],
    );
  }

  /// 탭 (루틴 / 프로젝트)
  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: _kShadow2.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _kShadow2.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: _kText,
          unselectedLabelColor: _kText.withOpacity(0.5),
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          dividerColor: Colors.transparent,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('루틴'),
                  const SizedBox(width: 4),
                  if (_goals!.routines.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _kAccent.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_goals!.routines.length}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('프로젝트'),
                  const SizedBox(width: 4),
                  if (_goals!.projects.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _kAccent.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_goals!.projects.length}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 내용 (탭별)
  Widget _buildContent() {
    if (_goals == null || _goals!.items.isEmpty) {
      return _buildEmptyState();
    }

    final items = _currentTab == 0 ? _goals!.routines : _goals!.projects;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _currentTab == 0 ? '루틴이 없어요' : '프로젝트가 없어요',
              style: TextStyle(
                fontSize: 15,
                color: _kText.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _showAddGoalForm,
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text('추가하기'),
              style: TextButton.styleFrom(
                foregroundColor: _kText,
                backgroundColor: _kAccent.withOpacity(0.2),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _currentTab == 0
            ? _buildRoutineCard(items[index])
            : _buildProjectCard(items[index]);
      },
    );
  }

  /// 빈 상태
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text(
              '이번 기간 목표는 딱 1~3개만.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '작고 하찮은 게 오래 가요.',
              style: TextStyle(
                fontSize: 14,
                color: _kText.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddGoalForm,
              icon: const Icon(Icons.add),
              label: const Text('목표 추가'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: _kText,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 루틴 카드
  Widget _buildRoutineCard(UserGoal goal) {
    final isCheckedToday = _todayCheck?.isChecked(goal.id) ?? false;
    final weeklyCount = _weeklyCheckCounts[goal.id] ?? 0;
    final weeklyTarget = goal.weeklyTarget;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCheckedToday ? _kSuccess.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCheckedToday
              ? _kSuccess.withOpacity(0.4)
              : _kShadow2.withOpacity(0.4),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _kShadow2.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 제목 + 배지 + 삭제
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _kText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildBadge('루틴', _kAccent),
                        const SizedBox(width: 6),
                        _buildBadge(goal.periodLabel, _kShadow2),
                        const SizedBox(width: 6),
                        Text(
                          goal.frequencyText,
                          style: TextStyle(
                            fontSize: 11,
                            color: _kText.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
          
          const SizedBox(height: 16),

          // 오늘 체크 버튼 (가장 중요)
          GestureDetector(
            onTap: () => _toggleRoutineCheck(goal),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isCheckedToday
                    ? _kSuccess.withOpacity(0.2)
                    : _kAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCheckedToday
                      ? _kSuccess.withOpacity(0.5)
                      : _kAccent.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isCheckedToday
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    color: isCheckedToday ? _kSuccess : _kText.withOpacity(0.6),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCheckedToday ? '오늘 했어요' : '오늘 하기',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isCheckedToday ? _kSuccess : _kText.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 진행률
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '이번 주',
                          style: TextStyle(
                            fontSize: 12,
                            color: _kText.withOpacity(0.6),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$weeklyCount/$weeklyTarget',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _kText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: weeklyTarget > 0 ? weeklyCount / weeklyTarget : 0,
                      backgroundColor: _kShadow2.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation(_kSuccess),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 프로젝트 카드
  Widget _buildProjectCard(UserGoal goal) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: goal.isDone ? _kSuccess.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: goal.isDone
              ? _kSuccess.withOpacity(0.4)
              : _kShadow2.withOpacity(0.4),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _kShadow2.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 제목 + 배지 + 삭제
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _kText,
                        decoration: goal.isDone
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildBadge('프로젝트', _kAccent),
                        const SizedBox(width: 6),
                        _buildBadge(goal.periodLabel, _kShadow2),
                        if (goal.isDone) ...[
                          const SizedBox(width: 6),
                          _buildBadge('완료됨', _kSuccess),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
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
          
          const SizedBox(height: 12),

          // 마감 안내
          if (!goal.isDone)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _kAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: _kText.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    goal.deadlineText,
                    style: TextStyle(
                      fontSize: 12,
                      color: _kText.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // 완료 토글
          GestureDetector(
            onTap: () => _toggleProjectDone(goal),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: goal.isDone
                    ? _kSuccess.withOpacity(0.2)
                    : _kAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: goal.isDone
                      ? _kSuccess.withOpacity(0.5)
                      : _kAccent.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    goal.isDone
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    color: goal.isDone ? _kSuccess : _kText.withOpacity(0.6),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    goal.isDone ? '완료됨' : '완료 체크',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: goal.isDone ? _kSuccess : _kText.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _kText.withOpacity(0.7),
        ),
      ),
    );
  }

  // ─── 액션 ───

  /// 루틴 체크 토글
  Future<void> _toggleRoutineCheck(UserGoal goal) async {
    await UserGoalService.toggleRoutineCheck(goal.id);
    
    // 데이터 리로드
    final todayCheck = await UserGoalService.loadTodayCheck();
    final weeklyCount = await UserGoalService.getWeeklyCheckCount(goal.id);
    
    if (mounted) {
      setState(() {
        _todayCheck = todayCheck;
        _weeklyCheckCounts[goal.id] = weeklyCount;
      });

      // 피드백 토스트
      final isChecked = todayCheck.isChecked(goal.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isChecked ? '좋아. 오늘 한 칸 채웠다.' : '체크 취소'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }

  /// 프로젝트 완료 토글
  Future<void> _toggleProjectDone(UserGoal goal) async {
    final updated = goal.copyWith(
      isDone: !goal.isDone,
      doneAt: !goal.isDone ? DateTime.now() : null,
    );
    
    await UserGoalService.updateGoal(updated);
    await _loadData();

    if (mounted && updated.isDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('완료! 이건 꽤 큰 거 했네.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 2000),
        ),
      );
    }
  }

  /// 목표 삭제
  Future<void> _deleteGoal(UserGoal goal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('목표 삭제'),
          content: const Text('삭제할까요?'),
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
      await _loadData();
    }
  }

  /// 목표 추가 폼
  void _showAddGoalForm() {
    if (!_goals!.canAdd) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('목표는 최대 3개까지예요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GoalAddForm(
          onAdded: () {
            _loadData();
            Navigator.pop(context);
          },
        ),
        fullscreenDialog: true,
      ),
    );
  }
}
