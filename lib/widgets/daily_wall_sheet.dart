import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/daily_wall_post.dart';
import '../services/daily_wall_service.dart';

/// "오늘의 한 문장" BottomSheet
/// 탭A: 만들기 (3단 조합 선택)
/// 탭B: 오늘의 문장들 (피드 + 리액션)
class DailyWallSheet extends StatefulWidget {
  const DailyWallSheet({super.key});

  @override
  State<DailyWallSheet> createState() => _DailyWallSheetState();
}

class _DailyWallSheetState extends State<DailyWallSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final String _dateKey = DailyWallService.todayDateKey();
  bool _alreadyPosted = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _checkAlreadyPosted();
  }

  Future<void> _checkAlreadyPosted() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _checking = false);
        return;
      }
      final posted = await DailyWallService.hasPostedToday(uid, _dateKey);
      if (mounted) {
        setState(() {
          _alreadyPosted = posted;
          _checking = false;
          if (posted) _tabCtrl.index = 1;
        });
      }
    } catch (e) {
      debugPrint('⚠️ _checkAlreadyPosted error: $e');
      if (mounted) {
        setState(() => _checking = false); // 에러여도 UI 풀어줌
      }
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // 드래그 핸들
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // 제목
              const Text(
                '✍️ 오늘의 한 문장',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 8),

              // 탭바
              TabBar(
                controller: _tabCtrl,
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textDisabled,
                indicatorColor: AppColors.accent,
                tabs: const [
                  Tab(text: '만들기'),
                  Tab(text: '오늘의 문장들'),
                ],
              ),

              // 탭뷰
              Expanded(
                child: _checking
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabCtrl,
                        children: [
                          _ComposeTab(
                            dateKey: _dateKey,
                            alreadyPosted: _alreadyPosted,
                            onPostSuccess: () {
                              setState(() => _alreadyPosted = true);
                              _tabCtrl.animateTo(1); // 피드 탭으로 이동
                            },
                          ),
                          _FeedTab(dateKey: _dateKey),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════
//  탭A: 만들기 (3단 조합 선택)
// ═══════════════════════════════════════════════════════

class _ComposeTab extends StatefulWidget {
  final String dateKey;
  final bool alreadyPosted;
  final VoidCallback onPostSuccess;

  const _ComposeTab({
    required this.dateKey,
    required this.alreadyPosted,
    required this.onPostSuccess,
  });

  @override
  State<_ComposeTab> createState() => _ComposeTabState();
}

class _ComposeTabState extends State<_ComposeTab> {
  String? _selectedSituation;
  String? _selectedTone;
  String? _selectedEndingKey;
  bool _posting = false;

  String get _preview {
    if (_selectedSituation == null ||
        _selectedTone == null ||
        _selectedEndingKey == null) {
      return '';
    }
    return DailyWallService.renderText(
      _selectedSituation!,
      _selectedTone!,
      _selectedEndingKey!,
    );
  }

  bool get _canPost =>
      !widget.alreadyPosted &&
      _selectedSituation != null &&
      _selectedTone != null &&
      _selectedEndingKey != null &&
      !_posting;

  Future<void> _submit() async {
    if (!_canPost) return;
    setState(() => _posting = true);
    try {
      await DailyWallService.createPost(
        situationTag: _selectedSituation!,
        toneEmoji: _selectedTone!,
        endingKey: _selectedEndingKey!,
        dateKey: widget.dateKey,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오늘의 한 문장을 남겼어요 ✨')),
        );
        widget.onPostSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 이미 게시한 경우
    if (widget.alreadyPosted) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 56, color: AppColors.accent),
            const SizedBox(height: 16),
            const Text(
              '오늘은 이미 남겼어요',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '"오늘의 문장들" 탭에서 확인해 보세요.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Step 1: 상황 태그 ──
          _sectionTitle('1. 오늘 어떤 상황이었어?'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DailyWallService.situationTags.map((tag) {
              final selected = _selectedSituation == tag;
                return ChoiceChip(
                label: Text(tag),
                selected: selected,
                selectedColor: AppColors.accent.withOpacity(0.15),
                onSelected: (_) =>
                    setState(() => _selectedSituation = tag),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // ── Step 2: 감정 톤 ──
          _sectionTitle('2. 느낌은?'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: DailyWallService.toneEmojis.map((emoji) {
              final selected = _selectedTone == emoji;
              return GestureDetector(
                onTap: () => setState(() => _selectedTone = emoji),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accent.withOpacity(0.15)
                        : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(16),
                    border: selected
                        ? Border.all(color: AppColors.accent, width: 2)
                        : null,
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // ── Step 3: 마침 문구 ──
          _sectionTitle('3. 마무리 한마디'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DailyWallService.endings.entries.map((e) {
              final selected = _selectedEndingKey == e.key;
                return ChoiceChip(
                label: Text(e.value),
                selected: selected,
                selectedColor: AppColors.accent.withOpacity(0.15),
                onSelected: (_) =>
                    setState(() => _selectedEndingKey = e.key),
              );
            }).toList(),
          ),

          const SizedBox(height: 28),

          // ── 미리보기 ──
          if (_preview.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _preview,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── 게시 버튼 ──
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _canPost ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                disabledBackgroundColor: AppColors.disabledBg,
              ),
              child: _posting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Text(
                      '남기기',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  탭B: 오늘의 문장들 (피드 + 리액션)
// ═══════════════════════════════════════════════════════

class _FeedTab extends StatelessWidget {
  final String dateKey;
  const _FeedTab({required this.dateKey});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DailyWallPost>>(
      stream: DailyWallService.streamTodayPosts(dateKey),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          debugPrint('⚠️ FeedTab stream error: ${snap.error}');
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, size: 48, color: AppColors.textDisabled),
                const SizedBox(height: 12),
                Text(
                  '불러오는 중 문제가 생겼어요.\n잠시 후 다시 시도해 주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          );
        }
        final posts = snap.data ?? [];
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_note, size: 48, color: AppColors.textDisabled),
                const SizedBox(height: 12),
                Text(
                  '아직 오늘의 문장이 없어요.\n첫 번째로 남겨 보세요!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _PostCard(post: posts[i]),
        );
      },
    );
  }
}

// ───────────────── 피드 카드 ─────────────────

class _PostCard extends StatefulWidget {
  final DailyWallPost post;
  const _PostCard({required this.post});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  String? _myReactionKey;
  Map<String, int>? _summary;
  bool _showReactions = false;

  @override
  void initState() {
    super.initState();
    _loadReactionData();
  }

  Future<void> _loadReactionData() async {
    final results = await Future.wait([
      DailyWallService.getMyReaction(widget.post.id),
      DailyWallService.getReactionSummary(widget.post.id),
    ]);
    if (mounted) {
      setState(() {
        _myReactionKey = results[0] as String?;
        _summary = results[1] as Map<String, int>;
      });
    }
  }

  Future<void> _react(String key) async {
    await DailyWallService.setReaction(widget.post.id, key);
    if (mounted) {
      setState(() {
        // 이전 리액션 카운트 감소
        if (_myReactionKey != null && _summary != null) {
          final prev = _myReactionKey!;
          _summary![prev] = ((_summary![prev] ?? 1) - 1).clamp(0, 9999);
        }
        _myReactionKey = key;
        _summary ??= {};
        _summary![key] = (_summary![key] ?? 0) + 1;
        _showReactions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final hasAnyReaction =
        _summary != null && _summary!.values.any((v) => v > 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 작성자 뱃지
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  post.authorMeta.displayLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const Spacer(),
              // "반응 있음" 작은 dot
              if (hasAnyReaction)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // 문장 본문
          Text(
            post.renderedText,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.6,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 12),

          // 리액션 요약 (작게) + 리액션 버튼
          Row(
            children: [
              // 요약 텍스트
              if (_summary != null)
                Expanded(
                  child: _buildReactionSummary(),
                )
              else
                const Spacer(),

              // 리액션 토글
              GestureDetector(
                onTap: () =>
                    setState(() => _showReactions = !_showReactions),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _myReactionKey != null
                        ? AppColors.accent.withOpacity(0.15)
                        : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_myReactionKey != null)
                        Text(
                          DailyWallService
                                  .reactionOptions[_myReactionKey]?.emoji ??
                              '💛',
                          style: const TextStyle(fontSize: 14),
                        )
                      else
                        Icon(Icons.add_reaction_outlined,
                            size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        _myReactionKey != null ? '변경' : '공감',
                        style: TextStyle(
                          fontSize: 11,
                          color: _myReactionKey != null
                              ? AppColors.accent
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 리액션 선택 패널
          if (_showReactions) ...[
            const SizedBox(height: 12),
            _buildReactionPicker(),
          ],
        ],
      ),
    );
  }

  Widget _buildReactionSummary() {
    if (_summary == null || _summary!.isEmpty) return const SizedBox.shrink();

    final entries = _summary!.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      children: entries.map((e) {
        final option = DailyWallService.reactionOptions[e.key];
        if (option == null) return const SizedBox.shrink();
        return Text(
          '${option.emoji}${e.value}',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        );
      }).toList(),
    );
  }

  Widget _buildReactionPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children:
            DailyWallService.reactionOptions.entries.map((e) {
          final isSelected = _myReactionKey == e.key;
          return GestureDetector(
            onTap: () => _react(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accent.withOpacity(0.15)
                    : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? Border.all(color: AppColors.accent, width: 1.5)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e.value.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Text(
                    e.value.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? AppColors.accent
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

