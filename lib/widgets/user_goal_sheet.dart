import 'dart:math';

import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_confirm_modal.dart';
import '../core/widgets/app_modal_scaffold.dart';
import '../data/caring_ments.dart';
import '../models/user_goal.dart';
import '../models/routine_check.dart';
import '../services/admin_activity_service.dart';
import '../services/user_goal_service.dart';
import 'goal_add_form.dart';

/// 사용자 목표 허브 (완성형)
///
/// 내부 콘텐츠는 [UserGoalContent]로 분리되어 [RecordHubSheet] 등 다른 시트에
/// 재사용 가능하다. 단독 호출은 기존과 동일하게 [show]를 사용한다.
class UserGoalSheet {
  static Future<void> show(BuildContext context) {
    return showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const UserGoalContent(),
    );
  }
}

/// 「나의 목표」 콘텐츠 본체 (시트 껍데기 없이 어디서든 재사용 가능)
///
/// - [embedded] true: 외부 시트 안에 임베드되는 경우. 자체 라운드 카드/드래그 핸들/
///   외부 패딩을 그리지 않고, 콘텐츠만 출력한다. ([RecordHubSheet]에서 사용)
/// - [embedded] false: 단독 시트로 쓰일 때. 기존과 동일한 외형(흰색 카드 + 핸들).
/// - [onCharacterMent]: 사용자의 액션(체크/완료/생성/재시작 등)에 대한 캐릭터
///   멘트 후보를 부모에 알리는 콜백. [RecordHubSheet]가 시트 종료 시 캐릭터
///   말풍선으로 흘려보낸다. null이면 기존 토스트만 사용.
class UserGoalContent extends StatefulWidget {
  const UserGoalContent({
    super.key,
    this.embedded = false,
    this.onCharacterMent,
  });

  final bool embedded;
  final ValueChanged<String>? onCharacterMent;

  @override
  State<UserGoalContent> createState() => _UserGoalContentState();
}

