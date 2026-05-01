import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/daily_word.dart';
import '../models/ebook.dart';
import '../models/hira_update.dart';
import '../services/daily_word_service.dart';
import '../services/admin_activity_service.dart';
import '../services/content_read_state_service.dart';
import '../services/ebook_service.dart';
import '../services/hira_update_service.dart';
import '../widgets/hira_update_detail_sheet.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_muted_button.dart';
import '../core/widgets/app_muted_card.dart';
import '../core/widgets/app_primary_card.dart';
import '../core/widgets/app_segmented_control.dart';
import 'ebook/ebook_detail_page.dart';
import 'quiz_today_page.dart';
import 'hira_update_page.dart';
import 'settings/settings_page.dart';

/// 성장 탭
///
/// 상단 세그먼트 4개 (스토어 탭은 숨김 — `EbookListPage`는 `/books` 등에서 유지):
/// 1. 오늘의 퀴즈 — 매일 2문제
/// 2. 오늘 단어 — 배치 구상용
/// 3. 보험정보 — HIRA 수가/급여 변경
/// 4. 내 서재 — 연동 도서 목록
class GrowthPage extends StatefulWidget {
  final ValueNotifier<int>? subTabNotifier;

  /// 보험정보(HiraUpdatePage) 내부 소탭: 0=수가 조회, 1=제도 변경
  final ValueNotifier<int>? hiraTabRequestNotifier;

  const GrowthPage({
    super.key,
    this.subTabNotifier,
    this.hiraTabRequestNotifier,
  });

  @override
  State<GrowthPage> createState() => _GrowthPageState();
}

class _GrowthPageState extends State<GrowthPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  int _lastMarkedTabIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(_markCurrentTabSeen);
    widget.subTabNotifier?.addListener(_onSubTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _markCurrentTabSeen());
  }

  void _onSubTabChanged() {
    final idx = widget.subTabNotifier?.value ?? -1;
    if (idx >= 0 && idx < 4) {
      _tabCtrl.animateTo(idx);
    }
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_markCurrentTabSeen);
    widget.subTabNotifier?.removeListener(_onSubTabChanged);
    _tabCtrl.dispose();
    super.dispose();
  }

  void _markCurrentTabSeen() {
    if (!mounted || _lastMarkedTabIndex == _tabCtrl.index) return;
    _lastMarkedTabIndex = _tabCtrl.index;
    final key = switch (_tabCtrl.index) {
      0 => ContentReadKeys.todayQuiz,
      1 => ContentReadKeys.todayWords,
      _ => null,
    };
    if (key != null) ContentReadStateService.markSeen(key);
    if (_tabCtrl.index == 1) {
      AdminActivityService.log(
        ActivityEventType.viewTodayWords,
        page: 'growth_today_words',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            // 세그먼트 탭바 → AppSegmentedControl (상단 마진 0 — 헤더 아이콘과 겹치지 않게 본문만 위로)
            StreamBuilder<Set<int>>(
              stream: ContentReadStateService.watchNewIndices(const {
                0: [ContentReadKeys.todayQuiz],
                1: [ContentReadKeys.todayWords],
                2: [ContentReadKeys.hiraPolicyUpdates],
                3: [
                  ContentReadKeys.ebooks,
                  ContentReadKeys.savedHiraUpdates,
                  ContentReadKeys.savedWords,
                ],
              }),
              initialData: const {},
              builder: (context, snapshot) {
                return AppSegmentedControl(
                  controller: _tabCtrl,
                  labels: const ['오늘 퀴즈', '오늘 단어', '보험정보', '내 서재'],
                  newIndices: snapshot.data ?? const {},
                  margin: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.sm,
                  ),
                );
              },
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  const QuizTodayPage(),
                  const _TodayWordView(),
                  HiraUpdatePage(
                    tabRequestNotifier: widget.hiraTabRequestNotifier,
                  ),
                  const _MyLibraryView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xl,
        right: 4,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),
          IconButton(
            icon: Icon(
              Icons.info_outline,
              color: AppColors.textDisabled,
              size: 18,
            ),
            onPressed: () => _showConceptDialog(context),
          ),
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: AppColors.textDisabled,
              size: 20,
            ),
            onPressed:
                () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
    );
  }

  void _showConceptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text(
              '성장하기 탭에 대해서',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            content: const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '퀴즈, 단어, 보험정보, 책으로 치과 직무를 배우고 기록하는 공간이에요.',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '📝 오늘 퀴즈',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '매일 국시·임상 문제를 풀어요. (스케줄에 따라 하루 2문항)',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '🔤 오늘 단어',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '하루에 하나씩 치과 실무 단어를 익히는 공간이에요.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '📋 보험정보',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '수가 조회와 HIRA 급여·수가 제도 변경 소식을 확인해요.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '📖 하이진랩',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '하이진랩에 올라온 책들을 볼 수 있는 공간이에요.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '📗 내 서재',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '연동 전자책 스토어에서 구매한 책들을 볼 수 있는 곳이에요.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('닫기'),
              ),
            ],
          ),
    );
  }
}

