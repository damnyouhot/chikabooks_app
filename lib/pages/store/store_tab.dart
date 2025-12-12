// lib/pages/store/store_tab.dart
import 'package:flutter/material.dart';
import '../../services/ebook_service.dart';
import '../../models/ebook.dart';
import '../ebook/ebook_detail_page.dart';

class StoreTab extends StatelessWidget {
  const StoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final service = EbookService();

    return Scaffold(
      appBar: AppBar(title: const Text('e-Book 스토어')),
      body: StreamBuilder<List<Ebook>>(
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
                childAspectRatio: 0.66,
              ),
              itemCount: books.length,
              itemBuilder: (context, i) {
                final b = books[i];
                return InkWell(
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child:
                              b.coverUrl.isNotEmpty
                                  ? Image.network(
                                    b.coverUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder:
                                        (_, __, ___) => Container(
                                          color: Colors.grey[300],
                                          child: const Icon(
                                            Icons.book,
                                            size: 48,
                                          ),
                                        ),
                                  )
                                  : Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.book, size: 48),
                                  ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        b.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