class _UserGoalContentState extends State<UserGoalContent>
    with SingleTickerProviderStateMixin {
  // ── 디자인 컬러 팔레트 → AppColors로 교체 ──
  static const _kAccent = AppColors.accent;
  static const _kText = AppColors.textPrimary;
  static const _kShadow2 = AppColors.divider;
  // 목표 시트 전용 그린 — 흰 배경 위에서 텍스트 가독성을 위해 더 진한 톤.
  // 전역 [AppColors.success] 는 형광 톤이라 큰 면적에서 글자 콘트라스트가 낮음.
  static const _kSuccess = Color(0xFF1F8A4C);
  static const _kSuccessOn = Color(0xFFFFFFFF); // 솔리드 버튼 위 텍스트(흰색)

  UserGoals? _goals;
  RoutineCheck? _todayCheck;
  bool _loading = true;

  // 탭 컨트롤러
  late TabController _tabController;
  int _currentTab = 0; // 0: 루틴, 1: 프로젝트

  // 주간 체크 횟수 캐시 (goalId -> count)
  final Map<String, int> _weeklyCheckCounts = {};

  /// 이번 달(월초~오늘) 모든 루틴 체크 누적 합계.
  /// 시트 진입 시 1회 로드. 빠른 진단을 위해 초기값 0.
  int _monthlyTotal = 0;

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

    // 월간 누적 합계 (모든 루틴 통합) 1회 로드.
    final monthly = await UserGoalService.getMonthlyTotalChecks();

    if (mounted) {
      setState(() {
        _goals = goals;
        _todayCheck = todayCheck;
        _monthlyTotal = monthly;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasItems =
        !_loading && _goals != null && _goals!.items.isNotEmpty;
    final inner = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.embedded) ...[
          // 드래그 핸들 (단독 시트일 때만)
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
        ],

        // 헤더
        _buildHeader(),
        const SizedBox(height: 8),

        // 상태 요약
        if (hasItems) _buildSummary(),
        if (hasItems) const SizedBox(height: 16),

        // 탭
        if (hasItems) _buildTabs(),
        if (hasItems) const SizedBox(height: 16),

        // 내용
        Flexible(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildContent(),
        ),

        const SizedBox(height: 20),
      ],
    );

    if (widget.embedded) {
      // 시트 외형(라운드 카드/배경)은 바깥 [RecordHubSheet] 가 책임진다.
      return inner;
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: inner,
    );
  }

  /// 헤더 (제목 + 추가 버튼)
  ///
  /// 허브 임베드 모드에서는 시트 헤더와 세그먼트 라벨에 이미 「목표, 리마인드」
  /// 가 노출되므로 본문 타이틀/부제는 숨겨 중복을 줄이고, 우측 「+ 추가」 컨트롤만 살린다.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          if (!widget.embedded)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '목표, 기억할 것',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _kText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '최대 3개 · 루틴/프로젝트 · 오늘/주/월/연',
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
                  // 「기록하기」 흐름의 강조색 — 1탭 버튼/시트 헤더 점과 동일.
                  color: AppColors.lime,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      size: 18,
                      color: AppColors.onCardEmphasis,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '추가',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onCardEmphasis,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_goals != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _kShadow2.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '3/3',
                style: TextStyle(fontSize: 12, color: _kText.withOpacity(0.5)),
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

    // 주간 7단계 (담담한 진척 톤)
    final weekly = _resolveWeeklyTier(weeklyTotal);
    // 월간 5단계 (월초~오늘 누적)
    final monthly = _resolveMonthlyTier(_monthlyTotal);

    // 흰 카드 + 1px 라인 → 다른 카드들과 톤 통일.
    // 상단: 주간/월간 두 레벨 칩 / 하단: 보조 수치(오늘 체크 · 이번 주 · 이번 달).
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 상단: 주간 레벨 칩 + 월간 레벨 칩 ──
            Row(
              children: [
                Expanded(
                  child: _LevelChip(
                    medal: weekly.medal,
                    title: weekly.title,
                    suffix: '주간',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LevelChip(
                    medal: monthly.medal,
                    title: monthly.title,
                    suffix: '월간',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // ── 하단: 보조 수치(오늘 체크 · 이번 주 · 이번 달) ──
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 14,
                  color: _kSuccess,
                ),
                const SizedBox(width: 4),
                Text(
                  '오늘',
                  style: TextStyle(
                    fontSize: 12,
                    color: _kText.withOpacity(0.55),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '$todayChecked/${routines.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 1,
                  height: 10,
                  color: _kShadow2.withOpacity(0.6),
                ),
                const SizedBox(width: 12),
                Text(
                  '이번 주',
                  style: TextStyle(
                    fontSize: 12,
                    color: _kText.withOpacity(0.55),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '$weeklyTotal회',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 1,
                  height: 10,
                  color: _kShadow2.withOpacity(0.6),
                ),
                const SizedBox(width: 12),
                Text(
                  '이번 달',
                  style: TextStyle(
                    fontSize: 12,
                    color: _kText.withOpacity(0.55),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '$_monthlyTotal회',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 레벨 산출 (주간 7단계 / 월간 5단계) ──────────────────────
  // 임계치는 「루틴 최대 3개 × 7일 = 21회/주」 분포에 맞춰 7단계로 잘게,
  // 월간은 4주 누적 추세를 5단계로 담담하게.
  static _Tier _resolveWeeklyTier(int total) {
    if (total >= 18) return const _Tier('빛나는 한 주', '💎');
    if (total >= 14) return const _Tier('결이 잡힘', '🥇');
    if (total >= 10) return const _Tier('단단해지는 중', '🥈');
    if (total >= 6) return const _Tier('흐름 좋음', '🥈');
    if (total >= 3) return const _Tier('페이스 잡힘', '🥉');
    if (total >= 1) return const _Tier('시작', '🥉');
    return const _Tier('시작 전', '▫️');
  }

  static _Tier _resolveMonthlyTier(int total) {
    if (total >= 26) return const _Tier('결이 단단해진 달', '💎');
    if (total >= 18) return const _Tier('단단해지는 중', '🥇');
    if (total >= 10) return const _Tier('흐름 좋음', '🥈');
    if (total >= 4) return const _Tier('페이스 잡힘', '🥉');
    return const _Tier('시작', '▫️');
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
            color: AppColors.white,
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
              style: TextStyle(fontSize: 15, color: _kText.withOpacity(0.5)),
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
              style: TextStyle(fontSize: 14, color: _kText.withOpacity(0.6)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddGoalForm,
              icon: const Icon(Icons.add),
              label: const Text('목표 추가'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lime,
                foregroundColor: AppColors.onCardEmphasis,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
        color: isCheckedToday ? _kSuccess.withOpacity(0.1) : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isCheckedToday
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
          // 체크된 상태는 「확정된 성과」를 바로 인식할 수 있도록 솔리드 톤
          // (진한 초록 배경 + 흰 텍스트) — 큰 면적의 옅은 그린은 가독성↓.
          GestureDetector(
            onTap: () => _toggleRoutineCheck(goal),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isCheckedToday ? _kSuccess : AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCheckedToday
                      ? _kSuccess
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
                    color: isCheckedToday
                        ? _kSuccessOn
                        : _kText.withOpacity(0.6),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCheckedToday ? '오늘 했어요' : '오늘 하기',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isCheckedToday
                          ? _kSuccessOn
                          : _kText.withOpacity(0.7),
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
        color: goal.isDone ? _kSuccess.withOpacity(0.1) : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              goal.isDone
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
                        decoration:
                            goal.isDone ? TextDecoration.lineThrough : null,
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

          // 완료 토글 — 「오늘 했어요」와 동일하게 솔리드 그린 패턴.
          GestureDetector(
            onTap: () => _toggleProjectDone(goal),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: goal.isDone ? _kSuccess : AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: goal.isDone
                      ? _kSuccess
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
                    color: goal.isDone
                        ? _kSuccessOn
                        : _kText.withOpacity(0.6),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    goal.isDone ? '완료됨' : '완료 체크',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: goal.isDone
                          ? _kSuccessOn
                          : _kText.withOpacity(0.7),
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

  /// 캐릭터 멘트 풀에서 1줄 무작위 선택 후 콜백 호출 (선택)
  void _emitCharacterMent(List<String> pool) {
    final cb = widget.onCharacterMent;
    if (cb == null || pool.isEmpty) return;
    cb(pool[Random().nextInt(pool.length)]);
  }

  /// 루틴 체크 토글
  Future<void> _toggleRoutineCheck(UserGoal goal) async {
    await UserGoalService.toggleRoutineCheck(goal.id);

    // 데이터 리로드 (오늘 체크 + 해당 루틴 주간 카운트 + 월간 누적)
    final todayCheck = await UserGoalService.loadTodayCheck();
    final weeklyCount = await UserGoalService.getWeeklyCheckCount(goal.id);
    final monthly = await UserGoalService.getMonthlyTotalChecks();

    if (mounted) {
      setState(() {
        _todayCheck = todayCheck;
        _weeklyCheckCounts[goal.id] = weeklyCount;
        _monthlyTotal = monthly;
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

      // 캐릭터 멘트 (체크 ON일 때만)
      if (isChecked) {
        _emitCharacterMent(CaringMents.goalChecked);
        AdminActivityService.log(
          ActivityEventType.goalRoutineCheck,
          page: 'record_hub',
          targetId: goal.id,
        );
      }
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
      _emitCharacterMent(CaringMents.goalCompleted);
      AdminActivityService.log(
        ActivityEventType.goalProjectDone,
        page: 'record_hub',
        targetId: goal.id,
      );
    }
  }

  /// 목표 삭제
  Future<void> _deleteGoal(UserGoal goal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => const AppConfirmModal(
            title: '목표 삭제',
            message: '삭제할까요?',
            confirmLabel: '삭제',
            destructive: true,
          ),
    );

    if (confirm == true) {
      await UserGoalService.deleteGoal(goal.id);
      AdminActivityService.log(
        ActivityEventType.goalDelete,
        page: 'record_hub',
        targetId: goal.id,
      );
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
        builder:
            (_) => GoalAddForm(
              onAdded: () {
                _loadData();
                _emitCharacterMent(CaringMents.goalCreated);
                AdminActivityService.log(
                  ActivityEventType.goalCreate,
                  page: 'record_hub',
                );
                Navigator.pop(context);
              },
            ),
        fullscreenDialog: true,
      ),
    );
  }
}

/// 주간/월간 레벨 산출 결과 — 칭호와 메달 이모지를 함께 묶는다.
class _Tier {
  const _Tier(this.title, this.medal);
  final String title;
  final String medal;
}

/// 요약 카드 상단의 레벨 칩 — 메달 + 칭호 + 우측의 작은 「주간/월간」 라벨.
class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.medal,
    required this.title,
    required this.suffix,
  });

  final String medal;
  final String title;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(medal, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  suffix,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