class _TodayWordView extends StatefulWidget {
  const _TodayWordView();

  @override
  State<_TodayWordView> createState() => _TodayWordViewState();
}

class _TodayWordViewState extends State<_TodayWordView> {
  bool _loading = true;
  List<DailyWord> _words = [];
  Map<String, DailyWordStatus> _actions = {};
  Set<String> _savedWordIds = {};
  int _knownCount = 0;
  int _reviewCount = 0;
  int _savedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadTodayDeck();
  }

  Future<void> _loadTodayDeck() async {
    setState(() => _loading = true);
    final deck = await DailyWordService.loadTodayDeck();
    if (!mounted) return;
    setState(() {
      _words = deck.words;
      _actions = Map<String, DailyWordStatus>.from(deck.actions);
      _savedWordIds = Set<String>.from(deck.savedWordIds);
      _knownCount = deck.knownCount;
      _reviewCount = deck.reviewLaterCount;
      _savedCount = deck.savedCount;
      _loading = false;
    });
  }

  void _adjustCounts(DailyWordStatus? previous, DailyWordStatus? next) {
    if (previous == DailyWordStatus.known) _knownCount--;
    if (previous == DailyWordStatus.reviewLater) _reviewCount--;
    if (next == DailyWordStatus.known) _knownCount++;
    if (next == DailyWordStatus.reviewLater) _reviewCount++;
  }

  Future<void> _toggleWordAction(DailyWord word, DailyWordStatus status) async {
    final previous = _actions[word.id];
    if (previous != null && previous != status) return;

    final next = previous == status ? null : status;
    setState(() {
      _adjustCounts(previous, next);
      if (next == null) {
        _actions.remove(word.id);
      } else {
        _actions[word.id] = next;
      }
    });

    try {
      await DailyWordService.setWordStatus(word: word, status: next);
      if (next != null) {
        AdminActivityService.log(
          next == DailyWordStatus.known
              ? ActivityEventType.dailyWordKnown
              : ActivityEventType.dailyWordReviewLater,
          page: 'growth_today_words',
          targetId: word.id,
          extra: {
            'wordCategory': word.category,
            'wordEnglish': word.english,
          },
        );
      }
    } catch (e) {
      debugPrint('⚠️ 오늘 단어 상태 저장 실패: $e');
      if (!mounted) return;
      await _loadTodayDeck();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('단어 기록 저장에 실패했습니다. 다시 시도해 주세요.')),
      );
    }
  }

  Future<void> _toggleSaved(DailyWord word) async {
    final wasSaved = _savedWordIds.contains(word.id);
    setState(() {
      if (wasSaved) {
        _savedWordIds.remove(word.id);
        _savedCount--;
      } else {
        _savedWordIds.add(word.id);
        _savedCount++;
      }
    });

    try {
      await DailyWordService.setSavedWord(word: word, isSaved: !wasSaved);
      AdminActivityService.log(
        wasSaved
            ? ActivityEventType.dailyWordUnsaved
            : ActivityEventType.dailyWordSaved,
        page: 'growth_today_words',
        targetId: word.id,
        extra: {
          'wordCategory': word.category,
          'wordEnglish': word.english,
        },
      );
    } catch (e) {
      debugPrint('⚠️ 오늘 단어 저장 실패: $e');
      if (!mounted) return;
      await _loadTodayDeck();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('단어 저장에 실패했습니다. 다시 시도해 주세요.')),
      );
    }
  }

  Future<void> _confirmResetWordHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            title: const Text(
              '전체 기록 리셋',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            content: const Text(
              '아는 단어, 다시보기, 저장한 단어, 오늘 배정 기록이 모두 초기화됩니다.\n\n'
              '초기화 후에는 전체 단어풀이 다시 노출 대상이 됩니다. 계속할까요?',
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: AppColors.textSecondary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  '전체 기록 리셋',
                  style: TextStyle(
                    color: AppColors.destructive,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      await _resetWordHistory();
    }
  }

  Future<void> _resetWordHistory() async {
    await DailyWordService.resetAllUserRecords();
    if (!mounted) return;
    await _loadTodayDeck();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      children: [
        _TodayWordStatsCard(
          knownCount: _knownCount,
          reviewCount: _reviewCount,
          savedCount: _savedCount,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오늘 단어 3개',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            AppMutedButton(
              onTap: _confirmResetWordHistory,
              label: '전체 기록 리셋',
              icon: Icons.refresh_rounded,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              fontWeight: FontWeight.w700,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_words.isEmpty)
          const _TodayWordEmptyCard()
        else
          ..._words.map(
            (word) => _TodayWordCard(
              key: ValueKey(word.id),
              word: word,
              action: _actions[word.id],
              isSaved: _savedWordIds.contains(word.id),
              onKnown: () => _toggleWordAction(word, DailyWordStatus.known),
              onReviewLater:
                  () => _toggleWordAction(word, DailyWordStatus.reviewLater),
              onSave: () => _toggleSaved(word),
            ),
          ),
      ],
    );
  }
}

