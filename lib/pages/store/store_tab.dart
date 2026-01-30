// lib/pages/store/store_tab.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/ebook_service.dart';
import '../../services/iap_service.dart';
import '../../models/ebook.dart';
import '../ebook/ebook_detail_page.dart';

class StoreTab extends StatefulWidget {
  const StoreTab({super.key});

  @override
  State<StoreTab> createState() => _StoreTabState();
}

class _StoreTabState extends State<StoreTab> {
  bool _showMyLibrary = false; // false: 스토어, true: 내 서재

  void _switchToStore() {
    setState(() => _showMyLibrary = false);
  }

  @override
  Widget build(BuildContext context) {
    final service = EbookService();
    final iapService = IapService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('e-Book'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 세그먼트 토글
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: _SegmentButton(
                      label: '스토어',
                      icon: Icons.storefront,
                      isSelected: !_showMyLibrary,
                      onTap: () => setState(() => _showMyLibrary = false),
                    ),
                  ),
                  Expanded(
                    child: _SegmentButton(
                      label: '내 서재',
                      icon: Icons.library_books,
                      isSelected: _showMyLibrary,
                      onTap: () => setState(() => _showMyLibrary = true),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 콘텐츠
          Expanded(
            child: _showMyLibrary
                ? _MyLibraryView(service: service, iapService: iapService)
                : _StoreView(service: service),
          ),
        ],
      ),
    );
  }
}

/// 세그먼트 버튼 위젯
class _SegmentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.brown[700] : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.brown[700] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 스토어 뷰 (전체 책 목록 + 큐레이션)
class _StoreView extends StatelessWidget {
  final EbookService service;

  const _StoreView({required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Ebook>>(
      stream: service.watchEbooks(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final books = snap.data ?? [];
        if (books.isEmpty) {
          return const Center(child: Text('등록된 전자책이 없습니다.'));
        }

        // 카테고리별 분류
        final freeBooks = books.where((b) => b.price == 0).toList();
        final newBooks = books.toList()
          ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        final recentBooks = newBooks.take(5).toList();

        return RefreshIndicator(
          onRefresh: () async {},
          child: CustomScrollView(
            slivers: [
              // 배너/히어로 섹션
              SliverToBoxAdapter(
                child: _buildHeroBanner(context, books.isNotEmpty ? books.first : null),
              ),

              // 신간 섹션
              if (recentBooks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildSectionHeader('📚 신간 도서', null),
                ),
                SliverToBoxAdapter(
                  child: _buildHorizontalBookList(context, recentBooks),
                ),
              ],

              // 무료 책 섹션
              if (freeBooks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildSectionHeader('🎁 무료 도서', null),
                ),
                SliverToBoxAdapter(
                  child: _buildHorizontalBookList(context, freeBooks),
                ),
              ],

              // 전체 책 그리드
              SliverToBoxAdapter(
                child: _buildSectionHeader('📖 전체 도서', '${books.length}권'),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _BookCard(book: books[i]),
                    childCount: books.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.55,
                  ),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          ),
        );
      },
    );
  }

  /// 히어로 배너
  Widget _buildHeroBanner(BuildContext context, Ebook? featuredBook) {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Colors.brown[700]!, Colors.brown[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // 배경 패턴
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.menu_book,
              size: 120,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          // 콘텐츠
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '치과 전문 전자책 📖',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '치과인을 위한 전문 도서를\n언제 어디서나 편리하게',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '신간 보러가기 →',
                    style: TextStyle(
                      color: Colors.brown[700],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 섹션 헤더
  Widget _buildSectionHeader(String title, String? count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (count != null)
            Text(
              count,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
    );
  }

  /// 수평 책 리스트 (큐레이션용)
  Widget _buildHorizontalBookList(BuildContext context, List<Ebook> books) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: books.length,
        itemBuilder: (context, i) {
          final book = books[i];
          return Container(
            width: 120,
            margin: EdgeInsets.only(right: i < books.length - 1 ? 12 : 0),
            child: _MiniBookCard(book: book),
          );
        },
      ),
    );
  }
}

/// 내 서재 뷰 (구매한 책 목록 + 정렬/진행률)
class _MyLibraryView extends StatefulWidget {
  final EbookService service;
  final IapService iapService;

  const _MyLibraryView({required this.service, required this.iapService});

  @override
  State<_MyLibraryView> createState() => _MyLibraryViewState();
}

