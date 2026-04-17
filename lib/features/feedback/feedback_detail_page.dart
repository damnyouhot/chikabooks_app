import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/web_site_footer.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/feedback_post.dart';
import '../../services/feedback_service.dart';
import '../../services/user_profile_service.dart';

/// 피드백 상세 + 댓글 페이지
class FeedbackDetailPage extends StatefulWidget {
  final String feedbackId;

  const FeedbackDetailPage({super.key, required this.feedbackId});

  @override
  State<FeedbackDetailPage> createState() => _FeedbackDetailPageState();
}

class _FeedbackDetailPageState extends State<FeedbackDetailPage> {
  static const _prefKey = 'feedback_display_name';

  final _commentCtrl = TextEditingController();
  final _namePrefCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _submittingComment = false;
  bool _isAdmin = false;
  String? _myUid;

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid;
    _checkAdmin();
    _loadNamePref();
  }

  Future<void> _checkAdmin() async {
    final admin = await UserProfileService.isAdmin();
    if (mounted) setState(() => _isAdmin = admin);
  }

  Future<void> _loadNamePref() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey) ?? '';
    if (saved.isNotEmpty && mounted) {
      setState(() => _namePrefCtrl.text = saved);
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _namePrefCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    if (_submittingComment) return;

    // 식별명 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _namePrefCtrl.text.trim());

    setState(() => _submittingComment = true);

    final ok = await FeedbackService.addComment(
      feedbackId: widget.feedbackId,
      text: text,
      displayName: _namePrefCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _submittingComment = false);

    if (ok) {
      _commentCtrl.clear();
      // 댓글 목록 하단으로 스크롤
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _updateAdminStatus(
      FeedbackPost post, FeedbackAdminStatus status) async {
    await FeedbackService.updateAdminStatus(post.id, status);
  }

  bool _canEdit(FeedbackPost post) =>
      _isAdmin || post.uid == _myUid;

  void _showEditDialog(FeedbackPost post) {
    final textCtrl = TextEditingController(text: post.text);
    var type = post.type;
    var priority = post.priority;
    var visibility = post.visibility;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('피드백 수정',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 유형
                  const Text('유형',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: FeedbackType.values.map((t) {
                      final sel = type == t;
                      return GestureDetector(
                        onTap: () => setS(() => type = t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.accent
                                : AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(t.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: sel
                                    ? AppColors.onAccent
                                    : AppColors.textSecondary,
                              )),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  // 중요도
                  const Text('중요도',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: FeedbackPriority.values.map((p) {
                      final sel = priority == p;
                      final color = switch (p) {
                        FeedbackPriority.high => AppColors.error,
                        FeedbackPriority.medium => AppColors.warning,
                        FeedbackPriority.low => AppColors.textDisabled,
                      };
                      return GestureDetector(
                        onTap: () => setS(() => priority = p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: sel
                                ? color.withOpacity(0.15)
                                : AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(6),
                            border: sel
                                ? Border.all(color: color, width: 1.5)
                                : null,
                          ),
                          child: Text(p.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: sel ? color : AppColors.textSecondary,
                              )),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  // 공개 설정
                  const Text('공개 설정',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: FeedbackVisibility.values.map((v) {
                      final sel = visibility == v;
                      return GestureDetector(
                        onTap: () => setS(() => visibility = v),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.accent
                                : AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            v == FeedbackVisibility.public ? '공개' : '비공개',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: sel
                                  ? AppColors.onAccent
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  // 내용
                  const Text('내용',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: textCtrl,
                    maxLines: 5,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceMuted,
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (textCtrl.text.trim().isEmpty) return;
                      setS(() => saving = true);
                      final ok = await FeedbackService.updatePost(
                        feedbackId: post.id,
                        text: textCtrl.text.trim(),
                        type: type,
                        priority: priority,
                        visibility: visibility,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted && !ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('수정에 실패했어요')),
                        );
                      }
                    },
              child: const Text('저장',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePost(FeedbackPost post) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('피드백 삭제'),
        content: const Text('이 피드백을 삭제할까요?\n댓글도 함께 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await FeedbackService.deletePost(post.id);
              if (mounted) {
                if (ok) {
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('삭제에 실패했어요')),
                  );
                }
              }
            },
            child: const Text('삭제',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          '피드백 상세',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: StreamBuilder<FeedbackPost?>(
        stream: FeedbackService.watchOne(widget.feedbackId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final post = snap.data;
          if (post == null) {
            return const Center(child: Text('피드백을 찾을 수 없어요'));
          }

          return Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                  children: [
                    // ── 본문 카드 ──────────────────────────────────
                    _PostBody(post: post),
                    const SizedBox(height: 8),

                    // ── 수정/삭제 버튼 (작성자 또는 관리자) ───────────
                    if (_canEdit(post)) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _showEditDialog(post),
                            icon: const Icon(Icons.edit_outlined, size: 14),
                            label: const Text('수정',
                                style: TextStyle(fontSize: 13)),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                            ),
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            onPressed: () => _confirmDeletePost(post),
                            icon: const Icon(Icons.delete_outline, size: 14),
                            label: const Text('삭제',
                                style: TextStyle(fontSize: 13)),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.error,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],

                    // ── 관리자 상태 변경 ───────────────────────────
                    if (_isAdmin)
                      _AdminStatusRow(
                        current: post.adminStatus,
                        onChanged: (s) => _updateAdminStatus(post, s),
                      ),
                    const SizedBox(height: 20),

                    // ── 이미지 전체보기 ─────────────────────────────
                    if (post.imageUrls.isNotEmpty) ...[
                      const _SectionTitle('첨부 이미지'),
                      const SizedBox(height: 8),
                      ...post.imageUrls.map(
                        (url) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                            child: Image.network(
                              url,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 120,
                                color: AppColors.surfaceMuted,
                                child: const Icon(Icons.broken_image_outlined,
                                    color: AppColors.textDisabled),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── 댓글 섹션 ──────────────────────────────────
                    const _SectionTitle('댓글'),
                    const SizedBox(height: 8),
                    StreamBuilder<List<FeedbackComment>>(
                      stream: FeedbackService.watchComments(widget.feedbackId),
                      builder: (context, cs) {
                        final comments = cs.data ?? [];
                        if (comments.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              '아직 댓글이 없어요. 첫 댓글을 남겨보세요!',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textDisabled,
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: comments
                              .map((c) => _CommentItem(
                                    comment: c,
                                    myUid: _myUid,
                                    isAdmin: _isAdmin,
                                    onDelete: () => FeedbackService
                                        .deleteComment(
                                            widget.feedbackId, c.id),
                                  ))
                              .toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // ── 댓글 입력창 ──────────────────────────────────────
              _CommentInputBar(
                commentCtrl: _commentCtrl,
                nameCtrl: _namePrefCtrl,
                submitting: _submittingComment,
                onSubmit: _submitComment,
              ),
            ],
          );
        },
      ),
      bottomNavigationBar:
          kIsWeb ? const WebSiteFooter(backgroundColor: AppColors.white) : null,
    );
  }
}

// ── 본문 카드 ────────────────────────────────────────────────────
class _PostBody extends StatelessWidget {
  final FeedbackPost post;
  const _PostBody({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 뱃지 행
          Wrap(
            spacing: 6,
            children: [
              _chip(post.type.label, AppColors.accent),
              _chip(
                post.priority.label,
                switch (post.priority) {
                  FeedbackPriority.high => AppColors.error,
                  FeedbackPriority.medium => AppColors.warning,
                  FeedbackPriority.low => AppColors.textDisabled,
                },
              ),
              if (post.visibility == FeedbackVisibility.private)
                _chip('비공개', AppColors.textDisabled),
            ],
          ),
          const SizedBox(height: 12),

          // 본문
          Text(
            post.text,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),

          // 작성 정보
          _InfoRow(
              icon: Icons.person_outline,
              text: post.displayName.isNotEmpty
                  ? post.displayName
                  : post.authNickname.isNotEmpty
                      ? post.authNickname
                      : '익명'),
          const SizedBox(height: 4),
          _InfoRow(
              icon: Icons.location_on_outlined,
              text: '${post.sourceScreenLabel} (${post.sourceRoute})'),
          const SizedBox(height: 4),
          _InfoRow(
              icon: Icons.phone_iphone_outlined,
              text: '앱 버전 ${post.appVersion}'),
          const SizedBox(height: 4),
          _InfoRow(
              icon: Icons.access_time,
              text: _formatDate(post.createdAt)),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );

  String _formatDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.textDisabled),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textDisabled,
            ),
          ),
        ),
      ],
    );
  }
}

// ── 관리자 상태 변경 행 ────────────────────────────────────────────
class _AdminStatusRow extends StatelessWidget {
  final FeedbackAdminStatus current;
  final ValueChanged<FeedbackAdminStatus> onChanged;
  const _AdminStatusRow({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings_outlined,
              size: 14, color: AppColors.accent),
          const SizedBox(width: 6),
          const Text(
            '처리 상태:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 8),
          ...FeedbackAdminStatus.values.map((s) {
            final selected = s == current;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => onChanged(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accent
                        : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    s.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AppColors.onAccent
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── 댓글 아이템 ──────────────────────────────────────────────────
class _CommentItem extends StatelessWidget {
  final FeedbackComment comment;
  final String? myUid;
  final bool isAdmin;
  final VoidCallback onDelete;

  const _CommentItem({
    required this.comment,
    required this.myUid,
    required this.isAdmin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final canDelete = isAdmin || comment.uid == myUid;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceMuted,
            ),
            child: Center(
              child: Text(
                (comment.displayName.isNotEmpty
                        ? comment.displayName
                        : comment.authNickname)
                    .characters
                    .first,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.displayName.isNotEmpty
                          ? comment.displayName
                          : comment.authNickname.isNotEmpty
                              ? comment.authNickname
                              : '익명',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _timeAgo(comment.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textDisabled,
                      ),
                    ),
                    if (canDelete) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _confirmDelete(context),
                        child: const Icon(Icons.delete_outline,
                            size: 14, color: AppColors.textDisabled),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('댓글을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: const Text('삭제',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

// ── 댓글 입력창 ─────────────────────────────────────────────────
class _CommentInputBar extends StatefulWidget {
  final TextEditingController commentCtrl;
  final TextEditingController nameCtrl;
  final bool submitting;
  final VoidCallback onSubmit;

  const _CommentInputBar({
    required this.commentCtrl,
    required this.nameCtrl,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  State<_CommentInputBar> createState() => _CommentInputBarState();
}

class _CommentInputBarState extends State<_CommentInputBar> {
  bool _showNameField = false;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottom),
      duration: const Duration(milliseconds: 150),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          border: const Border(
            top: BorderSide(color: AppColors.divider),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 식별명 입력 (토글)
            if (_showNameField)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: TextField(
                  controller: widget.nameCtrl,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: '댓글 식별명 (비워두면 익명)',
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textDisabled,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                  ),
                ),
              ),

            Row(
              children: [
                // 식별명 토글 버튼
                GestureDetector(
                  onTap: () =>
                      setState(() => _showNameField = !_showNameField),
                  child: Icon(
                    _showNameField
                        ? Icons.person
                        : Icons.person_outline,
                    size: 20,
                    color: _showNameField
                        ? AppColors.accent
                        : AppColors.textDisabled,
                  ),
                ),
                const SizedBox(width: 8),
                // 댓글 입력창
                Expanded(
                  child: TextField(
                    controller: widget.commentCtrl,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '댓글을 입력하세요',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textDisabled,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: AppColors.surfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // 전송 버튼
                GestureDetector(
                  onTap: widget.submitting ? null : widget.onSubmit,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: widget.submitting
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onAccent,
                            ),
                          )
                        : const Icon(Icons.send_rounded,
                            size: 18, color: AppColors.onAccent),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 섹션 타이틀 ──────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      );
}
