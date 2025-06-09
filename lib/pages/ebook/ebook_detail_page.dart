// lib/pages/ebook/ebook_detail_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/ebook.dart';
import 'epub_reader_page.dart';

class EbookDetailPage extends StatelessWidget {
  final Ebook ebook;
  const EbookDetailPage({super.key, required this.ebook});

  @override
  Widget build(BuildContext context) {
    final priceText = ebook.price == 0
        ? '무료'
        : '${NumberFormat.decimalPattern().format(ebook.price)}원';

    return Scaffold(
      appBar: AppBar(title: Text(ebook.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  ebook.coverUrl,
                  width: 200,
                  height: 300,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              ebook.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('저자: ${ebook.author}'),
            const SizedBox(height: 16),
            Text(ebook.description),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  // 👉 추후 IAP 연결 지점
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EpubReaderPage(ebook: ebook),
                    ),
                  );
                },
                child:
                    Text(ebook.price == 0 ? '바로 읽기' : '$priceText • 구매 후 읽기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
