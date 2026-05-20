import 'dart:math';

import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_confirm_modal.dart';
import '../core/widgets/app_muted_card.dart';
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
  // 루틴·프로젝트 체크/진행 강조 — 앱 블루(accent) + onAccent(흰색).

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

  /// 카드 리스트 전용 스크롤 컨트롤러 — Scrollbar 와 ListView 가 같은
  /// 스크롤을 공유하도록 명시적으로 보유.
  final ScrollController _listScrollController = ScrollController();

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
    _listScrollController.dispose();
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
  /// 허브 임베드 모드에서는 시트 헤더와 세그먼트 라벨에 이미 「목표」
  /// 가 노출되므로 본문 타이틀/부제는 숨겨 중복을 줄이고, 우측 「+ 추가」 컨트롤만 살린다.
  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.embedded ? AppSpacing.xl : 24,
      ),
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
                  '루틴/프로젝트 · 오늘/주/월/연',
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

    // ── 달성률 기반 레벨 ─────────────────────────────────────
    // 분모: 활성 루틴 수에 비례한 「가능한 최대 체크」
    //   주간 = 활성 루틴 × 7
    //   월간 = 활성 루틴 × 월초~오늘 일수
    // 활성 루틴이 0 이면 분모 0 → tier 가 null 인 「루틴 추가 유도」 칩.
    final activeRoutines = routines.length;
    final today = DateTime.now();
    final daysIntoMonth = today.day; // 1..31
    final weeklyMax = activeRoutines * 7;
    final monthlyMax = activeRoutines * daysIntoMonth;
    final weeklyRate = weeklyMax > 0 ? weeklyTotal / weeklyMax : null;
    final monthlyRate = monthlyMax > 0 ? _monthlyTotal / monthlyMax : null;
    final weekly = _resolveWeeklyTier(weeklyRate);
    final monthly = _resolveMonthlyTier(monthlyRate);

    // 흰 카드 + 1px 라인 → 다른 카드들과 톤 통일.
    // 상단: 주간/월간 두 레벨 칩 / 하단: 보조 수치(오늘 체크 · 이번 주 · 이번 달).
    final summaryBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _LevelChip(
                tier: weekly,
                suffix: '주간',
                rate: weeklyRate,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _LevelChip(
                tier: monthly,
                suffix: '월간',
                rate: monthlyRate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 14,
              color: _kAccent,
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
              weeklyMax > 0 ? '$weeklyTotal/$weeklyMax' : '$weeklyTotal',
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
              monthlyMax > 0 ? '$_monthlyTotal/$monthlyMax' : '$_monthlyTotal',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
          ],
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.embedded ? AppSpacing.xl : 24,
      ),
      child: widget.embedded
          ? AppMutedCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: summaryBody,
            )
          : Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider, width: 1),
              ),
              child: summaryBody,
            ),
    );
  }

  // ── 레벨 산출 (달성률 기반, 루틴 개수에 공평) ──────────────
  // 분모(활성 루틴 × 기간일수) 가 0 이면 null 을 반환 → 칩이 「루틴 추가
  // 유도」 톤으로 바뀐다.
  static _Tier? _resolveWeeklyTier(double? rate) {
    if (rate == null) return null;
    if (rate >= 0.90) return const _Tier('빛나는 한 주', '💎');
    if (rate >= 0.70) return const _Tier('결이 잡힘', '🥇');
    if (rate >= 0.50) return const _Tier('단단해지는 중', '🥈');
    if (rate >= 0.30) return const _Tier('흐름 좋음', '🥈');
    if (rate >= 0.15) return const _Tier('페이스 잡힘', '🥉');
    if (rate > 0) return const _Tier('시작', '🥉');
    return const _Tier('시작 전', '▫️');
  }

  static _Tier? _resolveMonthlyTier(double? rate) {
    if (rate == null) return null;
    if (rate >= 0.75) return const _Tier('결이 단단해진 달', '💎');
    if (rate >= 0.50) return const _Tier('단단해지는 중', '🥇');
    if (rate >= 0.25) return const _Tier('흐름 좋음', '🥈');
    if (rate > 0) return const _Tier('페이스 잡힘', '🥉');
    return const _Tier('시작', '▫️');
  }

  /// 탭 (루틴 / 프로젝트)
  Widget _buildTabs() {
    final hubStyle = widget.embedded;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: hubStyle ? AppSpacing.xl : 24,
      ),
      child: Container(
        padding: hubStyle ? const EdgeInsets.all(4) : null,
        decoration: BoxDecoration(
          color: hubStyle
              ? AppColors.surfaceMuted
              : _kShadow2.withOpacity(0.2),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: hubStyle ? AppColors.lime : AppColors.white,
            borderRadius: BorderRadius.circular(
              hubStyle ? AppRadius.sm : 12,
            ),
            boxShadow: hubStyle
                ? null
                : [
                    BoxShadow(
                      color: _kShadow2.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor:
              hubStyle ? AppColors.onCardEmphasis : _kText,
          unselectedLabelColor: hubStyle
              ? AppColors.textSecondary
              : _kText.withOpacity(0.5),
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
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

    // 항목이 많아져 스크롤이 필요할 때 사용자에게 「더 있다」를 알리도록
    // Scrollbar 를 항상 노출(thumbVisibility: true). 컨트롤러를 공유해
    // ListView 가 사용하는 동일 스크롤에 붙는다.
    final controller = _listScrollController;
    return Scrollbar(
      controller: controller,
      thumbVisibility: true,
      thickness: 3,
      radius: const Radius.circular(2),
      child: ListView.separated(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
          widget.embedded ? AppSpacing.xl : 24,
          0,
          widget.embedded ? AppSpacing.xl : 24,
          8,
        ),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return _currentTab == 0
              ? _buildRoutineCard(items[index])
              : _buildProjectCard(items[index]);
        },
      ),
    );
  }

  /// 빈 상태
  Widget _buildEmptyState() {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🎯', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 16),
        const Text(
          '챙기고 싶은 목표를 자유롭게 적어보세요.',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
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
    );

    return Center(
      child: Padding(
        padding: EdgeInsets.all(widget.embedded ? AppSpacing.xl : 32),
        child: widget.embedded
            ? AppMutedCard(
                padding: const EdgeInsets.symmetric(
                    vertical: 28, horizontal: 20),
                child: body,
              )
            : body,
      ),
    );
  }

  /// 루틴 카드
  Widget _buildRoutineCard(UserGoal goal) {
    final isCheckedToday = _todayCheck?.isChecked(goal.id) ?? false;
    final weeklyCount = _weeklyCheckCounts[goal.id] ?? 0;
    final weeklyTarget = goal.weeklyTarget;

    // ── 60% 더 압축한 1행 레이아웃 ───────────────────────────
    // [원형 체크] [ 제목/배지·빈도 / 진행바 ]   [N/M]   [🗑]
    // 카드 한 장 높이가 약 60px 수준. 체크 시 앱 블루 솔리드 원형 버튼.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCheckedToday ? _kAccent.withOpacity(0.07) : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCheckedToday
              ? _kAccent.withOpacity(0.35)
              : _kShadow2.withOpacity(0.4),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _kShadow2.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ① 원형 체크 토글 (가장 핵심 액션)
          GestureDetector(
            onTap: () => _toggleRoutineCheck(goal),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isCheckedToday ? _kAccent : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCheckedToday
                      ? _kAccent
                      : _kAccent.withOpacity(0.45),
                  width: 1.4,
                ),
              ),
              child: Icon(
                isCheckedToday ? Icons.check : Icons.check,
                size: 18,
                color: isCheckedToday
                    ? AppColors.onAccent
                    : _kText.withOpacity(0.25),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // ② 제목 + 배지/빈도 + 진행 바
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        goal.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isCheckedToday
                              ? FontWeight.w800
                              : FontWeight.w700,
                          color: _kText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildBadge('루틴', _kAccent),
                    const SizedBox(width: 4),
                    _buildBadge(goal.periodLabel, _kShadow2),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        goal.frequencyText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isCheckedToday
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isCheckedToday
                              ? _kAccent.withOpacity(0.9)
                              : _kText.withOpacity(0.45),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: weeklyTarget > 0 ? weeklyCount / weeklyTarget : 0,
                    backgroundColor: _kShadow2.withOpacity(0.25),
                    valueColor: AlwaysStoppedAnimation(_kAccent),
                    minHeight: 3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ③ 분수(N/M) + 삭제 — 컴팩트하게 세로 정렬
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$weeklyCount/$weeklyTarget',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isCheckedToday
                      ? _kAccent
                      : _kText.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: () => _deleteGoal(goal),
                child: Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: _kText.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 마감 D-N 색 단계: 7일 초과=중성/3일 이내=주황/1일 이내·과거=빨강.
  Color _deadlineColor(int? days) {
    if (days == null) return _kShadow2;
    if (days <= 1) return const Color(0xFFE05757); // 빨강
    if (days <= 3) return const Color(0xFFE0833E); // 주황
    return const Color(0xFF4A8AB6); // 차분한 블루
  }

  /// 프로젝트 카드 — 1행 헤더 + (체크포인트/오늘 터치 확장 영역).
  Widget _buildProjectCard(UserGoal goal) {
    final dDay = goal.dDayLabel;
    final days = goal.daysUntilDeadline;
    final dColor = _deadlineColor(days);
    final progress = goal.checkpointProgress;
    final hasCheckpoints = goal.checkpoints.isNotEmpty;
    final showTouchRow = !goal.isDone;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: goal.isDone ? _kAccent.withOpacity(0.07) : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: goal.isDone
              ? _kAccent.withOpacity(0.35)
              : _kShadow2.withOpacity(0.4),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _kShadow2.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 헤더 행: 완료 토글 + 제목/배지/마감 + 삭제 ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _toggleProjectDone(goal),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: goal.isDone ? _kAccent : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: goal.isDone
                          ? _kAccent
                          : _kAccent.withOpacity(0.45),
                      width: 1.4,
                    ),
                  ),
                  child: Icon(
                    Icons.check,
                    size: 18,
                    color: goal.isDone
                        ? AppColors.onAccent
                        : _kText.withOpacity(0.25),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            goal.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _kText,
                              decoration: goal.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildBadge('프로젝트', _kAccent),
                        if (goal.isDone) ...[
                          const SizedBox(width: 4),
                          _buildBadge('완료', _kAccent),
                        ],
                      ],
                    ),
                    if (!goal.isDone) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (dDay != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: dColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                dDay,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: dColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              goal.deadlineText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _kText.withOpacity(0.78),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _deleteGoal(goal),
                child: Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: _kText.withOpacity(0.3),
                ),
              ),
            ],
          ),

          // ── 체크포인트 진행 영역 ──
          if (hasCheckpoints && !goal.isDone) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress ?? 0,
                      minHeight: 4,
                      backgroundColor: _kShadow2.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation(_kAccent),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${goal.checkpoints.where((c) => c.done).length}/${goal.checkpoints.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _kText.withOpacity(0.85),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 체크포인트 칩 — 단계 토글
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final cp in goal.checkpoints)
                  GestureDetector(
                    onTap: () => _toggleCheckpoint(goal, cp),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cp.done
                            ? _kAccent.withOpacity(0.15)
                            : AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cp.done
                              ? _kAccent.withOpacity(0.45)
                              : _kShadow2.withOpacity(0.4),
                          width: 0.6,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cp.done
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 14,
                            color: cp.done
                                ? AppColors.onAccent
                                : _kText.withOpacity(0.5),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            cp.title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cp.done
                                  ? AppColors.onAccent
                                  : _kText.withOpacity(0.9),
                              decoration: cp.done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],

          // ── 오늘 5분 했어요 (데일리 터치) ──
          if (showTouchRow) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _toggleDailyTouch(goal),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: goal.touchedToday
                      ? _kAccent.withOpacity(0.14)
                      : _kAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: goal.touchedToday
                        ? _kAccent.withOpacity(0.5)
                        : _kAccent.withOpacity(0.35),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      goal.touchedToday
                          ? Icons.bolt
                          : Icons.bolt_outlined,
                      size: 16,
                      color: goal.touchedToday
                          ? AppColors.onAccent
                          : _kText.withOpacity(0.75),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      goal.touchedToday
                          ? '오늘 5분 했어요'
                          : '오늘 5분이라도 했나요?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: goal.touchedToday
                            ? AppColors.onAccent
                            : _kText.withOpacity(0.88),
                      ),
                    ),
                    const Spacer(),
                    if (goal.dailyTouchDates.isNotEmpty)
                      Text(
                        '🔥 ${goal.dailyTouchDates.length}일',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _kText.withOpacity(0.75),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _toggleCheckpoint(UserGoal goal, GoalCheckpoint cp) async {
    final ok = await UserGoalService.toggleCheckpoint(goal.id, cp.id);
    if (ok) {
      AdminActivityService.log(
        ActivityEventType.goalCheckpointToggle,
        page: 'record_hub',
        targetId: goal.id,
        extra: {'checkpointId': cp.id, 'doneAfter': !cp.done},
      );
      if (mounted) _loadData();
    }
  }

  Future<void> _toggleDailyTouch(UserGoal goal) async {
    final ok = await UserGoalService.toggleDailyTouch(goal.id);
    if (ok) {
      AdminActivityService.log(
        ActivityEventType.goalDailyTouch,
        page: 'record_hub',
        targetId: goal.id,
      );
      if (mounted) _loadData();
    }
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
      }
      AdminActivityService.log(
        isChecked
            ? ActivityEventType.goalRoutineCheck
            : ActivityEventType.goalRoutineUncheck,
        page: 'record_hub',
        targetId: goal.id,
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
      _emitCharacterMent(CaringMents.goalCompleted);
    }
    AdminActivityService.log(
      updated.isDone
          ? ActivityEventType.goalProjectDone
          : ActivityEventType.goalProjectUndone,
      page: 'record_hub',
      targetId: goal.id,
    );
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
        extra: {'goalType': goal.type.name},
      );
      await _loadData();
    }
  }

  /// 목표 추가 폼 — 상한 없음.
  void _showAddGoalForm() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => GoalAddForm(
              onAdded: (createdGoal) {
                _loadData();
                _emitCharacterMent(CaringMents.goalCreated);
                AdminActivityService.log(
                  ActivityEventType.goalCreate,
                  page: 'record_hub',
                  targetId: createdGoal?.id,
                  extra: {
                    'goalType': createdGoal?.type.name ?? 'unknown',
                    if (createdGoal != null)
                      'periodType': createdGoal.periodType.name,
                    if (createdGoal != null &&
                        createdGoal.checkpoints.isNotEmpty)
                      'checkpointCount': createdGoal.checkpoints.length,
                  },
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

/// 요약 카드 상단의 레벨 칩 — 메달 + 칭호 + 우측의 작은 「주간/월간 N%」 라벨.
///
/// [tier] 가 null 이면 「루틴 추가 유도」 톤으로 자동 전환.
class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.tier,
    required this.suffix,
    required this.rate,
  });

  final _Tier? tier;
  final String suffix;
  final double? rate;

  @override
  Widget build(BuildContext context) {
    final t = tier;
    if (t == null) {
      // 활성 루틴이 0개 → 분모가 없어 의미 있는 레벨이 안 나옴.
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Text('▫️', style: TextStyle(fontSize: 16)),
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
                  const Text(
                    '루틴을 추가해 보세요',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final pct = rate == null ? null : (rate! * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(t.medal, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      suffix,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary.withOpacity(0.5),
                      ),
                    ),
                    if (pct != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '· $pct%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  t.title,
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
