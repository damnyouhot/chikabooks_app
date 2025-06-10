import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/ebook.dart';
import '../../../services/ebook_service.dart';
import '../../../widgets/shimmer_list_tile.dart'; // ◀◀◀ 쉬머 위젯 import
import 'ebook_detail_page.dart';

class EbookListPage extends StatelessWidget {
  const EbookListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EbookService>();

    return StreamBuilder<List<Ebook>>(
      stream: service.watchEbooks(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('오류: ${snap.error}'));
        }
        if (snap.connectionState == ConnectionState.waiting || !snap.hasData) {
          // ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼ 로딩 UI를 쉬머 효과로 교체 ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 7,
            itemBuilder: (_, __) => const ShimmerListTile(),
          );
          // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲ 로딩 UI를 쉬머 효과로 교체 ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
        }

        final list = snap.data!;
        if (list.isEmpty) {
          return const Center(child: Text('등록된 전자책이 없습니다.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final ebook = list[i];
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  ebook.coverUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.image_not_supported),
                ),
              ),
              title: Text(ebook.title),
              subtitle: Text(ebook.author),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => EbookDetailPage(ebook: ebook)),
                );
              },
            );
          },
        );
      },
    );
  }
}
