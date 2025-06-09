// lib/pages/growth/emotion_record_page.dart
import 'package:flutter/material.dart';
import '../../services/emotion_service.dart';

class EmotionRecordPage extends StatefulWidget {
  const EmotionRecordPage({super.key});

  @override
  State<EmotionRecordPage> createState() => _EmotionRecordPageState();
}

class _EmotionRecordPageState extends State<EmotionRecordPage> {
  // 사용자가 슬라이더로 선택한 점수를 저장할 변수
  int _score = 3; // 기본값 3점
  // 로딩 중일 때 버튼을 비활성화하기 위한 변수
  bool _loading = false;

  // '기록하기' 버튼을 눌렀을 때 실행될 함수
  Future<void> _submit() async {
    // 로딩 시작
    setState(() => _loading = true);

    // EmotionService를 호출하여 오늘 이미 기록했는지 확인
    final canRecord = await EmotionService.canRecordToday();
    if (!canRecord) {
      // 위젯이 화면에 아직 붙어있는지 확인 (안전장치)
      if (mounted) {
        // 이미 기록했다면 사용자에게 알림 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오늘은 이미 감정을 기록했어요!')),
        );
        Navigator.pop(context); // 이전 화면으로 돌아가기
      }
      return;
    }

    // EmotionService를 호출하여 점수 기록
    await EmotionService.recordEmotion(_score);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오늘의 감정이 기록되었습니다 🙂')),
      );
      Navigator.pop(context); // 기록 후 이전 화면으로 돌아가기
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
              '$_score점', // 선택된 점수 표시
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            // 점수를 선택하는 슬라이더
            Slider(
              value: _score.toDouble(),
              min: 1,
              max: 5,
              divisions: 4, // 1~5점이므로 4개의 구간으로 나눔
              label: '$_score점', // 슬라이더를 움직일 때 표시될 라벨
              onChanged: (value) {
                // 슬라이더 값이 바뀔 때마다 _score 변수 업데이트 및 화면 새로고침
                setState(() {
                  _score = value.round();
                });
              },
            ),
            const SizedBox(height: 48),
            // 기록하기 버튼
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                // _loading이 true이면 버튼 비활성화, 아니면 _submit 함수 실행
                onPressed: _loading ? null : _submit,
                child: _loading
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