class _MyLibraryViewState extends State<_MyLibraryView> {
  String _sortBy = 'recent'; // 'recent', 'title', 'progress'

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.login, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('로그인이 필요합니다'),
          ],
        ),
      );
    }

    return StreamBuilder<List<Ebook>>(
      stream: widget.service.watchEbooks(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allBooks = snap.data ?? [];
        // 구매한 책만 필터링
        var purchasedBooks = allBooks.where((book) {
          return book.price == 0 || widget.iapService.isPurchased(book.productId);
        }).toList();

        // 정렬 적용
        purchasedBooks = _sortBooks(purchasedBooks);

        if (purchasedBooks.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.library_books, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text('구매한 책이 없습니다'),
                const SizedBox(height: 8),
                Text(
                  '스토어에서 책을 구매해보세요!',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    _StoreTabState? state;
                    context.visitAncestorElements((element) {
                      if (element is StatefulElement && element.state is _StoreTabState) {
                        state = element.state as _StoreTabState;
                        return false;
                      }
                      return true;
                    });
                    state?._switchToStore();
                  },
                  icon: const Icon(Icons.storefront),
                  label: const Text('스토어 가기'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // 정렬 필터 바
            _buildSortBar(purchasedBooks.length),
            
            // 책 리스트
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: purchasedBooks.length,
                itemBuilder: (context, i) {
                  final book = purchasedBooks[i];
                  return _LibraryBookCard(book: book);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  List<Ebook> _sortBooks(List<Ebook> books) {
    switch (_sortBy) {
      case 'title':
        return books..sort((a, b) => a.title.compareTo(b.title));
      case 'progress':
        // TODO: 실제 진행률 데이터로 정렬 (현재는 랜덤)
        return books;
      case 'recent':
      default:
        return books..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    }
  }

  Widget _buildSortBar(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '총 $count권',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          // 정렬 드롭다운
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                icon: const Icon(Icons.sort, size: 18),
                style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                items: const [
                  DropdownMenuItem(value: 'recent', child: Text('최근 추가순')),
                  DropdownMenuItem(value: 'title', child: Text('제목순')),
                  DropdownMenuItem(value: 'progress', child: Text('읽는 중')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _sortBy = value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 미니 책 카드 (수평 스크롤용)
class _MiniBookCard extends StatelessWidget {
  final Ebook book;

  const _MiniBookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EbookDetailPage(ebook: book)),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 표지
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  book.coverUrl.isNotEmpty
                      ? Image.network(
                          book.coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _PlaceholderCover(),
                        )
                      : const _PlaceholderCover(),
                  // 무료 뱃지
                  if (book.price == 0)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '무료',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 제목
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// 스토어용 책 카드 (그리드)
class _BookCard extends StatelessWidget {
  final Ebook book;

  const _BookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EbookDetailPage(ebook: book)),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 표지 이미지 (비율 유지)
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 0.7, // 일반적인 책 표지 비율 (가로:세로 = 7:10)
                child: book.coverUrl.isNotEmpty
                    ? Image.network(
                        book.coverUrl,
                        fit: BoxFit.contain, // 비율 유지
                        alignment: Alignment.center,
                        errorBuilder: (_, __, ___) => const _PlaceholderCover(),
                      )
                    : const _PlaceholderCover(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 제목
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          // 가격
          Text(
            book.price == 0 ? '무료' : '${_formatPrice(book.price)}원',
            style: TextStyle(
              fontSize: 12,
              color: book.price == 0 ? Colors.green[700] : Colors.brown[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}

/// 내 서재용 책 카드 (리스트 + 진행률)
class _LibraryBookCard extends StatelessWidget {
  final Ebook book;

  const _LibraryBookCard({required this.book});

  // TODO: 실제 진행률 데이터 연동
  double get _readProgress => 0.0; // 0.0 ~ 1.0

  @override
  Widget build(BuildContext context) {
    final progressPercent = (_readProgress * 100).toInt();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EbookDetailPage(ebook: book)),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 표지 (비율 유지) + 진행률 오버레이
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 70,
                      height: 100,
                      child: book.coverUrl.isNotEmpty
                          ? Image.network(
                              book.coverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const _PlaceholderCover(small: true),
                            )
                          : const _PlaceholderCover(small: true),
                    ),
                  ),
                  // 진행률 바 (하단)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                        color: Colors.black.withOpacity(0.3),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _readProgress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 진행률 표시
                    Row(
                      children: [
                        Icon(
                          _readProgress > 0 ? Icons.auto_stories : Icons.book_outlined,
                          size: 14,
                          color: _readProgress > 0 ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _readProgress > 0 ? '$progressPercent% 읽음' : '읽지 않음',
                          style: TextStyle(
                            fontSize: 11,
                            color: _readProgress > 0 ? Colors.green[700] : Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 읽기 버튼
                    SizedBox(
                      height: 32,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EbookDetailPage(ebook: book)),
                        ),
                        icon: Icon(
                          _readProgress > 0 ? Icons.play_arrow : Icons.menu_book,
                          size: 16,
                        ),
                        label: Text(
                          _readProgress > 0 ? '이어 읽기' : '읽기 시작',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 표지 없을 때 플레이스홀더
class _PlaceholderCover extends StatelessWidget {
  final bool small;

  const _PlaceholderCover({this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.book,
          size: small ? 24 : 48,
          color: Colors.grey[400],
        ),
      ),
    );
  }
}
