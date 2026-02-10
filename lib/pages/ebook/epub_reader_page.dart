// lib/pages/ebook/epub_reader_page.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:epub_view/epub_view.dart';
import '../../models/ebook.dart';
import '../../services/ebook_service.dart';

class EpubReaderPage extends StatefulWidget {
  final Ebook ebook;
  const EpubReaderPage({super.key, required this.ebook});

  @override
  State<EpubReaderPage> createState() => _EpubReaderPageState();
}

class _EpubReaderPageState extends State<EpubReaderPage> {
  late EpubController _controller;
  bool _isLoading = true;

  final _ebookService = EbookService();
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // 1. 저장된 진행도(CFI) 불러오기
      String? lastCfi;
      final progress =
          await _ebookService.getReadingProgress(widget.ebook.id);
      if (progress != null) {
        final cfiValue = progress['lastCfi'];
        if (cfiValue is String && cfiValue.isNotEmpty) {
          lastCfi = cfiValue;
        }
      }

      // 2. EPUB 파일 다운로드
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${widget.ebook.id}.epub');

      if (!await file.exists()) {
        final bytes = await http.readBytes(Uri.parse(widget.ebook.fileUrl));
        await file.writeAsBytes(bytes);
      }

      // 3. 컨트롤러 생성 (저장된 위치에서 시작)
      _controller = EpubController(
        document: EpubDocument.openFile(file),
        epubCfi: lastCfi,
      );
      _controller.currentValueListenable.addListener(_saveProgressDebounced);

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ePub 열기 실패: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  /// 진행도 저장 (디바운스: 3초)
  void _saveProgressDebounced() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 3), () async {
      try {
        final cfi = _controller.generateEpubCfi();
        if (cfi != null) {
          await _ebookService.saveReadingProgress(
            widget.ebook.id,
            lastCfi: cfi,
          );
        }
      } catch (e) {
        debugPrint('⚠️ EPUB 진행도 저장 실패: $e');
      }
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    if (!_isLoading) {
      // 닫힐 때 마지막 위치 저장
      try {
        final cfi = _controller.generateEpubCfi();
        if (cfi != null) {
          _ebookService.saveReadingProgress(
            widget.ebook.id,
            lastCfi: cfi,
          );
        }
      } catch (_) {}
      _controller.currentValueListenable
          .removeListener(_saveProgressDebounced);
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.ebook.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.ebook.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: EpubView(controller: _controller),
    );
  }
}
