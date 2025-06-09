// lib/pages/growth/study/ebook_list_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/ebook.dart';
import '../../../services/ebook_service.dart';
import 'ebook_detail_page.dart';

class EbookListPage extends StatelessWidget {
  const EbookListPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Provider로 등록된 EbookService 인스턴스를 읽어옵니다.
    final service = context.read<EbookService>();

    return StreamBuilder<List<Ebook>>(
      // 서비스에서 제공하는 스트림: 전체 전자책 리스트를 실시간으로 감시
      stream: service.watchEbooks(),
      builder: (context, snap) {
        // 오류가 있으면 화면에 메시지 표시
        if (snap.hasError) {
          return Center(child: Text('오류: ${snap.error}'));
        }
        // 데이터가 아직 로드되지 않았으면 로딩 인디케이터 표시
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final list = snap.data!;
        // eBook이 하나도 없다면
        if (list.isEmpty) {
          return const Center(child: Text('등록된 전자책이 없습니다.'));
        }

        // 실제로 가져온 전자책 리스트를 ListView로 렌더링
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final ebook = list[i];
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  ebook.coverUrl,
                  width: 48,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.image_not_supported),
                ),
              ),
              title: Text(ebook.title),
              subtitle: Text(ebook.price == 0 ? '무료' : '${ebook.price}원'),
              // ────────────────────────────────────────────────
              // 카드를 탭하면 상세페이지로 이동
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EbookDetailPage(ebook: ebook),
                  ),
                );
              },
              // ────────────────────────────────────────────────
            );
          },
        );
      },
    );
  }
}
