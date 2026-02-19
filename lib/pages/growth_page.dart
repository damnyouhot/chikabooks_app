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

// ── 디자인 팔레트 (2탭과 통일) ──
const _kText = Color(0xFF5D6B6B);
const _kBg = Color(0xFFF1F7F7);
const _kShadow1 = Color(0xFFDDD3D8);
const _kShadow2 = Color(0xFFD5E5E5);
const _kCardBg = Colors.white;

/// 성장 탭 (3탭)
///
/// 내부 소탭 4개:
/// 1. 오늘의 퀴즈 — 매일 2문제
/// 2. 급여변경 — HIRA 수가/급여 변경 포인트
/// 3. 치과책방 — e-Book 스토어
/// 4. 내 서재 — 구매한 e-Book 목록
class GrowthPage extends StatefulWidget {
  const GrowthPage({super.key});

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
  }

  @override
  void dispose() {
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
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '성장',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _kText,
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: _kShadow2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kShadow1, width: 0.5),
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: _kShadow1.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(3),
        dividerColor: Colors.transparent,
        labelColor: _kText,
        unselectedLabelColor: _kText.withOpacity(0.4),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        tabs: const [
          Tab(text: '퀴즈'),
          Tab(text: '급여변경'),
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
            color: _kShadow2.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabCtrl,
            indicator: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: _kShadow1.withOpacity(0.1),
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
            tabs: const [
              Tab(text: '전자책'),
              Tab(text: '저장한 변경사항'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: const [
              _MyBooksTab(),
              _SavedHiraTab(),
            ],
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
                Icon(Icons.menu_book_outlined,
                    size: 48, color: _kShadow1),
                const SizedBox(height: 12),
                Text(
                  '구매한 도서가 없습니다.',
                  style: TextStyle(color: _kText.withOpacity(0.6), fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '치과책방에서 도서를 만나보세요.',
                  style: TextStyle(color: _kText.withOpacity(0.4), fontSize: 12),
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
            final myBooks = allSnap.data!
                .where((b) => purchasedIds.contains(b.id))
                .toList();

            if (myBooks.isEmpty) {
              return Center(
                child: Text(
                  '도서 정보를 불러오는 중...',
                  style: TextStyle(color: _kText.withOpacity(0.6), fontSize: 14),
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
                Icon(Icons.bookmark_border,
                    size: 48, color: _kShadow1),
                const SizedBox(height: 12),
                Text(
                  '저장한 변경사항이 없습니다',
                  style: TextStyle(fontSize: 14, color: _kText.withOpacity(0.6)),
                ),
                const SizedBox(height: 4),
                Text(
                  '급여변경 탭에서 항목을 저장하세요.',
                  style: TextStyle(fontSize: 12, color: _kText.withOpacity(0.4)),
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
          border: Border.all(color: _kShadow2, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: _kShadow1.withOpacity(0.15),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 20,
              color: _kText.withOpacity(0.5),
            ),
            const SizedBox(width: 12),
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
                      color: _kText,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${update.publishedAt.year}.${update.publishedAt.month.toString().padLeft(2, '0')}.${update.publishedAt.day.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 11, color: _kText.withOpacity(0.5)),
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

class _MyBookTile extends StatelessWidget {
  final Ebook book;
  const _MyBookTile({required this.book});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EbookDetailPage(ebook: book)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kShadow2, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: _kShadow1.withOpacity(0.15),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                book.coverUrl,
                width: 52,
                height: 68,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 52,
                  height: 68,
                  color: _kShadow2,
                  child: Icon(Icons.book, color: _kText.withOpacity(0.3)),
                ),
              ),
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
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author,
                    style: TextStyle(fontSize: 12, color: _kText.withOpacity(0.5)),
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
              onTap: () => Navigator.push(
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
                        border: Border.all(color: _kShadow2, width: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: _kShadow1.withOpacity(0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          b.coverUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => Container(
                            color: _kShadow2,
                            child: Icon(Icons.image, color: _kText.withOpacity(0.3)),
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
                    style: const TextStyle(
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


