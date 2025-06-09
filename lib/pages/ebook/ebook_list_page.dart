// lib/pages/ebook/ebook_list_page.dart
import 'package:flutter/material.dart';
import '../../models/ebook.dart';
import '../../services/ebook_service.dart';
import 'ebook_detail_page.dart';

class EbookListPage extends StatelessWidget {
  const EbookListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = EbookService();

    return StreamBuilder<List<Ebook>>(
      stream: service.watchEbooks(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final books = snap.data ?? [];
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (_, i) {
            final b = books[i];
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(b.coverUrl, width: 56, fit: BoxFit.cover),
              ),
              title: Text(b.title),
              subtitle: Text(b.author),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EbookDetailPage(ebook: b)),
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: books.length,
        );
      },
    );
  }
}
