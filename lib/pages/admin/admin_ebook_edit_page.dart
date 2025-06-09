// lib/pages/admin/admin_ebook_edit_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_selector/file_selector.dart'; // ✅ file_picker → file_selector
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/ebook.dart';
import '../../services/storage_service.dart';

class AdminEbookEditPage extends StatefulWidget {
  final Ebook ebook;
  const AdminEbookEditPage({super.key, required this.ebook});

  @override
  State<AdminEbookEditPage> createState() => _AdminEbookEditPageState();
}

class _AdminEbookEditPageState extends State<AdminEbookEditPage> {
  final _formKey = GlobalKey<FormState>();

  late String _title, _author, _coverUrl, _description, _productId;
  late DateTime _publishedAt;
  late int _price;

  @override
  void initState() {
    super.initState();
    final e = widget.ebook;
    _title = e.title;
    _author = e.author;
    _coverUrl = e.coverUrl;
    _description = e.description;
    _productId = e.productId;
    _publishedAt = e.publishedAt;
    _price = e.price;
  }

  /* ───────────────────────────────────── 기본 메타 수정 ───────────────────────────────────── */
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    await FirebaseFirestore.instance
        .collection('ebooks')
        .doc(widget.ebook.id)
        .update({
      'title': _title.trim(),
      'author': _author.trim(),
      'coverUrl': _coverUrl.trim(),
      'description': _description.trim(),
      'productId': _productId.trim(),
      'publishedAt': Timestamp.fromDate(_publishedAt),
      'price': _price,
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('수정이 완료되었습니다.')),
    );
    Navigator.pop(context);
  }

  /* ───────────────────────────────────── ePub 교체 ───────────────────────────────────── */
  Future<void> _replaceEpub() async {
    const group = XTypeGroup(
      label: 'epub',
      extensions: ['epub'],
      mimeTypes: ['application/epub+zip'],
    );

    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return; // 사용자가 취소한 경우

    final bytes = await file.readAsBytes();

    final url = await StorageService.uploadEpub(
      docId: widget.ebook.id,
      bytes: bytes,
    );

    await FirebaseFirestore.instance
        .collection('ebooks')
        .doc(widget.ebook.id)
        .update({'fileUrl': url});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ePub 파일이 교체되었습니다.')),
      );
    }
  }

  /* ───────────────────────────────────── UI ───────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('전자책 수정')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _field('제목*', _title, (v) => _title = v, _req),
              _field('저자*', _author, (v) => _author = v, _req),
              _field('가격(원)*', '$_price', (v) => _price = int.tryParse(v) ?? 0,
                  (v) => int.tryParse(v) == null ? '숫자' : null,
                  keyboard: TextInputType.number),
              _field('상품 ID*', _productId, (v) => _productId = v, _req),
              _field('표지 URL*', _coverUrl, (v) => _coverUrl = v, _req),
              _field('설명', _description, (v) => _description = v, null,
                  maxLines: 3),

              /* 출간일 선택 */
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    '출간일: ${DateFormat('yyyy-MM-dd').format(_publishedAt)}'),
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

              /* ePub 교체 버튼 */
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('ePub 교체'),
                onPressed: _replaceEpub,
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _submit, child: const Text('수정 완료')),
            ],
          ),
        ),
      ),
    );
  }

  /* ───────────────────────────────────── 필드 헬퍼 ───────────────────────────────────── */
  Widget _field(
    String label,
    String init,
    void Function(String) onSave,
    String? Function(String)? validator, {
    int maxLines = 1,
    TextInputType? keyboard,
  }) =>
      TextFormField(
        initialValue: init,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label),
        onSaved: (v) => onSave(v!.trim()),
        validator: validator == null ? null : (v) => validator(v!.trim()),
      );

  String? _req(String v) => v.isEmpty ? '필수 입력' : null;
}
