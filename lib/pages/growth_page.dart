import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ebook.dart';
import '../models/hira_update.dart';
import '../services/ebook_service.dart';
import '../services/hira_update_service.dart';
import '../widgets/hira_update_detail_sheet.dart';
import 'ebook/ebook_detail_page.dart';
import 'quiz_today_page.dart';
import 'hira_update_page.dart';
import 'settings/settings_page.dart';
import '../core/theme/app_colors.dart';

// ── 디자인 팔레트: AppColors 참조 ──
// 색상 변경 → app_colors.dart Primitive만 수정하면 자동 반영
const _kText    = AppColors.textPrimary;   // Black
const _kBg      = AppColors.appBg;         // Soft gray
const _kCardBg  = AppColors.surfaceMuted;  // Muted surface 카드 배경

/// 성장 탭 (3탭)
///
/// 내부 소탭 4개:
/// 1. 오늘의 퀴즈 — 매일 2문제
/// 2. 급여변경 — HIRA 수가/급여 변경 포인트
/// 3. 치과책방 — e-Book 스토어
/// 4. 내 서재 — 구매한 e-Book 목록
class GrowthPage extends StatefulWidget {
  /// 서브탭 점프용 notifier (HomeShell에서 주입, 값이 바뀌면 해당 탭으로 이동)
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
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── 상단 헤더 ──
            _buildHeader(),

            // ── 탭 바 ──
            _buildTabBar(),

            // ── 탭 뷰 ──
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.info_outline,
                  color: _kText.withOpacity(0.5),
                  size: 18,
                ),
                onPressed: () => _showConceptDialog(context),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  color: _kText.withOpacity(0.4),
                  size: 20,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(
            '성장하기',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _kText,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(
            '오늘도 하나씩, 꾸준히 성장해요.',
            style: TextStyle(fontSize: 12, color: _kText.withOpacity(0.55)),
          ),
        ),
        const SizedBox(height: 8),
      ],
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

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
          color: AppColors.accent,  // Blue 인디케이터
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(3),
        dividerColor: Colors.transparent,
        labelColor: AppColors.onAccent,    // Blue 위 → White
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        tabs: const [
          Tab(text: '오늘 퀴즈'),
          Tab(text: '제도 변경'),
          Tab(text: '치과책방'),
          Tab(text: '내 서재'),
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
        // 서브 탭바
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabCtrl,
            indicator: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.surfaceMuted.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: _kText,
            unselectedLabelColor: _kText.withOpacity(0.5),
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [Tab(text: '전자책'), Tab(text: '저장한 변경사항')],
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
                Icon(Icons.menu_book_outlined, size: 48, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                Text(
                  '구매한 도서가 없습니다.',
                  style: TextStyle(
                    color: _kText.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '치과책방에서 도서를 만나보세요.',
                  style: TextStyle(
                    color: _kText.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        // 구매한 ebook 목록을 전체 ebook 스트림에서 필터
        return StreamBuilder<List<Ebook>>(
          stream: service.watchEbooks(),
          builder: (context, allSnap) {
            if (!allSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final myBooks =
                allSnap.data!
                    .where((b) => purchasedIds.contains(b.id))
                    .toList();

            if (myBooks.isEmpty) {
              return Center(
                child: Text(
                  '도서 정보를 불러오는 중...',
                  style: TextStyle(
                    color: _kText.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: myBooks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final book = myBooks[i];
                return _MyBookTile(book: book);
              },
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
                Icon(Icons.bookmark_border, size: 48, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                Text(
                  '저장한 변경사항이 없습니다',
                  style: TextStyle(
                    fontSize: 14,
                    color: _kText.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '제도 변경 탭에서 항목을 저장하세요.',
                  style: TextStyle(
                    fontSize: 12,
                    color: _kText.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: savedUpdates.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final update = savedUpdates[i];
            return _SavedHiraTile(update: update);
          },
        );
      },
    );
  }
}

class _SavedHiraTile extends StatelessWidget {
  final HiraUpdate update;
  const _SavedHiraTile({required this.update});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => HiraUpdateDetailSheet(update: update),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 20, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    update.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kText,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${update.publishedAt.year}.${update.publishedAt.month.toString().padLeft(2, '0')}.${update.publishedAt.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 11,
                      color: _kText.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.accent, size: 20),
          ],
        ),
      ),
    );
  }
}

class _MyBookTile extends StatelessWidget {
  final Ebook book;
  const _MyBookTile({required this.book});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EbookDetailPage(ebook: book)),
          ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // 커버 이미지: 화면 너비의 13% 기준, 최소44·최대68 clamp, 비율 3:4 유지
            LayoutBuilder(
              builder: (ctx, constraints) {
                final screenW = MediaQuery.of(ctx).size.width;
                final coverW = (screenW * 0.13).clamp(44.0, 68.0);
                final coverH = coverW * (4 / 3); // 3:4 비율
                return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                book.coverUrl,
                    width: coverW,
                    height: coverH,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Container(
                          width: coverW,
                          height: coverH,
                      color: AppColors.surfaceMuted,
                      child: Icon(Icons.book, color: _kText.withOpacity(0.3)),
                    ),
              ),
                );
              },
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author,
                    style: TextStyle(
                      fontSize: 12,
                      color: _kText.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: _kText.withOpacity(0.3), size: 20),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// 치과책방 (e-Book 스토어 — 기존 StoreTab 내용)
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
              style: TextStyle(color: _kText.withOpacity(0.6), fontSize: 14),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            childAspectRatio: 0.66,
          ),
          itemCount: books.length,
          itemBuilder: (context, i) {
            final b = books[i];
            return GestureDetector(
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EbookDetailPage(ebook: b),
                    ),
                  ),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          b.coverUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder:
                              (_, __, ___) => Container(
                                color: AppColors.surfaceMuted,
                                child: Icon(
                                  Icons.image,
                                  color: _kText.withOpacity(0.3),
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    b.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _kText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
