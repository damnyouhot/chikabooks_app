// lib/pages/growth/study/ebook_detail_page.dart

import 'package:flutter/material.dart';
import '../../../models/ebook.dart';
import 'epub_reader_page.dart';

class EbookDetailPage extends StatelessWidget {
  final Ebook ebook;
  // ▼▼▼ 생성자를 super parameter로 수정 ▼▼▼
  const EbookDetailPage({super.key, required this.ebook});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(ebook.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Image.network(
                ebook.coverUrl,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => const Icon(Icons.image_not_supported),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              ebook.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('저자: ${ebook.author}'),
            const SizedBox(height: 8),
            Text(
              '출간일: ${ebook.publishedAt.toLocal().toString().split(' ')[0]}',
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  ebook.description,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  if (ebook.fileUrl.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ePub 파일 URL이 없습니다.')),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EpubReaderPage(ebook: ebook),
                    ),
                  );
                },
                child: Text(ebook.price == 0 ? '무료로 보기' : '${ebook.price}원 구매'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
