// lib/pages/ebook/epub_reader_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:epub_view/epub_view.dart';
import '../../models/ebook.dart';

class EpubReaderPage extends StatefulWidget {
  final Ebook ebook;
  const EpubReaderPage({super.key, required this.ebook});

  @override
  State<EpubReaderPage> createState() => _EpubReaderPageState();
}

class _EpubReaderPageState extends State<EpubReaderPage> {
  late EpubController _controller;
  File? _localFile;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${widget.ebook.id}.epub');

    if (!await file.exists()) {
      final bytes = await http.readBytes(Uri.parse(widget.ebook.fileUrl));
      await file.writeAsBytes(bytes);
    }

    setState(() => _localFile = file);

    _controller = EpubController(
      document: EpubDocument.openFile(_localFile!),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_localFile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.ebook.title)),
      body: EpubView(controller: _controller),
    );
  }
}
