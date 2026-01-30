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

/// 스토어 뷰 (전체 책 목록)
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

        return RefreshIndicator(
          onRefresh: () async {},
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio: 0.55, // 책 표지 비율에 맞게 조정
            ),
            itemCount: books.length,
            itemBuilder: (context, i) => _BookCard(book: books[i]),
          ),
        );
      },
    );
  }
}

/// 내 서재 뷰 (구매한 책 목록)
class _MyLibraryView extends StatelessWidget {
  final EbookService service;
  final IapService iapService;

  const _MyLibraryView({required this.service, required this.iapService});

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
      stream: service.watchEbooks(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allBooks = snap.data ?? [];
        // 구매한 책만 필터링
        final purchasedBooks = allBooks.where((book) {
          // 무료 책이거나 구매한 책
          return book.price == 0 || iapService.isPurchased(book.productId);
        }).toList();

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
                    // 부모 위젯의 상태를 변경하기 위해 콜백 사용
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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: purchasedBooks.length,
          itemBuilder: (context, i) {
            final book = purchasedBooks[i];
            return _LibraryBookCard(book: book);
          },
        );
      },
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
                        errorBuilder: (_, __, ___) => _PlaceholderCover(),
                      )
                    : _PlaceholderCover(),
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

/// 내 서재용 책 카드 (리스트)
class _LibraryBookCard extends StatelessWidget {
  final Ebook book;

  const _LibraryBookCard({required this.book});

  @override
  Widget build(BuildContext context) {
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
              // 표지 (비율 유지)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 85,
                  child: book.coverUrl.isNotEmpty
                      ? Image.network(
                          book.coverUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => _PlaceholderCover(small: true),
                        )
                      : _PlaceholderCover(small: true),
                ),
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
                    const SizedBox(height: 8),
                    // 읽기 버튼
                    SizedBox(
                      height: 32,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EbookDetailPage(ebook: book)),
                        ),
                        icon: const Icon(Icons.menu_book, size: 16),
                        label: const Text('읽기', style: TextStyle(fontSize: 12)),
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
