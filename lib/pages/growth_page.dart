import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ebook.dart';
import '../models/hira_update.dart';
import '../services/ebook_service.dart';
import '../services/hira_update_service.dart';
import '../widgets/hira_update_detail_sheet.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_muted_card.dart';
import '../core/widgets/app_segmented_control.dart';
import 'ebook/ebook_detail_page.dart';
import 'quiz_today_page.dart';
import 'hira_update_page.dart';
import 'settings/settings_page.dart';

/// 성장 탭 (3탭)
///
/// 내부 소탭 4개:
/// 1. 오늘의 퀴즈 — 매일 2문제
/// 2. 급여변경 — HIRA 수가/급여 변경 포인트
/// 3. 치과책방 — e-Book 스토어
/// 4. 내 서재 — 구매한 e-Book 목록
class GrowthPage extends StatefulWidget {
  final ValueNotifier<int>? subTabNotifier;

  const GrowthPage({super.key, this.subTabNotifier});

  @override
  State<GrowthPage> createState() => _GrowthPageState();
}

class _GrowthPageState extends State<GrowthPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    widget.subTabNotifier?.addListener(_onSubTabChanged);
  }

  void _onSubTabChanged() {
    final idx = widget.subTabNotifier?.value ?? -1;
    if (idx >= 0 && idx < 4) {
      _tabCtrl.animateTo(idx);
    }
  }

  @override
  void dispose() {
    widget.subTabNotifier?.removeListener(_onSubTabChanged);
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            // 세그먼트 탭바 → AppSegmentedControl
            AppSegmentedControl(
              controller: _tabCtrl,
              labels: const ['오늘 퀴즈', '제도 변경', '치과책방', '내 서재'],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: const [
                  QuizTodayPage(),
                  HiraUpdatePage(),
                  _BookStoreBrowseView(),
                  _MyLibraryView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 타이틀 + 아이콘 (한 행으로 통합) ──
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xl, right: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                '성장하기',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
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
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                ),
              ),
            ],
          ),
        ),
        // ── 서브타이틀 ──
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xl),
          child: Text(
            '오늘도 하나씩, 꾸준히 성장해요.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  void _showConceptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
            title: const Text(
              '성장하기 탭에 대해서',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            content: const SingleChildScrollView(
              child: Text('', style: TextStyle(fontSize: 13, height: 1.6)),
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

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 서브 탭바 → AppSegmentedControl
        AppSegmentedControl(
            controller: _tabCtrl,
          labels: const ['전자책', '저장한 변경사항'],
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: const [_MyBooksTab(), _SavedHiraTab()],
          ),
        ),
      ],
    );
  }
}

class _MyBooksTab extends StatelessWidget {
  const _MyBooksTab();

  @override
  Widget build(BuildContext context) {
    final service = context.read<EbookService>();

    return StreamBuilder<List<String>>(
      stream: service.watchPurchasedEbookIds(),
      builder: (context, purchaseSnap) {
        if (purchaseSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final purchasedIds = purchaseSnap.data ?? [];
        if (purchasedIds.isEmpty) {
          return Center(
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
                  '구매한 도서가 없습니다.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '치과책방에서 도서를 만나보세요.',
                  style: TextStyle(
                    color: AppColors.textDisabled,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        return StreamBuilder<List<Ebook>>(
          stream: service.watchEbooks(),
          builder: (context, allSnap) {
            if (!allSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final myBooks = allSnap.data!
                    .where((b) => purchasedIds.contains(b.id))
                    .toList();

            if (myBooks.isEmpty) {
              return Center(
                  child: Text(
                  '도서 정보를 불러오는 중...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.xl),
              itemCount: myBooks.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) => _MyBookTile(book: myBooks[i]),
            );
          },
        );
      },
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
                  '제도 변경 탭에서 항목을 저장하세요.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textDisabled,
                  ),
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

// ── 저장한 HIRA 타일 ──────────────────────────────────────────

class _SavedHiraTile extends StatelessWidget {
  final HiraUpdate update;
  const _SavedHiraTile({required this.update});

  @override
  Widget build(BuildContext context) {
    return AppMutedCard(
      padding: const EdgeInsets.all(AppSpacing.lg - 2),
      onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => HiraUpdateDetailSheet(update: update),
        ),
        child: Row(
          children: [
          const Icon(
            Icons.info_outline,
            size: 20,
            color: AppColors.accent,
          ),
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
      onTap: () => Navigator.push(
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
                  errorBuilder: (_, __, ___) => Container(
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

// ═══════════════════════════════════════════════════
// 치과책방 (e-Book 스토어)
// ═══════════════════════════════════════════════════

class _BookStoreBrowseView extends StatelessWidget {
  const _BookStoreBrowseView();

  @override
  Widget build(BuildContext context) {
    final service = context.read<EbookService>();

    return StreamBuilder<List<Ebook>>(
      stream: service.watchEbooks(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final books = snap.data ?? [];
        if (books.isEmpty) {
          return Center(
            child: Text(
              '등록된 전자책이 없습니다.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            childAspectRatio: 0.66,
          ),
          itemCount: books.length,
          itemBuilder: (context, i) => _BookGridTile(book: books[i]),
        );
      },
    );
  }
}

class _BookGridTile extends StatelessWidget {
  final Ebook book;
  const _BookGridTile({required this.book});

  @override
  Widget build(BuildContext context) {
            return GestureDetector(
      onTap: () => Navigator.push(
                    context,
        MaterialPageRoute(builder: (_) => EbookDetailPage(ebook: book)),
                  ),
              child: Column(
                children: [
                  Expanded(
                      child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.md),
                        child: Image.network(
                book.coverUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.disabledBg,
                  child: const Icon(
                                  Icons.image,
                    color: AppColors.textDisabled,
                                ),
                              ),
                        ),
                      ),
                    ),
          const SizedBox(height: AppSpacing.sm),
                  Text(
            book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
    );
  }
}
