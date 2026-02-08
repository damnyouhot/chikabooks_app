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
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text(
          'e-Book Store',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // 세그먼트 토글
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  Expanded(
                    child: _SegmentButton(
                      label: '스토어',
                      icon: Icons.storefront_rounded,
                      isSelected: !_showMyLibrary,
                      onTap: () => setState(() => _showMyLibrary = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SegmentButton(
                      label: '내 서재',
                      icon: Icons.library_books_rounded,
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
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C63FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : Colors.grey[400],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

        final freeBooks = books.where((b) => b.price == 0).toList();
        final newBooks = books.toList()
          ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        final recentBooks = newBooks.take(5).toList();

        return RefreshIndicator(
          onRefresh: () async {},
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeroBanner(context),
              ),
              if (recentBooks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildSectionHeader('📚 신간 도서', null),
                ),
                SliverToBoxAdapter(
                  child: _buildHorizontalBookList(context, recentBooks),
                ),
              ],
              if (freeBooks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildSectionHeader('🎁 무료 도서', null),
                ),
                SliverToBoxAdapter(
                  child: _buildHorizontalBookList(context, freeBooks),
                ),
              ],
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

  Widget _buildHeroBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF8E87FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            bottom: -30,
            child: Icon(
              Icons.auto_stories_rounded,
              size: 180,
              color: Colors.white.withOpacity(0.15),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '치과 전문 전자책 📖',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '치과인을 위한 전문 도서를\n언제 어디서나 편리하게',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String? count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (count != null)
            Text(
              count,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
        ],
      ),
    );
  }

  Widget _buildHorizontalBookList(BuildContext context, List<Ebook> books) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: books.length,
        itemBuilder: (context, i) {
          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 12),
            child: _MiniBookCard(book: books[i]),
          );
        },
      ),
    );
  }
}

class _MyLibraryView extends StatefulWidget {
  final EbookService service;
  final IapService iapService;
  const _MyLibraryView({required this.service, required this.iapService});

  @override
  State<_MyLibraryView> createState() => _MyLibraryViewState();
}

class _MyLibraryViewState extends State<_MyLibraryView> {
  String _sortBy = 'recent';

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('로그인이 필요합니다'));

    return StreamBuilder<List<String>>(
      stream: widget.service.watchPurchasedEbookIds(),
      builder: (context, purchasedSnap) {
        final purchasedIds = purchasedSnap.data ?? [];
        return StreamBuilder<List<Ebook>>(
          stream: widget.service.watchEbooks(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final allBooks = snap.data ?? [];
            final purchasedBooks = allBooks.where((book) {
              return book.price == 0 || purchasedIds.contains(book.id);
            }).toList();

            if (purchasedBooks.isEmpty) {
              return const Center(child: Text('구매한 책이 없습니다'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: purchasedBooks.length,
              itemBuilder: (context, i) => _LibraryBookCard(book: purchasedBooks[i]),
            );
          },
        );
      },
    );
  }
}

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: book.coverUrl.isNotEmpty
                  ? Image.network(book.coverUrl, fit: BoxFit.cover)
                  : Container(color: Colors.grey[200]),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

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
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: book.coverUrl.isNotEmpty
                    ? Image.network(book.coverUrl, fit: BoxFit.cover)
                    : Container(color: Colors.grey[200]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                book.title,
                maxLines: 2,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryBookCard extends StatelessWidget {
  final Ebook book;
  const _LibraryBookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: book.coverUrl.isNotEmpty
              ? Image.network(book.coverUrl, width: 50, fit: BoxFit.cover)
              : Container(width: 50, color: Colors.grey[200]),
        ),
        title: Text(book.title),
        subtitle: Text(book.author),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EbookDetailPage(ebook: book)),
        ),
      ),
    );
  }
}
