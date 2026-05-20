import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_muted_card.dart';
import '../../../services/admin_timeline_service.dart';
import '../../../widgets/timeline/image_thumb_row.dart';

/// 운영 대시보드 「타임라인」 탭.
///
/// 전체 유저가 작성한 「기록(notes)」과 「목표(goals)」를 트위터 타임라인처럼
/// 시간 역순으로 한 흐름에 모아 보여줍니다.
///
/// - 사진은 썸네일 가로 스크롤 → 탭 시 풀스크린 [FullImageViewer].
/// - 작성자 닉네임/이메일을 함께 노출(운영자 권한).
/// - 기간 칩(상단)으로 [since] 가 제어됩니다.
class AdminTimelineTab extends StatelessWidget {
  final DateTime since;
  const AdminTimelineTab({super.key, required this.since});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TimelineItem>>(
      stream: AdminTimelineService.watchFeed(since: since),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '타임라인을 불러오지 못했어요.\n${snap.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          );
        }
        final items = snap.data!;
        if (items.isEmpty) {
          return const Center(
            child: Text(
              '해당 기간에 작성된 기록·목표가 없어요',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (_, i) {
            final item = items[i];
            return _TimelineCard(item: item);
          },
        );
      },
    );
  }
}

// ─── 카드 ────────────────────────────────────────────────────────

class _TimelineCard extends StatelessWidget {
  final TimelineItem item;
  const _TimelineCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppMutedCard(
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AuthorHeader(uid: item.uid, createdAt: item.createdAt, kind: item.kind),
          const SizedBox(height: AppSpacing.sm),
          if (item.kind == TimelineItemKind.note)
            _NoteBody(item: item)
          else
            _GoalBody(item: item),
        ],
      ),
    );
  }
}

class _NoteBody extends StatelessWidget {
  final TimelineItem item;
  const _NoteBody({required this.item});

  @override
  Widget build(BuildContext context) {
    final text = item.noteText;
    final mood = item.noteMood;
    final images = item.noteImageUrls;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (text.isNotEmpty || (mood != null && mood.isNotEmpty))
          Text.rich(
            TextSpan(
              children: [
                if (mood != null && mood.isNotEmpty)
                  TextSpan(
                    text: '$mood  ',
                    style: const TextStyle(fontSize: 16),
                  ),
                if (text.isNotEmpty)
                  TextSpan(
                    text: text,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
        if (images.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          ImageThumbRow(imageUrls: images),
        ],
      ],
    );
  }
}

class _GoalBody extends StatelessWidget {
  final TimelineItem item;
  const _GoalBody({required this.item});

  @override
  Widget build(BuildContext context) {
    final title = item.goalTitle;
    final isRoutine = item.goalType == 'routine';
    final isDone = item.goalIsDone;
    final checkpoints = item.goalCheckpoints;
    final doneCount = checkpoints.where((c) => c['done'] == true).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isRoutine
                    ? AppColors.cardPrimary.withValues(alpha: 0.1)
                    : AppColors.cardEmphasis.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                isRoutine ? '루틴' : '프로젝트',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isRoutine
                      ? AppColors.cardPrimary
                      : AppColors.cardEmphasis,
                ),
              ),
            ),
            if (isDone) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle, size: 14, color: AppColors.cardPrimary),
              const SizedBox(width: 2),
              const Text(
                '완료',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.cardPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title.isEmpty ? '(제목 없음)' : title,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textPrimary,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (checkpoints.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: doneCount / checkpoints.length,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceMuted,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$doneCount / ${checkpoints.length}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─── 작성자 헤더 (닉네임 + 이메일 + 시간) ────────────────────────

class _AuthorHeader extends StatelessWidget {
  final String uid;
  final DateTime createdAt;
  final TimelineItemKind kind;
  const _AuthorHeader({
    required this.uid,
    required this.createdAt,
    required this.kind,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AuthorInfo>(
      future: _AuthorInfoCache.instance.get(uid),
      builder: (context, snap) {
        final info = snap.data;
        final nickname = info?.nickname ?? '...';
        final email = info?.email;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.surfaceMuted,
              child: Text(
                nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        kind == TimelineItemKind.note
                            ? Icons.edit_note_outlined
                            : Icons.flag_outlined,
                        size: 14,
                        color: AppColors.textDisabled,
                      ),
                    ],
                  ),
                  if (email != null && email.isNotEmpty)
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textDisabled,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatTime(createdAt),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textDisabled,
              ),
            ),
          ],
        );
      },
    );
  }

  static String _formatTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return DateFormat('yy.MM.dd HH:mm').format(t);
  }
}

// ─── 작성자 정보 캐시 (앱 세션 메모리) ─────────────────────────

class _AuthorInfo {
  final String nickname;
  final String? email;
  const _AuthorInfo({required this.nickname, this.email});
}

class _AuthorInfoCache {
  _AuthorInfoCache._();
  static final instance = _AuthorInfoCache._();

  final Map<String, _AuthorInfo> _cache = {};
  final Map<String, Future<_AuthorInfo>> _inflight = {};

  Future<_AuthorInfo> get(String uid) {
    final cached = _cache[uid];
    if (cached != null) return Future.value(cached);
    final inflight = _inflight[uid];
    if (inflight != null) return inflight;

    final future = _fetch(uid);
    _inflight[uid] = future;
    return future;
  }

  Future<_AuthorInfo> _fetch(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data() ?? const {};
      final nickname =
          (data['nickname'] as String?)?.trim().isNotEmpty == true
              ? (data['nickname'] as String).trim()
              : '(닉네임 없음)';
      final email = (data['email'] as String?)?.trim();
      final info = _AuthorInfo(
        nickname: nickname,
        email: (email != null && email.isNotEmpty) ? email : null,
      );
      _cache[uid] = info;
      return info;
    } catch (_) {
      final info = _AuthorInfo(nickname: '($uid)', email: null);
      _cache[uid] = info;
      return info;
    } finally {
      _inflight.remove(uid);
    }
  }
}
