import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_muted_card.dart';
import '../services/diary_image_service.dart';

/// 나의 기록 타임라인 페이지
///
/// 과거에 작성한 기록들을 시간 순으로 보여줌.
/// 이미지가 있으면 썸네일 1장 + 이미지 수 배지 표시.
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
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text('오류가 발생했습니다: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }

          final notes = snapshot.data?.docs ?? [];
          if (notes.isEmpty) {
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
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              final data = note.data() as Map<String, dynamic>;
              final text = data['text'] as String? ?? '';
              final createdAt = data['createdAt'] as Timestamp?;
              final imageUrls = _parseImageUrls(data);

              return _NoteCard(
                noteId: note.id,
                text: text,
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
  final Timestamp? createdAt;
  final List<String> imageUrls;
  final String uid;

  const _NoteCard({
    required this.noteId,
    required this.text,
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
        return '${yearShort}년 ${date.month}월 ${date.day}일, $weekday요일 ${DateFormat('HH시 mm분').format(date)}';
      }
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기록 삭제'),
        content: Text(imageUrls.isNotEmpty
            ? '이 기록과 첨부된 사진 ${imageUrls.length}장을 함께 삭제합니다.'
            : '이 기록을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => _deleteNote(context),
            child: const Text('삭제',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNote(BuildContext context) async {
    try {
      // Storage 이미지 삭제
      if (imageUrls.isNotEmpty) {
        await DiaryImageService.deleteAll(
          uid: uid,
          noteId: noteId,
          imageUrls: imageUrls,
        );
      }

      // Firestore 문서 삭제
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notes')
          .doc(noteId)
          .delete();

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기록이 삭제되었습니다')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
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

            // 본문
            if (text.isNotEmpty)
              Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),

            // 이미지 썸네일
            if (imageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ImageRow(imageUrls: imageUrls),
            ],
          ],
        ),
      ),
    );
  }
}

/// 이미지 행: 최대 3장 가로 나열, 탭 시 크게 보기
class _ImageRow extends StatelessWidget {
  final List<String> imageUrls;
  const _ImageRow({required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: imageUrls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          return GestureDetector(
            onTap: () => _openViewer(context, i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imageUrls[i],
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                cacheWidth: 200,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    width: 80,
                    height: 80,
                    color: AppColors.surfaceMuted,
                    child: const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  width: 80,
                  height: 80,
                  color: AppColors.surfaceMuted,
                  child: const Icon(Icons.broken_image_outlined,
                      size: 24, color: AppColors.textDisabled),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openViewer(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullImageViewer(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

/// 전체 화면 이미지 뷰어 (좌우 스와이프)
class _FullImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullImageViewer({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_FullImageViewer> createState() => _FullImageViewerState();
}

class _FullImageViewerState extends State<_FullImageViewer> {
  late final PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_current + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(fontSize: 16),
        ),
        elevation: 0,
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.imageUrls.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 3.0,
            child: Center(
              child: Image.network(
                widget.imageUrls[i],
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child:
                        CircularProgressIndicator(color: Colors.white54),
                  );
                },
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_outlined,
                      size: 48, color: Colors.white38),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
