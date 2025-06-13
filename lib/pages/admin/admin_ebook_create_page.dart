// lib/pages/admin/admin_ebook_create_page.dart

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/epub_utility.dart';
import '../../services/storage_service.dart';

class AdminEbookCreatePage extends StatefulWidget {
  const AdminEbookCreatePage({super.key});

  @override
  State<AdminEbookCreatePage> createState() => _AdminEbookCreatePageState();
}

class _AdminEbookCreatePageState extends State<AdminEbookCreatePage> {
  final _formKey = GlobalKey<FormState>();

  String _title = '', _author = '', _description = '', _productId = '';
  DateTime _publishedAt = DateTime.now();
  int _price = 0;
  Uint8List? _epubBytes;
  Uint8List? _coverImageBytes;
  bool _isLoading = false;

  Future<void> _pickEpub() async {
    const typeGroup = XTypeGroup(label: 'epub', extensions: ['epub']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final cover = await EpubUtility.extractCoverImage(bytes);

    setState(() {
      _epubBytes = bytes;
      _coverImageBytes = cover;
    });

    if (cover == null && mounted) {
      _snack('ePub 파일에서 표지를 추출하지 못했습니다. 수동 URL 입력이 필요합니다.');
    }
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    if (_epubBytes == null) {
      _snack('ePub 파일을 선택하세요.');
      return;
    }
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      final doc = FirebaseFirestore.instance.collection('ebooks').doc();

      String coverUrl = '';
      if (_coverImageBytes != null) {
        coverUrl = await StorageService.uploadCoverImage(
          ebookId: doc.id,
          bytes: _coverImageBytes!,
        );
      } else {
        _snack('표지 이미지가 없어 URL이 비게 됩니다. 나중에 수정해주세요.');
      }

      final fileUrl =
          await StorageService.uploadEpub(docId: doc.id, bytes: _epubBytes!);

      await doc.set({
        'title': _title.trim(),
        'author': _author.trim(),
        'coverUrl': coverUrl,
        'description': _description.trim(),
        'productId': _productId.trim(),
        'publishedAt': Timestamp.fromDate(_publishedAt),
        'price': _price,
        'fileUrl': fileUrl,
      });

      if (!mounted) return;
      _snack('전자책이 추가되었습니다.');
      _formKey.currentState?.reset();
      setState(() {
        _epubBytes = null;
        _coverImageBytes = null;
      });
      if (mounted) DefaultTabController.of(context).animateTo(0);
    } catch (e) {
      if (!mounted) return;
      _snack('오류 발생: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _field('제목*', onSave: (v) => _title = v, validator: _req),
            _field('저자*', onSave: (v) => _author = v, validator: _req),
            _field('가격(원)*',
                keyboard: TextInputType.number,
                onSave: (v) => _price = int.tryParse(v) ?? 0,
                validator: (v) => int.tryParse(v) == null ? '숫자' : null),
            _field('상품 ID*', onSave: (v) => _productId = v, validator: _req),
            _field('설명', maxLines: 3, onSave: (v) => _description = v),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title:
                  Text('출간일: ${DateFormat('yyyy-MM-dd').format(_publishedAt)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _publishedAt,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _publishedAt = d);
              },
            ),
            if (_coverImageBytes != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Column(
                  children: [
                    const Text('추출된 표지'),
                    const SizedBox(height: 8),
                    Image.memory(_coverImageBytes!, height: 150),
                  ],
                ),
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file),
              label: Text(_epubBytes == null ? 'ePub 선택' : 'ePub 변경'),
              onPressed: _pickEpub,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _create,
              child: Text(_isLoading ? '등록 중...' : '추가하기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label, {
    int maxLines = 1,
    TextInputType? keyboard,
    required void Function(String) onSave,
    String? Function(String)? validator,
  }) =>
      TextFormField(
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label),
        onSaved: (v) => onSave(v!.trim()),
        validator: validator == null ? null : (v) => validator(v!.trim()),
      );

  String? _req(String v) => v.isEmpty ? '필수 입력' : null;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
