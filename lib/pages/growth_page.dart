import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ebook.dart';
import '../services/ebook_service.dart';
import 'ebook/ebook_detail_page.dart';
import 'quiz_today_page.dart';

// ── 디자인 팔레트 (2탭과 통일) ──
const _kText = Color(0xFF5D6B6B);
const _kBg = Color(0xFFF1F7F7);
const _kShadow1 = Color(0xFFDDD3D8);
const _kShadow2 = Color(0xFFD5E5E5);
const _kCardBg = Colors.white;

/// 성장 탭 (3탭)
///
/// 내부 소탭 3개:
/// 1. 오늘의 퀴즈 — 매일 2문제
/// 2. 내 서재 — 구매한 e-Book 목록
/// 3. 치과책방 — e-Book 스토어
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
    _tabCtrl = TabController(length: 3, vsync: this);
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
                  _MyLibraryView(),
                  _BookStoreBrowseView(),
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
          Tab(text: '내 서재'),
          Tab(text: '치과책방'),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// 내 서재 (구매한 e-Book 목록)
// ═══════════════════════════════════════════════════

class _MyLibraryView extends StatelessWidget {
  const _MyLibraryView();

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


