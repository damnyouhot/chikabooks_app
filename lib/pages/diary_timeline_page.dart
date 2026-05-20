import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_confirm_modal.dart';
import '../core/widgets/app_muted_card.dart';
import '../services/admin_activity_service.dart';
import '../services/diary_image_service.dart';
import '../widgets/timeline/image_thumb_row.dart';

/// 나의 기록 타임라인 페이지
///
/// 과거에 작성한 기록들을 최신순으로 보여준다.
///
/// 설계 메모
/// - Firestore 쿼리에 `orderBy` 를 쓰지 않는다. 메모는 한 사용자가 평생 수백
///   개 안 쌓이는 데이터라 단일 필드 색인 빌드 / `createdAt` 누락 같은 문제를
///   감수할 이유가 없다. 전부 받아 클라이언트에서 정렬한다.
/// - 정렬 키 우선순위: `createdAt`(있으면) desc → 문서 ID desc(자동 ID 는
///   생성 시각이 어느 정도 단조 증가). 둘 다 없는 케이스는 사실상 발생 X.
class DiaryTimelinePage extends StatelessWidget {
  const DiaryTimelinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('나의 기록'),
          backgroundColor: AppColors.appBg,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: const Center(child: Text('로그인이 필요합니다')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        title: const Text(
          '나의 기록',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        backgroundColor: AppColors.appBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notes')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // 권한/네트워크 등 진짜 에러일 때만 도달. 메시지는 짧게.
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '기록을 불러오지 못했어요. 잠시 뒤 다시 시도해 주세요.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }

          final docs = [...?snapshot.data?.docs];
          docs.sort(_compareNotesDesc);

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.edit_note_outlined,
                      size: 64, color: AppColors.textDisabled),
                  SizedBox(height: 16),
                  Text('아직 기록이 없어요',
                      style: TextStyle(
                          fontSize: 16, color: AppColors.textSecondary)),
                  SizedBox(height: 8),
                  Text('오늘의 마음을 기록해보세요',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textDisabled)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final note = docs[index];
              final data = note.data() as Map<String, dynamic>;
              final text = data['text'] as String? ?? '';
              final createdAt = data['createdAt'] as Timestamp?;
              final imageUrls = _parseImageUrls(data);
              final mood = data['mood'] as String?;
              return _NoteCard(
                noteId: note.id,
                text: text,
                mood: mood,
                createdAt: createdAt,
                imageUrls: imageUrls,
                uid: uid,
              );
            },
          );
        },
      ),
    );
  }

  /// 최신순 정렬 비교자.
  ///
  /// `createdAt` 이 있는 쪽을 우선해 desc, 둘 중 하나만 없으면 있는 쪽이 위로.
  /// 둘 다 없으면 문서 ID(자동 생성 ID 는 시간 근사) desc 로 보조 정렬.
  static int _compareNotesDesc(QueryDocumentSnapshot a, QueryDocumentSnapshot b) {
    final aTs = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
    final bTs = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
    if (aTs != null && bTs != null) return bTs.compareTo(aTs);
    if (aTs != null) return -1;
    if (bTs != null) return 1;
    return b.id.compareTo(a.id);
  }

  static List<String> _parseImageUrls(Map<String, dynamic> data) {
    final raw = data['imageUrls'];
    if (raw is List) return raw.cast<String>();
    return [];
  }
}

/// 개별 기록 카드
class _NoteCard extends StatelessWidget {
  final String noteId;
  final String text;
  final String? mood;
  final Timestamp? createdAt;
  final List<String> imageUrls;
  final String uid;

  const _NoteCard({
    required this.noteId,
    required this.text,
    required this.mood,
    required this.createdAt,
    required this.imageUrls,
    required this.uid,
  });

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '날짜 없음';

    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);
    final weekday = ['월', '화', '수', '목', '금', '토', '일'][date.weekday - 1];

    if (diff.inDays == 0) {
      return '오늘 ${DateFormat('HH시 mm분').format(date)}';
    } else if (diff.inDays == 1) {
      return '어제 ${DateFormat('HH시 mm분').format(date)}';
    } else {
      final isThisYear = date.year == now.year;
      if (isThisYear) {
        return '${date.month}월 ${date.day}일, $weekday요일 ${DateFormat('HH시 mm분').format(date)}';
      } else {
        final yearShort = date.year % 100;
        return '$yearShort년 ${date.month}월 ${date.day}일, $weekday요일 ${DateFormat('HH시 mm분').format(date)}';
      }
    }
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    final message =
        imageUrls.isNotEmpty
            ? '이 기록과 첨부된 사진 ${imageUrls.length}장을 함께 삭제합니다.'
            : '이 기록을 삭제하시겠습니까?';
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AppConfirmModal(
            title: '기록 삭제',
            message: message,
            confirmLabel: '삭제',
            destructive: true,
          ),
    );
    if (confirmed == true && context.mounted) {
      await _deleteNoteAfterConfirm(context);
    }
  }

  Future<void> _deleteNoteAfterConfirm(BuildContext context) async {
    try {
      if (imageUrls.isNotEmpty) {
        await DiaryImageService.deleteAll(
          uid: uid,
          noteId: noteId,
          imageUrls: imageUrls,
        );
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notes')
          .doc(noteId)
          .delete();

      AdminActivityService.log(
        ActivityEventType.noteDelete,
        page: 'diary_timeline',
        targetId: noteId,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기록이 삭제되었습니다')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppMutedCard(
        radius: AppRadius.xl,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 날짜 + 삭제 버튼
            Row(
              children: [
                const Icon(Icons.schedule,
                    size: 14, color: AppColors.textDisabled),
                const SizedBox(width: 4),
                Text(
                  _formatDate(createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showDeleteDialog(context),
                  child: const Icon(Icons.delete_outline,
                      size: 18, color: AppColors.textDisabled),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 본문 + 「오늘 기분」 이모지 (있을 때만 본문 머리에 작게 붙임)
            if (text.isNotEmpty || (mood != null && mood!.isNotEmpty))
              Text.rich(
                TextSpan(
                  children: [
                    if (mood != null && mood!.isNotEmpty) ...[
                      TextSpan(
                        text: '$mood  ',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
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

            // 이미지 썸네일
            if (imageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              ImageThumbRow(imageUrls: imageUrls),
            ],
          ],
        ),
      ),
    );
  }
}
