// lib/pages/ebook/epub_reader_page.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
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
  EpubController? _controller;
  bool _isLoading = true;
  String? _error;

  final _ebookService = EbookService();
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _init();
  }

  Future<void> _init() async {
    try {
      // 저장된 CFI(진행도) 불러오기
      String? lastCfi;
      final progress = await _ebookService.getReadingProgress(widget.ebook.id);
      if (progress != null) {
        final cfiValue = progress['lastCfi'];
        if (cfiValue is String && cfiValue.isNotEmpty) lastCfi = cfiValue;
      }

      // EPUB 바이트 다운로드 (openData 방식으로 dart:io File 의존 제거)
      final bytes = await http.readBytes(Uri.parse(widget.ebook.fileUrl));

      _controller = EpubController(
        document: EpubDocument.openData(bytes),
        epubCfi: lastCfi,
      );
      _controller!.currentValueListenable.addListener(_saveProgressDebounced);

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'ePub 열기 실패: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _saveProgressDebounced() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 3), () async {
      try {
        final cfi = _controller?.generateEpubCfi();
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
    if (_controller != null) {
      try {
        final cfi = _controller!.generateEpubCfi();
        if (cfi != null) {
          _ebookService.saveReadingProgress(widget.ebook.id, lastCfi: cfi);
        }
      } catch (_) {}
      _controller!.currentValueListenable.removeListener(
        _saveProgressDebounced,
      );
      _controller!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 웹은 ePub 뷰어 미지원
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: AppColors.appBg,
        appBar: AppBar(
          backgroundColor: AppColors.appBg,
          elevation: 0,
          title: Text(widget.ebook.title),
        ),
        body: const Center(
          child: Text(
            'ePub 뷰어는 모바일 앱에서만 지원됩니다.',
            style: TextStyle(fontSize: 16, color: AppColors.textDisabled),
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.appBg,
        appBar: AppBar(
          backgroundColor: AppColors.appBg,
          elevation: 0,
          title: Text(widget.ebook.title),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.appBg,
        appBar: AppBar(
          backgroundColor: AppColors.appBg,
          elevation: 0,
          title: Text(widget.ebook.title),
        ),
        body: Center(
          child: Text(
            _error!,
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        backgroundColor: AppColors.appBg,
        elevation: 0,
        title: Text(
          widget.ebook.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: EpubView(controller: _controller!),
    );
  }
}
