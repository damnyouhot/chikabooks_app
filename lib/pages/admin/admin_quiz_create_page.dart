import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminQuizCreatePage extends StatefulWidget {
  const AdminQuizCreatePage({super.key});

  @override
  State<AdminQuizCreatePage> createState() => _AdminQuizCreatePageState();
}

class _AdminQuizCreatePageState extends State<AdminQuizCreatePage> {
  final _formKey = GlobalKey<FormState>();
  String _question = '';
  final List<String> _options = ['', '', '', ''];
  int _answerIndex = 0;
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('quizzes').add({
        'question': _question,
        'options': _options,
        'answerIndex': _answerIndex,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('퀴즈가 성공적으로 등록되었습니다.')),
        );
        _formKey.currentState?.reset();
        setState(() => _answerIndex = 0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              decoration: const InputDecoration(labelText: '퀴즈 질문'),
              validator: (val) => val!.isEmpty ? '질문을 입력하세요.' : null,
              onSaved: (val) => _question = val!,
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            const Text('보기 (정답을 선택해주세요)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ...List.generate(4, (index) {
              return RadioListTile<int>(
                title: TextFormField(
                  decoration: InputDecoration(labelText: '보기 ${index + 1}'),
                  validator: (val) => val!.isEmpty ? '보기를 입력하세요.' : null,
                  onSaved: (val) => _options[index] = val!,
                ),
                value: index,
                groupValue: _answerIndex,
                onChanged: (val) {
                  setState(() => _answerIndex = val!);
                },
              );
            }),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: Text(_isLoading ? '등록 중...' : '퀴즈 등록하기'),
            ),
          ],
        ),
      ),
    );
  }
}
