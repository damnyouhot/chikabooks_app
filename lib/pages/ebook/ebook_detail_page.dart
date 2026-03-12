// lib/pages/ebook/ebook_detail_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/ebook.dart';
import '../../services/ebook_service.dart';
import 'epub_reader_page.dart';
import 'pdf_reader_page.dart';

class EbookDetailPage extends StatefulWidget {
  final Ebook ebook;
  /// true이면 구매/읽기 버튼을 숨김 (치과책방 탭 전용)
  final bool hideActions;
  const EbookDetailPage({super.key, required this.ebook, this.hideActions = false});

  @override
  State<EbookDetailPage> createState() => _EbookDetailPageState();
}

class _EbookDetailPageState extends State<EbookDetailPage> {
  bool _isPurchased = false;
  bool _checkingPurchase = true;

  Ebook get ebook => widget.ebook;

  /// 파일 확장자로 PDF인지 확인
  bool get _isPdf {
    final url = ebook.fileUrl.toLowerCase();
    return url.contains('.pdf');
  }

  @override
  void initState() {
    super.initState();
    _checkPurchaseStatus();
  }

  Future<void> _checkPurchaseStatus() async {
    // 무료 책은 항상 구매된 것으로 취급
    if (ebook.price == 0) {
      if (mounted) setState(() { _isPurchased = true; _checkingPurchase = false; });
      return;
    }

    try {
      final ebookService = context.read<EbookService>();
      final purchased = await ebookService.hasPurchased(ebook.id);
      if (mounted) {
        setState(() {
          _isPurchased = purchased;
          _checkingPurchase = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _checkingPurchase = false);
    }
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
            // 표지 이미지: 화면 너비의 45% 기준, 최소160·최대240, 비율 2:3 유지
            Center(
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final screenW = MediaQuery.of(ctx).size.width;
                  final coverW = (screenW * 0.45).clamp(160.0, 240.0);
                  final coverH = coverW * 1.5; // 2:3 비율
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      ebook.coverUrl,
                      width: coverW,
                      height: coverH,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: coverW,
                        height: coverH,
                        color: Colors.grey[300],
                        child: const Icon(Icons.book, size: 64, color: Colors.grey),
                      ),
                    ),
                  );
                },
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
            
            // 구매/읽기 버튼 (hideActions가 true면 숨김 — 치과책방 탭)
            if (!widget.hideActions) ...[
              SizedBox(
                width: double.infinity,
                child: _checkingPurchase
                    ? const Center(child: CircularProgressIndicator())
                    : FilledButton(
                        onPressed: () => _onButtonPressed(context),
                        child: Text(
                          _isPurchased
                              ? '이어서 읽기'
                              : ebook.price == 0
                                  ? '바로 읽기'
                                  : '$priceText • 구매 후 읽기',
                        ),
                      ),
              ),

              // 이미 구매한 경우 안내
              if (_isPurchased && ebook.price > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '✓ 이미 구매한 책입니다.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              
              // 무료가 아니고 미구매인 경우 안내 문구
              if (!_isPurchased && ebook.price > 0) ...[
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
          ],
        ),
      ),
    );
  }

  Future<void> _onButtonPressed(BuildContext context) async {
    // 이미 구매했거나 무료면 바로 읽기
    if (_isPurchased) {
      _navigateToReader(context);
      return;
    }

    // 미구매 유료 책 → 구매 처리
    final ebookService = context.read<EbookService>();
    try {
      await ebookService.purchaseEbook(ebook.id);
      if (mounted) {
        setState(() => _isPurchased = true);
        _showPurchaseCompleteDialog(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('구매 처리 중 오류가 발생했습니다: $e')),
        );
      }
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
              // 성공 아이콘: 화면 너비의 18%, 최소64·최대96
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final iconSize = (MediaQuery.of(ctx).size.width * 0.18)
                      .clamp(64.0, 96.0);
                  return Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      size: iconSize * 0.625,
                      color: Colors.green[600],
                    ),
                  );
                },
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
                      label: const Text('이어서 읽기'),
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
