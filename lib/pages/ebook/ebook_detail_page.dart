// lib/pages/ebook/ebook_detail_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/ebook.dart';
import 'epub_reader_page.dart';
import 'pdf_reader_page.dart';

class EbookDetailPage extends StatelessWidget {
  final Ebook ebook;
  const EbookDetailPage({super.key, required this.ebook});

  /// 파일 확장자로 PDF인지 확인
  bool get _isPdf {
    final url = ebook.fileUrl.toLowerCase();
    return url.contains('.pdf');
  }

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
            // 표지 이미지
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  ebook.coverUrl,
                  width: 200,
                  height: 300,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 200,
                    height: 300,
                    color: Colors.grey[300],
                    child: const Icon(Icons.book, size: 64, color: Colors.grey),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // 제목
            Text(
              ebook.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            
            // 저자
            Text('저자: ${ebook.author}'),
            const SizedBox(height: 8),
            
            // 파일 형식 표시
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isPdf ? Colors.red[100] : Colors.blue[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _isPdf ? 'PDF' : 'EPUB',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _isPdf ? Colors.red[800] : Colors.blue[800],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 설명
            Text(ebook.description),
            const SizedBox(height: 32),
            
            // 구매/읽기 버튼
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _onReadPressed(context),
                child: Text(
                  ebook.price == 0 ? '바로 읽기' : '$priceText • 구매 후 읽기',
                ),
              ),
            ),
            
            // 무료가 아닌 경우 안내 문구
            if (ebook.price > 0) ...[
              const SizedBox(height: 8),
              Text(
                '* 현재 테스트 모드: 결제 없이 바로 읽을 수 있습니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _onReadPressed(BuildContext context) {
    // TODO: 추후 IAP 결제 로직 추가
    // if (ebook.price > 0 && !isPurchased) {
    //   // 결제 진행
    // }
    
    // 파일 형식에 따라 적절한 뷰어로 이동
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _isPdf 
            ? PdfReaderPage(ebook: ebook)
            : EpubReaderPage(ebook: ebook),
      ),
    );
  }
}
