import 'package:flutter/material.dart';
import '../../../core/analytics/event_catalog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/admin_dashboard_models.dart';
import '../../../services/admin_dashboard_service.dart';
import '../widgets/admin_common_widgets.dart';

class AdminFeatureTab extends StatefulWidget {
  final DateTime since;
  const AdminFeatureTab({super.key, required this.since});

  @override
  State<AdminFeatureTab> createState() => _AdminFeatureTabState();
}

class _AdminFeatureTabState extends State<AdminFeatureTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => false;

  bool _loading = true;
  String? _error;

  List<FeatureReactionItem> _features = [];
  List<AppErrorItem> _errors = [];
  List<MapEntry<String, int>> _topErrorPages = [];

  // 각 섹션의 표본 한계 메타 — limit 에 닿으면 배너 노출
  SampleMeta _featuresSample = SampleMeta.empty;
  SampleMeta _errorsSample = SampleMeta.empty;
  SampleMeta _errorPagesSample = SampleMeta.empty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AdminFeatureTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.since != widget.since) _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        // 탭별 섹션에 나눠 담기 위해 타입 수를 넉넉히 (전역 TOP N)
        AdminDashboardService.getTopFeaturesWithMeta(
          limit: 36,
          since: widget.since,
        ),
        AdminDashboardService.getRecentErrorsWithMeta(
          limit: 10,
          since: widget.since,
        ),
        AdminDashboardService.getTopErrorPagesWithMeta(
          limit: 5,
          since: widget.since,
        ),
      ]);
      if (!mounted) return;
      final featRes = results[0] as FeatureReactionResult;
      final errRes = results[1] as RecentErrorsResult;
      final pageRes = results[2] as TopErrorPagesResult;
      setState(() {
        _features = featRes.items;
        _featuresSample = featRes.sample;
        _errors = errRes.items;
        _errorsSample = errRes.sample;
        _topErrorPages = pageRes.entries;
        _errorPagesSample = pageRes.sample;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const AdminLoadingState();
    if (_error != null) return AdminErrorState(onRetry: _load);

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 기능 반응 TOP (탭별) ───────────────────────────────
          const AdminSectionTitle('기능 반응 TOP'),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              '탭(앱 하단 메뉴 그룹)별로 묶어 표시합니다.\n'
              '같이: 공감·공감 변경은 「공감투표 참여」로 합산, 보기 추가는 「투표 보기 추가」로 표시합니다.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textDisabled,
              ),
            ),
          ),
          AdminSampleNotice(
            sampleSize: _featuresSample.sampleSize,
            limit: _featuresSample.limit,
          ),
          if (_features.isEmpty)
            const AdminEmptyState(message: '아직 기록된 기능 반응이 없어요')
          else
            _FeatureListByTab(items: _features),

          const SizedBox(height: 24),

          // ── 오류 발생 페이지 TOP ──────────────────────────────
          const AdminSectionTitle('오류 발생 페이지 TOP'),
          AdminSampleNotice(
            sampleSize: _errorPagesSample.sampleSize,
            limit: _errorPagesSample.limit,
          ),
          if (_topErrorPages.isEmpty)
            const AdminEmptyState(message: '오류 데이터가 없어요 👍')
          else
            _ErrorPageList(entries: _topErrorPages),

          const SizedBox(height: 24),

          // ── 최근 오류 리스트 ──────────────────────────────────
          const AdminSectionTitle('최근 오류 리스트'),
          AdminSampleNotice(
            sampleSize: _errorsSample.sampleSize,
            limit: _errorsSample.limit,
          ),
          if (_errors.isEmpty)
            const AdminEmptyState(message: '최근 오류가 없어요 👍')
          else
            ..._errors.map((e) => AdminErrorTile(
                  message: e.errorMessage,
                  timestamp: e.timestamp,
                  page: e.page,
                  feature: e.feature,
                  isFatal: e.isFatal,
                  appVersion: e.appVersion,
                )),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── 탭 순서 (EventTab과 동일) ─────────────────────────────────
int _featureTabSortOrder(String tab) {
  const order = <String>[
    EventTab.na,
    EventTab.bond,
    EventTab.growth,
    EventTab.career,
    EventTab.job,
    EventTab.auth,
    EventTab.publisher,
    EventTab.other,
  ];
  final i = order.indexOf(tab);
  return i >= 0 ? i : 999;
}

