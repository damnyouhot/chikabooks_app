import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminItemCreatePage extends StatefulWidget {
  const AdminItemCreatePage({super.key});

  @override
  State<AdminItemCreatePage> createState() => _AdminItemCreatePageState();
}

class _AdminItemCreatePageState extends State<AdminItemCreatePage> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _description = '';
  String _imageUrl = '';
  int _price = 0;
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('storeItems').add({
        'name': _name,
        'description': _description,
        'price': _price,
        'imageUrl': _imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('아이템 등록 성공')));
        _formKey.currentState?.reset();
      }
    } catch (e) {
      // ... 에러 처리
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              decoration: const InputDecoration(labelText: '아이템 이름'),
              validator: (val) => val!.isEmpty ? '필수 입력' : null,
              onSaved: (val) => _name = val!,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: '아이템 설명'),
              onSaved: (val) => _description = val!,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: '가격 (포인트)'),
              keyboardType: TextInputType.number,
              validator: (val) => int.tryParse(val!) == null ? '숫자만 입력' : null,
              onSaved: (val) => _price = int.parse(val!),
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: '이미지 URL'),
              validator: (val) => val!.isEmpty ? '필수 입력' : null,
              onSaved: (val) => _imageUrl = val!,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: Text(_isLoading ? '등록 중...' : '아이템 등록'),
            )
          ],
        ),
      ),
    );
  }
}
