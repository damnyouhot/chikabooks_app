import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/web_site_footer.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/feedback_post.dart';
import '../../services/feedback_service.dart';
import '../../services/user_profile_service.dart';
import 'feedback_detail_page.dart';
import 'feedback_write_page.dart';
import 'widgets/feedback_card.dart';

/// 피드백 목록 페이지
class FeedbackListPage extends StatefulWidget {
  /// FAB에서 전달받은 현재 화면 정보 (작성 시 자동 채움)
  final String sourceScreenLabel;
  final String sourceRoute;

  const FeedbackListPage({
    super.key,
    this.sourceScreenLabel = '',
    this.sourceRoute = '/feedback',
  });

  @override
  State<FeedbackListPage> createState() => _FeedbackListPageState();
}

class _FeedbackListPageState extends State<FeedbackListPage> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final admin = await UserProfileService.isAdmin();
    if (mounted) setState(() => _isAdmin = admin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          '피드백 게시판',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FeedbackWritePage(
                  sourceScreenLabel: widget.sourceScreenLabel.isNotEmpty
                      ? widget.sourceScreenLabel
                      : '피드백 게시판',
                  sourceRoute: widget.sourceRoute.isNotEmpty
                      ? widget.sourceRoute
                      : '/feedback',
                ),
              ),
            ),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('작성'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<FeedbackPost>>(
        stream: FeedbackService.watchList(isAdmin: _isAdmin),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                '불러오기 실패: ${snap.error}',
                style: const TextStyle(color: AppColors.error),
              ),
            );
          }

          final posts = snap.data ?? [];

          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.feedback_outlined,
                      size: 48, color: AppColors.textDisabled),
                  const SizedBox(height: 12),
                  const Text(
                    '아직 피드백이 없어요',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '첫 번째 피드백을 남겨보세요',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textDisabled,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FeedbackWritePage(
                          sourceScreenLabel: widget.sourceScreenLabel.isNotEmpty
                              ? widget.sourceScreenLabel
                              : '피드백 게시판',
                          sourceRoute: widget.sourceRoute.isNotEmpty
                              ? widget.sourceRoute
                              : '/feedback',
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('피드백 작성하기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.onAccent,
                    ),
                  ),
                ],
              ),
            );
          }

          // 관리자 탭 분류 (관리자면 상단에 통계 표시)
          return CustomScrollView(
            slivers: [
              if (_isAdmin)
                SliverToBoxAdapter(
                  child: _AdminSummaryBar(posts: posts),
                ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => FeedbackCard(
                    post: posts[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            FeedbackDetailPage(feedbackId: posts[i].id),
                      ),
                    ),
                  ),
                  childCount: posts.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
      bottomNavigationBar:
          kIsWeb ? const WebSiteFooter(backgroundColor: AppColors.white) : null,
    );
  }
}

/// 관리자 전용 요약 바
class _AdminSummaryBar extends StatelessWidget {
  final List<FeedbackPost> posts;
  const _AdminSummaryBar({required this.posts});

  @override
  Widget build(BuildContext context) {
    final pending =
        posts.where((p) => p.adminStatus == FeedbackAdminStatus.pending).length;
    final private =
        posts.where((p) => p.visibility == FeedbackVisibility.private).length;
    final total = posts.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          _StatItem(label: '전체', value: '$total'),
          _Vdiv(),
          _StatItem(
            label: '미처리',
            value: '$pending',
            highlight: pending > 0,
          ),
          _Vdiv(),
          _StatItem(label: '비공개', value: '$private'),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _StatItem({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: highlight
                  ? AppColors.cardEmphasis
                  : AppColors.onCardPrimary,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.onCardPrimary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _Vdiv extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 32,
        width: 1,
        color: AppColors.onCardPrimary.withOpacity(0.2),
      );
}
