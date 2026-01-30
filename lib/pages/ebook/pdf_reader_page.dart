// lib/pages/ebook/pdf_reader_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../models/ebook.dart';

class PdfReaderPage extends StatefulWidget {
  final Ebook ebook;
  const PdfReaderPage({super.key, required this.ebook});

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  PdfControllerPinch? _pdfController;
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      // PDF 파일 다운로드
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${widget.ebook.id}.pdf');

      if (!await file.exists()) {
        setState(() => _isLoading = true);
        final response = await http.get(Uri.parse(widget.ebook.fileUrl));
        if (response.statusCode == 200) {
          await file.writeAsBytes(response.bodyBytes);
        } else {
          throw Exception('PDF 다운로드 실패: ${response.statusCode}');
        }
      }

      // PDF 컨트롤러 생성
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openFile(file.path),
      );
      
      // 페이지 수 가져오기
      final document = await PdfDocument.openFile(file.path);
      setState(() {
        _totalPages = document.pagesCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '문서를 불러올 수 없습니다.\n$e';
      });
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.ebook.title,
          style: const TextStyle(fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // 페이지 정보
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '$_currentPage / $_totalPages',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          // 페이지 점프 버튼
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: _totalPages > 0 ? _showPageJumpDialog : null,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('PDF 다운로드 중...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('돌아가기'),
              ),
            ],
          ),
        ),
      );
    }

    if (_pdfController == null) {
      return const Center(child: Text('PDF를 불러올 수 없습니다.'));
    }

    return PdfViewPinch(
      controller: _pdfController!,
      onPageChanged: (page) {
        setState(() => _currentPage = page);
      },
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
        pageLoaderBuilder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorBuilder: (_, error) => Center(
          child: Text('오류: $error', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  void _showPageJumpDialog() {
    showDialog(
      context: context,
      builder: (context) {
        int targetPage = _currentPage;
        return AlertDialog(
          title: const Text('페이지 이동'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('현재: $_currentPage / $_totalPages 페이지'),
              const SizedBox(height: 16),
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '이동할 페이지',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => targetPage = int.tryParse(v) ?? _currentPage,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                if (targetPage >= 1 && targetPage <= _totalPages) {
                  _pdfController?.jumpToPage(targetPage);
                }
                Navigator.pop(context);
              },
              child: const Text('이동'),
            ),
          ],
        );
      },
    );
  }
}