// ─── 기능 반응: 탭별 섹션 ─────────────────────────────────────
class _FeatureListByTab extends StatelessWidget {
  final List<FeatureReactionItem> items;
  const _FeatureListByTab({required this.items});

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<FeatureReactionItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.tab, () => []).add(item);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => b.clickCount.compareTo(a.clickCount));
    }
    final tabKeys = grouped.keys.toList()
      ..sort((a, b) {
        final cmp = _featureTabSortOrder(a).compareTo(_featureTabSortOrder(b));
        return cmp != 0 ? cmp : a.compareTo(b);
      });

    final globalMax =
        items.isEmpty ? 1 : items.map((e) => e.clickCount).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var t = 0; t < tabKeys.length; t++) ...[
          if (t > 0) const SizedBox(height: 16),
          _TabSubheading(
            title: tabKeys[t],
            count: grouped[tabKeys[t]]!.length,
          ),
          const SizedBox(height: 8),
          _FeatureRows(
            items: grouped[tabKeys[t]]!,
            globalMaxCount: globalMax,
          ),
        ],
      ],
    );
  }
}

class _TabSubheading extends StatelessWidget {
  final String title;
  final int count;

  const _TabSubheading({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count개 이벤트',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textDisabled,
          ),
        ),
      ],
    );
  }
}

// ─── 기능 반응 행 (한 탭 안) ────────────────────────────────────
class _FeatureRows extends StatelessWidget {
  final List<FeatureReactionItem> items;
  final int globalMaxCount;

  const _FeatureRows({
    required this.items,
    required this.globalMaxCount,
  });

  static const _icons = <String, IconData>{
    // 나
    'tap_character': Icons.emoji_nature_outlined,
    'caring_feed_success': Icons.restaurant_outlined,
    'tap_emotion_start': Icons.edit_note_outlined,
    'tap_emotion_save': Icons.save_outlined,
    'emotion_save_success': Icons.check_circle_outline,
    'emotion_save_fail': Icons.error_outline,
    'view_emotion_record': Icons.mood_outlined,
    // 같이
    'view_bond': Icons.favorite_outline,
    'view_whisper': Icons.forum_outlined,
    'poll_empathize': Icons.how_to_vote_outlined,
    'poll_change_empathy': Icons.swap_horiz_outlined,
    'poll_add_option': Icons.playlist_add_outlined,
    'whisper_create_complete': Icons.rate_review_outlined,
    'whisper_reaction': Icons.favorite_border,
    'whisper_comment': Icons.mode_comment_outlined,
    'whisper_reply': Icons.reply_outlined,
    'whisper_share': Icons.share_outlined,
    FeatureReactionAggregates.bondPollVote: Icons.how_to_vote_outlined,
    FeatureReactionAggregates.bondPollAdd: Icons.playlist_add_outlined,
    // 성장
    'view_growth': Icons.bar_chart_outlined,
    'view_today_words': Icons.abc_outlined,
    'quiz_completed': Icons.quiz_outlined,
    'daily_word_known': Icons.check_circle_outline,
    'daily_word_review_later': Icons.replay_outlined,
    'daily_word_saved': Icons.bookmark_outline,
    'daily_word_unsaved': Icons.bookmark_remove_outlined,
    // 커리어·구직
    'view_career': Icons.work_history_outlined,
    'view_job': Icons.list_alt_outlined,
    'view_job_detail': Icons.work_outline,
    'tap_job_save': Icons.bookmark_outline,
    'tap_job_apply': Icons.send_outlined,
    'tap_career_edit': Icons.badge_outlined,
    // 홈·기타
    'view_home': Icons.home_outlined,
    'view_settings': Icons.settings_outlined,
    'login_success': Icons.login_outlined,
    'view_sign_in_page': Icons.lock_open_outlined,
    'tap_login_google': Icons.g_mobiledata,
    'tap_login_kakao': Icons.chat_bubble_outline,
    'tap_login_apple': Icons.apple,
    'tap_login_email': Icons.email_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final maxCount = globalMaxCount > 0 ? globalMaxCount : 1;

    return Column(
      children: List.generate(items.length, (i) {
        final item = items[i];
        final ratio = item.clickCount / maxCount;
        final icon = _icons[item.eventType] ?? Icons.touch_app_outlined;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(icon, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${item.clickCount}회',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const SizedBox(width: 26),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: AppColors.disabledBg,
                        valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${item.userCount}명',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ─── 오류 발생 페이지 리스트 ──────────────────────────────────
class _ErrorPageList extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  const _ErrorPageList({required this.entries});

  @override
  Widget build(BuildContext context) {
    final maxCount = entries.isNotEmpty ? entries.first.value : 1;

    return Column(
      children: entries.map((e) {
        final ratio = maxCount > 0 ? e.value / maxCount : 0.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_outlined,
                  size: 14, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.key,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: AppColors.disabledBg,
                        valueColor: const AlwaysStoppedAnimation(AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${e.value}건',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

