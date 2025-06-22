// lib/pages/growth/study/epub_reader_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:epub_view/epub_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../models/ebook.dart';
import '../../../services/ebook_service.dart';
import '../../../services/growth_service.dart';

class EpubReaderPage extends StatefulWidget {
  final Ebook ebook;
  const EpubReaderPage({super.key, required this.ebook});

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
      final currentUid = _uid;
      if (currentUid != null) {
        final doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUid)
                .collection('purchases')
                .doc(widget.ebook.id)
                .get();

        // ▼▼▼ 오류가 발생한 부분을 안전한 코드로 수정합니다 ▼▼▼
        if (doc.exists) {
          final data = doc.data();
          final lastOpenedValue = data?['lastOpened'];
          if (lastOpenedValue is String) {
            lastCfi = lastOpenedValue;
          }
        }
        // ▲▲▲ 오류가 발생한 부분을 안전한 코드로 수정합니다 ▲▲▲
      }

      final res = await http.get(Uri.parse(widget.ebook.fileUrl));
      if (res.statusCode != 200) {
        throw 'ePub 다운로드 실패 (${res.statusCode})';
      }
      _controller = EpubController(
        document: EpubDocument.openData(res.bodyBytes),
        epubCfi: lastCfi,
      );
      _controller.currentValueListenable.addListener(_saveProgressDebounced);
      _startRead = DateTime.now();
      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ePub 열기 실패: $e')));
        Navigator.pop(context);
      }
    }
  }

  void _saveProgressDebounced() {
    final currentUid = _uid;
    if (currentUid == null) {
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () async {
      final val = _controller.currentValue;
      if (val == null) {
        return;
      }
      final percent = ((val.position as double? ?? 0.0) * 100)
          .clamp(0, 100)
          .toStringAsFixed(1);
      final cfi = _controller.generateEpubCfi();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('purchases')
          .doc(widget.ebook.id)
          .set({
            'lastOpened': cfi,
            'progress': double.parse(percent),
          }, SetOptions(merge: true));
    });
  }

  Future<void> _logStudyMinutes() async {
    final currentUid = _uid;
    final startTime = _startRead;
    if (currentUid == null || startTime == null) {
      return;
    }
    final mins = DateTime.now().difference(startTime).inMinutes;
    if (mins == 0) {
      return;
    }
    await GrowthService.recordEvent(
      uid: currentUid,
      type: 'study',
      value: mins.toDouble(),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (mounted && !_loading) {
      _controller.currentValueListenable.removeListener(_saveProgressDebounced);
      _controller.dispose();
    }
    _logStudyMinutes();
    super.dispose();
  }

  void _showBookmarks() {
    final ebookService = context.read<EbookService>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '북마크',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.bookmark_add),
                      label: const Text('현재 위치 추가'),
                      onPressed: () async {
                        final cfi = _controller.generateEpubCfi();
                        final title =
                            _controller.currentValue?.chapter?.Title ??
                            '알 수 없는 챕터';
                        if (cfi != null) {
                          await ebookService.addBookmark(
                            widget.ebook.id,
                            cfi,
                            title,
                          );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: ebookService.watchBookmarks(widget.ebook.id),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final bookmarks = snapshot.data!.docs;
                    if (bookmarks.isEmpty) {
                      return const Center(child: Text('추가된 북마크가 없습니다.'));
                    }
                    return ListView.builder(
                      itemCount: bookmarks.length,
                      itemBuilder: (context, index) {
                        final bookmark = bookmarks[index];
                        final data = bookmark.data() as Map<String, dynamic>;
                        return ListTile(
                          title: Text(
                            data['title'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            _controller.gotoEpubCfi(data['cfi']);
                            Navigator.pop(ctx);
                          },
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.grey,
                            ),
                            onPressed:
                                () => ebookService.removeBookmark(
                                  widget.ebook.id,
                                  bookmark.id,
                                ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
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
      appBar: AppBar(
        title: Text(
          _controller.currentValue?.chapter?.Title ?? widget.ebook.title,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            onPressed: _showBookmarks,
          ),
        ],
      ),
      body: EpubView(controller: _controller),
    );
  }
}