class _TodayWordCard extends StatefulWidget {
  const _TodayWordCard({
    super.key,
    required this.word,
    required this.action,
    required this.isSaved,
    required this.onKnown,
    required this.onReviewLater,
    required this.onSave,
  });

  final DailyWord word;
  final DailyWordStatus? action;
  final bool isSaved;
  final VoidCallback onKnown;
  final VoidCallback onReviewLater;
  final VoidCallback onSave;

  @override
  State<_TodayWordCard> createState() => _TodayWordCardState();
}

class _TodayWordCardState extends State<_TodayWordCard> {
  bool _isMeaningExpanded = false;

  @override
  Widget build(BuildContext context) {
    final word = widget.word;
    final action = widget.action;
    final isSaved = widget.isSaved;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppMutedCard(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        radius: AppRadius.lg,
        child: Stack(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 114),
              child: Padding(
                padding: const EdgeInsets.only(right: 82, bottom: 36),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DailyWordCategoryBadge(label: word.category),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      word.english,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      word.pronunciationKo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap:
                          () => setState(
                            () => _isMeaningExpanded = !_isMeaningExpanded,
                          ),
                      child: Text(
                        word.meaning,
                        maxLines: _isMeaningExpanded ? null : 2,
                        overflow:
                            _isMeaningExpanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: AppMutedButton(
                onTap: widget.onSave,
                label: isSaved ? '저장됨' : '저장',
                icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                isActive: isSaved,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                fontWeight: FontWeight.w700,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _WordActionButton(
                    onTap: widget.onKnown,
                    label: '아는 단어',
                    color: AppColors.cardEmphasis,
                    isSelected: action == DailyWordStatus.known,
                    isDisabled:
                        action != null && action != DailyWordStatus.known,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _WordActionButton(
                    onTap: widget.onReviewLater,
                    label: '다시보기',
                    color: AppColors.accent,
                    isSelected: action == DailyWordStatus.reviewLater,
                    isDisabled:
                        action != null && action != DailyWordStatus.reviewLater,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyWordCategoryBadge extends StatelessWidget {
  const _DailyWordCategoryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final text = label.trim().isEmpty ? '기타' : label.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardEmphasis,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.white,
          height: 1.1,
        ),
      ),
    );
  }
}

class _WordActionButton extends StatelessWidget {
  const _WordActionButton({
    required this.onTap,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.isDisabled,
  });

  final VoidCallback onTap;
  final String label;
  final Color color;
  final bool isSelected;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final bgColor =
        isSelected
            ? color
            : isDisabled
            ? AppColors.disabledBg
            : color.withValues(alpha: 0.1);
    final textColor =
        isSelected
            ? AppColors.white
            : isDisabled
            ? AppColors.disabledText
            : color;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color:
                isSelected
                    ? color
                    : isDisabled
                    ? AppColors.disabledBg
                    : color.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_rounded, size: 13, color: textColor),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayWordEmptyCard extends StatelessWidget {
  const _TodayWordEmptyCard();

  @override
  Widget build(BuildContext context) {
    return const AppMutedCard(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 42,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            '오늘 노출할 단어가 없습니다',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            '전체 기록 리셋을 하면 단어풀이 다시 노출됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayWordStatsCard extends StatelessWidget {
  const _TodayWordStatsCard({
    required this.knownCount,
    required this.reviewCount,
    required this.savedCount,
  });

  final int knownCount;
  final int reviewCount;
  final int savedCount;

  @override
  Widget build(BuildContext context) {
    return AppPrimaryCard(
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _statColumn(
                label: '아는 단어',
                value: '$knownCount개',
                caption: '재등장 방지',
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.onCardPrimary.withValues(alpha: 0.2),
            ),
            Expanded(
              child: _statColumn(
                label: '다시보기',
                value: '$reviewCount개',
                caption: '재노출 예정',
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.onCardPrimary.withValues(alpha: 0.2),
            ),
            Expanded(
              child: _statColumn(
                label: '총 학습 단어',
                value: '${knownCount + reviewCount}개',
                caption: '저장 $savedCount개',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statColumn({
    required String label,
    required String value,
    required String caption,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.onCardPrimary.withValues(alpha: 0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.onCardPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.onCardPrimary.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
// 내 서재 (구매한 e-Book + 저장한 HIRA 목록)
// ═══════════════════════════════════════════════════

class _MyLibraryView extends StatefulWidget {
  const _MyLibraryView();

  @override
  State<_MyLibraryView> createState() => _MyLibraryViewState();
}

class _MyLibraryViewState extends State<_MyLibraryView>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  int _lastMarkedTabIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(_markCurrentTabSeen);
    WidgetsBinding.instance.addPostFrameCallback((_) => _markCurrentTabSeen());
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_markCurrentTabSeen);
    _tabCtrl.dispose();
    super.dispose();
  }

  void _markCurrentTabSeen() {
    if (!mounted || _lastMarkedTabIndex == _tabCtrl.index) return;
    _lastMarkedTabIndex = _tabCtrl.index;
    final key = switch (_tabCtrl.index) {
      0 => ContentReadKeys.ebooks,
      1 => ContentReadKeys.savedHiraUpdates,
      2 => ContentReadKeys.savedWords,
      _ => null,
    };
    if (key != null) ContentReadStateService.markSeen(key);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 서브 탭바 → AppSegmentedControl
        StreamBuilder<Set<int>>(
          stream: ContentReadStateService.watchNewIndices(const {
            0: [ContentReadKeys.ebooks],
            1: [ContentReadKeys.savedHiraUpdates],
            2: [ContentReadKeys.savedWords],
          }),
          initialData: const {},
          builder: (context, snapshot) {
            return AppSegmentedControl(
              controller: _tabCtrl,
              labels: const ['치과책방', '저장한 변경사항', '저장한 단어'],
              newIndices: snapshot.data ?? const {},
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
            );
          },
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: const [_MyBooksTab(), _SavedHiraTab(), _SavedWordsTab()],
          ),
        ),
      ],
    );
  }
}

class _MyBooksTab extends StatefulWidget {
  const _MyBooksTab();

  @override
  State<_MyBooksTab> createState() => _MyBooksTabState();
}

class _MyBooksTabState extends State<_MyBooksTab> {
  bool _syncing = false;
  bool _loading = true;
  List<Ebook> _myBooks = [];

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadMyBooks();
      _checkAliasNotification();
    }
  }

  /// alias 이메일로 구매내역이 연결된 경우 1회 안내 다이얼로그 표시
  Future<void> _checkAliasNotification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final data = doc.data();
      if (data == null) return;

      // aliasNotified == false 이고 emailAliases 가 있을 때만 표시
      final notified = data['aliasNotified'] as bool? ?? true;
      if (notified) return;

      final aliases = List<String>.from(data['emailAliases'] as List? ?? []);
      if (aliases.isEmpty) return;

      // 안내 후 즉시 true 로 업데이트 (중복 표시 방지)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'aliasNotified': true},
      );

      if (!mounted) return;

      // 안내 다이얼로그 표시
      final aliasEmail = aliases.first;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder:
            (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                '구매 이메일 안내',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              content: Text(
                "연동 스토어에서 '$aliasEmail' 이메일로\n구매된 기록이 확인되었습니다.\n\n"
                '구매 내역은 정상적으로 연결되어 있습니다.\n'
                '앞으로는 현재 로그인한 이메일로 이용해 주세요.',
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('확인'),
                ),
              ],
            ),
      );
    } catch (e) {
      debugPrint('⚠️ alias 알림 확인 오류: $e');
    }
  }

  Future<void> _loadMyBooks() async {
    try {
      final service = context.read<EbookService>();
      final purchasedIds = await service.fetchPurchasedEbookIds();
      if (purchasedIds.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final allBooks = await service.fetchAllEbooks();
      final myBooks =
          allBooks.where((b) => purchasedIds.contains(b.id)).toList();
      if (mounted) {
        setState(() {
          _myBooks = myBooks;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ _MyBooksTab._loadMyBooks error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 아임웹 구매내역 수동 동기화
  Future<void> _syncPurchases() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final service = context.read<EbookService>();

    String? warning;
    final email =
        FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase();
    if (email?.isNotEmpty == true) {
      try {
        final doc =
            await FirebaseFirestore.instance
                .collection('imweb_sync_issues')
                .doc(email!)
                .get();
        if (doc.exists) {
          warning = doc.data()?['message'] as String?;
        }
      } catch (e) {
        debugPrint('⚠️ imweb_sync_issues 조회 실패: $e');
      }
    }

    if (warning != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(warning),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    try {
      final result = await service.syncImwebPurchases();
      final synced = result['synced'] as int? ?? 0;
      final message = result['message'] as String? ?? '동기화 완료';

      if (!mounted) return;

      if (synced > 0) {
        // 새 구매내역 발견 → 스낵바
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $message'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // 내역 없음 → 이메일 확인 안내 다이얼로그
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  '구매내역을 찾지 못했습니다',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                content: const Text(
                  '구매 시 사용한 이메일 주소로\n로그인하셨나요?\n\n'
                  '구매 시 사용한 이메일 계정으로\n로그인하면 자동으로 연결됩니다.',
                  style: TextStyle(fontSize: 14, height: 1.55),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('확인'),
                  ),
                ],
              ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('동기화 실패: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
        _loadMyBooks(); // 동기화 후 목록 새로고침
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── 동기화 버튼 배너 ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            0,
          ),
          child: InkWell(
            onTap: _syncing ? null : _syncPurchases,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.textDisabled.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.sync_rounded, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '책이 보이지 않나요?',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (_syncing)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(
                      '동기화',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        // ── 구매 도서 목록 ──────────────────────────────
        Expanded(
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _myBooks.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.menu_book_outlined,
                          size: 48,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          '등록된 책이 없습니다',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                  : RefreshIndicator(
                    onRefresh: _loadMyBooks,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      itemCount: _myBooks.length,
                      separatorBuilder:
                          (_, __) => const SizedBox(height: AppSpacing.md),
                      itemBuilder:
                          (context, i) => _MyBookTile(book: _myBooks[i]),
                    ),
                  ),
        ),
      ],
    );
  }
}

class _SavedHiraTab extends StatelessWidget {
  const _SavedHiraTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HiraUpdate>>(
      stream: HiraUpdateService.watchSavedUpdates(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final savedUpdates = snapshot.data ?? [];
        if (savedUpdates.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.bookmark_border,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '저장한 변경사항이 없습니다',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '보험정보 탭에서 항목을 저장하세요.',
                  style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.xl),
          itemCount: savedUpdates.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, i) => _SavedHiraTile(update: savedUpdates[i]),
        );
      },
    );
  }
}

class _SavedWordsTab extends StatelessWidget {
  const _SavedWordsTab();

  Map<String, List<SavedDailyWord>> _groupByCategory(
    List<SavedDailyWord> words,
  ) {
    final grouped = <String, List<SavedDailyWord>>{};
    for (final saved in words) {
      final category =
          saved.word.category.trim().isEmpty
              ? '기타'
              : saved.word.category.trim();
      grouped.putIfAbsent(category, () => []).add(saved);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SavedDailyWord>>(
      stream: DailyWordService.watchSavedWords(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final savedWords = snapshot.data ?? [];
        if (savedWords.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bookmark_border,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  '저장한 단어가 없습니다',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  '오늘 단어 탭에서 단어를 저장하세요.',
                  style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
                ),
              ],
            ),
          );
        }

        final groupedWords = _groupByCategory(savedWords);
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            for (final entry in groupedWords.entries) ...[
              Padding(
                padding: const EdgeInsets.only(
                  bottom: AppSpacing.sm,
                  top: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    _DailyWordCategoryBadge(label: entry.key),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${entry.value.length}개',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ],
                ),
              ),
              for (final saved in entry.value) ...[
                _SavedWordTile(saved: saved),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _SavedWordTile extends StatelessWidget {
  const _SavedWordTile({required this.saved});

  final SavedDailyWord saved;

  @override
  Widget build(BuildContext context) {
    final word = saved.word;
    return AppMutedCard(
      padding: const EdgeInsets.all(AppSpacing.lg - 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DailyWordCategoryBadge(label: word.category),
          const SizedBox(height: AppSpacing.sm),
          Text(
            word.english,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            word.pronunciationKo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            word.meaning,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textDisabled,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 저장한 HIRA 타일 ──────────────────────────────────────────

class _SavedHiraTile extends StatelessWidget {
  final HiraUpdate update;
  const _SavedHiraTile({required this.update});

  @override
  Widget build(BuildContext context) {
    return AppMutedCard(
      padding: const EdgeInsets.all(AppSpacing.lg - 2),
      onTap:
          () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => HiraUpdateDetailSheet(update: update),
          ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  update.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${update.publishedAt.year}.'
                  '${update.publishedAt.month.toString().padLeft(2, '0')}.'
                  '${update.publishedAt.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textDisabled,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textDisabled,
            size: 20,
          ),
        ],
      ),
    );
  }
}

// ── 내 e-Book 타일 ───────────────────────────────────────────

class _MyBookTile extends StatelessWidget {
  final Ebook book;
  const _MyBookTile({required this.book});

  @override
  Widget build(BuildContext context) {
    return AppMutedCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EbookDetailPage(ebook: book)),
          ),
      child: Row(
        children: [
          // 커버: 화면 너비 13%, 최소44·최대68, 비율 3:4
          LayoutBuilder(
            builder: (ctx, constraints) {
              final screenW = MediaQuery.of(ctx).size.width;
              final coverW = (screenW * 0.13).clamp(44.0, 68.0);
              final coverH = coverW * (4 / 3);
              return ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                child: Image.network(
                  book.coverUrl,
                  width: coverW,
                  height: coverH,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) => Container(
                        width: coverW,
                        height: coverH,
                        color: AppColors.disabledBg,
                        child: const Icon(
                          Icons.book,
                          color: AppColors.textDisabled,
                        ),
                      ),
                ),
              );
            },
          ),
          const SizedBox(width: AppSpacing.lg - 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  book.author,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textDisabled,
            size: 20,
          ),
        ],
      ),
    );
  }
}
