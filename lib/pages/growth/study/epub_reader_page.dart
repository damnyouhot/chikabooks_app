// lib/pages/growth/study/epub_reader_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:epub_view/epub_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/ebook.dart';
import '../../../services/growth_service.dart';

class EpubReaderPage extends StatefulWidget {
  final Ebook ebook;
  const EpubReaderPage({super.key, required this.ebook}); // super.key 수정

  @override
  State<EpubReaderPage> createState() => _EpubReaderPageState();
}

class _EpubReaderPageState extends State<EpubReaderPage> {
  late EpubController _controller;
  bool _loading = true;

  final _uid = FirebaseAuth.instance.currentUser?.uid;
  Timer? _debounce;
  DateTime? _startRead;

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  Future<void> _loadBook() async {
    try {
      String? lastCfi;
      final currentUid = _uid; // null일 수 있는 _uid를 지역 변수에 할당
      if (currentUid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .collection('purchases')
            .doc(widget.ebook.id)
            .get();
        lastCfi = doc.data()?['lastOpened'] as String?;
      }

      final res = await http.get(Uri.parse(widget.ebook.fileUrl));
      if (res.statusCode != 200) throw 'ePub 다운로드 실패 (${res.statusCode})';

      _controller = EpubController(
        document: EpubDocument.openData(res.bodyBytes),
        epubCfi: lastCfi,
      );

      _controller.currentValueListenable.addListener(_saveProgressDebounced);

      _startRead = DateTime.now();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ePub 열기 실패: $e')),
      );
      Navigator.pop(context);
    }
  }

  void _saveProgressDebounced() {
    final currentUid = _uid; // null일 수 있는 _uid를 지역 변수에 할당
    if (currentUid == null) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () async {
      final val = _controller.currentValue;
      if (val == null) return;

      final percent = ((val.position as double? ?? 0.0) * 100)
          .clamp(0, 100)
          .toStringAsFixed(1);

      final cfi = _controller.generateEpubCfi();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('purchases')
          .doc(widget.ebook.id)
          .set(
        {'lastOpened': cfi, 'progress': double.parse(percent)},
        SetOptions(merge: true),
      );
    });
  }

  Future<void> _logStudyMinutes() async {
    final currentUid = _uid; // null일 수 있는 _uid를 지역 변수에 할당
    final startTime = _startRead; // null일 수 있는 _startRead를 지역 변수에 할당

    if (currentUid == null || startTime == null) return;
    final mins = DateTime.now().difference(startTime).inMinutes;
    if (mins == 0) return;

    await GrowthService.recordEvent(
      uid: currentUid,
      type: 'study',
      value: mins.toDouble(),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // 컨트롤러가 초기화되었는지 확인 후 리스너 제거
    if (mounted && !_loading) {
      _controller.currentValueListenable.removeListener(_saveProgressDebounced);
      _controller.dispose();
    }
    _logStudyMinutes();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.ebook.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.ebook.title)),
      body: EpubView(controller: _controller),
    );
  }
}
