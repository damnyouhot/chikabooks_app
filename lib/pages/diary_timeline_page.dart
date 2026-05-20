import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_confirm_modal.dart';
import '../core/widgets/app_muted_card.dart';
import '../services/diary_image_service.dart';

/// 나의 기록 타임라인 페이지
///
/// 과거에 작성한 기록들을 시간 순으로 보여줌.
/// 이미지가 있으면 썸네일 1장 + 이미지 수 배지 표시.
///
/// 첫 응답이 일정 시간 내에 오지 않으면 「인덱스 빌드 중일 가능성」 을
/// 사용자에게 알려준다. (Firestore 가 첫 쿼리 시 단일 필드 인덱스를
/// 자동 빌드 — 보통 수 초 ~ 수 분 소요. 이 동안 stream 은 응답을 주지
/// 않고 대기 상태로 머물러 사용자가 무한 로딩처럼 느낀다.)
class DiaryTimelinePage extends StatefulWidget {
  const DiaryTimelinePage({super.key});

  @override
  State<DiaryTimelinePage> createState() => _DiaryTimelinePageState();
}

class _DiaryTimelinePageState extends State<DiaryTimelinePage> {
  /// 첫 응답이 6초 내에 오지 않으면 「오래 걸려요」 안내를 표시한다.
  static const _slowResponseThreshold = Duration(seconds: 6);

  Timer? _slowTimer;
  bool _slow = false;
  bool _firstResponseReceived = false;

  /// 사용자가 「정렬 없이 보기」를 눌렀을 때 true.
  /// orderBy 없이 limit 50 으로 페치 후 클라이언트에서 정렬한다.
  /// (createdAt 누락 문서 / 단일필드 색인 빌드 지연을 우회하는 진단·임시 수단)
  bool _useFallback = false;

  @override
  void initState() {
    super.initState();
    _slowTimer = Timer(_slowResponseThreshold, () {
      if (!mounted || _firstResponseReceived) return;
      setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  void _markFirstResponse() {
    if (_firstResponseReceived) return;
    _firstResponseReceived = true;
    _slowTimer?.cancel();
    if (_slow && mounted) {
      // 응답이 도착했으면 안내 배너를 즉시 내린다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _slow = false);
      });
    }
  }

  void _enableFallback() {
    if (_useFallback) return;
    setState(() {
      _useFallback = true;
      _slow = false;
      _firstResponseReceived = false;
    });
    _slowTimer?.cancel();
    _slowTimer = Timer(_slowResponseThreshold, () {
      if (!mounted || _firstResponseReceived) return;
      setState(() => _slow = true);
    });
  }

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
        // 기본은 createdAt desc. 사용자가 6초 무응답 후 「정렬 없이 보기」를
        // 누르면 orderBy 를 빼고 limit 50 만 받아 클라이언트에서 정렬한다.
        stream: _buildNotesStream(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('⚠️ DiaryTimeline error: ${snapshot.error}');
            return _buildErrorState(snapshot.error);
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState(
              slow: _slow,
              showFallbackButton: !_useFallback,
              onUseFallback: _enableFallback,
            );
          }
          _markFirstResponse();

          var notes = snapshot.data?.docs ?? [];
          if (_useFallback) {
            // 클라이언트 정렬: createdAt(있으면) desc, 없으면 그대로.
            final list = [...notes];
            list.sort((a, b) {
              final aTs = (a.data() as Map<String, dynamic>)['createdAt']
                  as Timestamp?;
              final bTs = (b.data() as Map<String, dynamic>)['createdAt']
                  as Timestamp?;
              if (aTs == null && bTs == null) return 0;
              if (aTs == null) return 1; // 누락은 뒤로
              if (bTs == null) return -1;
              return bTs.compareTo(aTs); // desc
            });
            notes = list;
          }
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

          // fallback 모드에서 결과를 받아 표시 중일 때, 사용자에게 상태를
          // 살짝 알려준다. (얇은 1줄 배지)
          final list = ListView.builder(
            padding: EdgeInsets.fromLTRB(
              16,
              _useFallback ? 8 : 16,
              16,
              16,
            ),
            itemCount: notes.length + (_useFallback ? 1 : 0),
            itemBuilder: (context, index) {
              if (_useFallback && index == 0) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '임시 정렬 모드 · 시간 정보가 없는 기록은 아래쪽에 표시돼요',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }
              final i = _useFallback ? index - 1 : index;
              final note = notes[i];
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
          return list;
        },
      ),
    );
  }

  /// 노트 stream — fallback 모드에서는 orderBy 를 빼고 limit 50 만 받아온다.
  Stream<QuerySnapshot> _buildNotesStream(String uid) {
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notes');
    if (_useFallback) {
      return col.limit(50).snapshots();
    }
    return col.orderBy('createdAt', descending: true).snapshots();
  }

  /// 로딩 상태 — 일정 시간이 지나도 첫 응답이 없으면 [slow] 안내를 함께 노출.
  /// fallback 미적용 상태일 때만 「정렬 없이 보기」 버튼을 노출해 사용자가
  /// 인덱스 빌드 대기/createdAt 누락 케이스를 즉시 우회할 수 있게 한다.
  Widget _buildLoadingState({
    required bool slow,
    required bool showFallbackButton,
    required VoidCallback onUseFallback,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.accent),
          if (slow) ...[
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '처음 한 번은 정렬 인덱스를 만드는 데 시간이 걸려요.\n잠시 후 자동으로 표시됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (showFallbackButton) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onUseFallback,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('정렬 없이 바로 보기'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// 에러 상태 — 인덱스 빌드 중(`failed-precondition`)은 별도 메시지로 안내.
  ///
  /// 다른 일반 에러는 한 줄 간략히 보여주고, 자세한 내용은 디버그 콘솔로.
  Widget _buildErrorState(Object? error) {
    final raw = error?.toString() ?? '';
    final isIndexBuilding =
        raw.contains('failed-precondition') ||
        raw.contains('requires an index');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isIndexBuilding
                  ? Icons.hourglass_top_rounded
                  : Icons.error_outline_rounded,
              size: 56,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: 16),
            Text(
              isIndexBuilding ? '잠시만요, 준비 중이에요' : '잠깐 문제가 생겼어요',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isIndexBuilding
                  ? '기록 정렬을 처음 준비하는 중이라 1~2분 정도 걸려요.\n조금 뒤에 다시 들어와 주세요.'
                  : '잠시 뒤 다시 시도해 주세요.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
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
