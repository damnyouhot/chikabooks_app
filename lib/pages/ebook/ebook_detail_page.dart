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
    // 유료 책인 경우 구매 완료 팝업 표시
    if (ebook.price > 0) {
      _showPurchaseCompleteDialog(context);
    } else {
      // 무료 책은 바로 읽기
      _navigateToReader(context);
    }
  }

  /// 구매 완료 후 동선 팝업
  void _showPurchaseCompleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 성공 아이콘
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 50,
                  color: Colors.green[600],
                ),
              ),
              const SizedBox(height: 20),
              
              // 제목
              const Text(
                '구매 완료! 🎉',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              // 책 제목
              Text(
                ebook.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              
              // 안내 메시지
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '구매한 책은 "내 서재"에서 언제든 다시 읽을 수 있어요!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // 버튼들
              Row(
                children: [
                  // 내 서재로 가기
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop(); // 팝업 닫기
                        Navigator.of(context).pop(); // 상세 페이지 닫기
                        // 내 서재로 이동하는 콜백이 필요하지만, 
                        // 현재는 단순히 뒤로가기로 처리
                      },
                      icon: const Icon(Icons.library_books, size: 18),
                      label: const Text('내 서재'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 바로 읽기
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop(); // 팝업 닫기
                        _navigateToReader(context);
                      },
                      icon: const Icon(Icons.auto_stories, size: 18),
                      label: const Text('바로 읽기'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 리더 페이지로 이동
  void _navigateToReader(BuildContext context) {
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
