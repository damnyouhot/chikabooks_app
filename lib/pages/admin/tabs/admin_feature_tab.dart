import 'package:flutter/material.dart';
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
        AdminDashboardService.getTopFeatures(limit: 12, since: widget.since),
        AdminDashboardService.getRecentErrors(limit: 10, since: widget.since),
        AdminDashboardService.getTopErrorPages(limit: 5, since: widget.since),
      ]);
      if (!mounted) return;
      setState(() {
        _features = results[0] as List<FeatureReactionItem>;
        _errors = results[1] as List<AppErrorItem>;
        _topErrorPages = results[2] as List<MapEntry<String, int>>;
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
          // ── 기능 반응 TOP ──────────────────────────────────────
          const AdminSectionTitle('기능 반응 TOP'),
          if (_features.isEmpty)
            const AdminEmptyState(message: '아직 기록된 기능 반응이 없어요')
          else
            _FeatureList(items: _features),

          const SizedBox(height: 24),

          // ── 오류 발생 페이지 TOP ──────────────────────────────
          const AdminSectionTitle('오류 발생 페이지 TOP'),
          if (_topErrorPages.isEmpty)
            const AdminEmptyState(message: '오류 데이터가 없어요 👍')
          else
            _ErrorPageList(entries: _topErrorPages),

          const SizedBox(height: 24),

          // ── 최근 오류 리스트 ──────────────────────────────────
          const AdminSectionTitle('최근 오류 리스트'),
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

// ─── 기능 반응 리스트 ─────────────────────────────────────────
class _FeatureList extends StatelessWidget {
  final List<FeatureReactionItem> items;
  const _FeatureList({required this.items});

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
    'poll_empathize': Icons.how_to_vote_outlined,
    'poll_change_empathy': Icons.swap_horiz_outlined,
    'poll_add_option': Icons.playlist_add_outlined,
    // 성장
    'view_growth': Icons.bar_chart_outlined,
    'quiz_completed': Icons.quiz_outlined,
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
    final maxCount = items.isNotEmpty ? items.first.clickCount : 1;

    return Column(
      children: List.generate(items.length, (i) {
        final item = items[i];
        final ratio = maxCount > 0 ? item.clickCount / maxCount : 0.0;
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
                  // 순위
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.tab,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textDisabled,
                          ),
                        ),
                      ],
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
                        value: ratio,
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

