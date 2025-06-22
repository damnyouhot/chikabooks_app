// lib/pages/growth/emotion_record_page.dart (진단용 코드)
import 'package:flutter/material.dart';
import '../../services/emotion_service.dart';
import 'dart:developer' as developer;

class EmotionRecordPage extends StatefulWidget {
  const EmotionRecordPage({super.key});

  @override
  State<EmotionRecordPage> createState() => _EmotionRecordPageState();
}

class _EmotionRecordPageState extends State<EmotionRecordPage> {
  int _score = 3;
  bool _loading = false;

  Future<void> _submit() async {
    developer.log('--- 감정 기록 시작 ---', name: 'EmotionDebug');
    setState(() => _loading = true);

    try {
      developer.log('1. 오늘 기록 가능한지 확인 시작...', name: 'EmotionDebug');
      final canRecord = await EmotionService.canRecordToday();
      developer.log('2. 오늘 기록 가능 여부: $canRecord', name: 'EmotionDebug');

      if (!canRecord) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('오늘은 이미 감정을 기록했어요!')));
          Navigator.pop(context, false);
        }
        developer.log('--- 이미 기록하여 프로세스 종료 ---', name: 'EmotionDebug');
        return;
      }

      developer.log(
        '3. Firestore에 감정 기록 시작 (점수: $_score)...',
        name: 'EmotionDebug',
      );
      await EmotionService.recordEmotion(_score);
      developer.log('4. Firestore에 감정 기록 성공!', name: 'EmotionDebug');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('오늘의 감정이 기록되었습니다 🙂')));
        Navigator.pop(context, true);
      }
      developer.log('--- 모든 프로세스 정상 종료 ---', name: 'EmotionDebug');
    } catch (e, s) {
      developer.log(
        '!!! 감정 기록 중 치명적인 오류 발생 !!!',
        name: 'EmotionDebug',
        error: e,
        stackTrace: s,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류 발생: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
      developer.log('--- finally 블록 실행 ---', name: 'EmotionDebug');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 감정 기록')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '오늘 기분은 몇 점인가요?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              '$_score점',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Slider(
              value: _score.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: '$_score점',
              onChanged: (value) {
                setState(() => _score = value.round());
              },
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child:
                    _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('기록하기', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
