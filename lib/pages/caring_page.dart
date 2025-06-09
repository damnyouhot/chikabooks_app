import 'package:flutter/material.dart';
import 'package:chikabooks_app/pages/growth/character_widget.dart';
import 'package:chikabooks_app/pages/growth/emotion_record_page.dart';
import '../models/character.dart';
import '../services/character_service.dart';

class CaringPage extends StatefulWidget {
  const CaringPage({super.key});

  @override
  State<CaringPage> createState() => _CaringPageState();
}

class _CaringPageState extends State<CaringPage> {
  Character? _character;
  bool _loading = true;
  bool _feeding = false;
  bool _checkingIn = false;

  @override
  void initState() {
    super.initState();
    _loadCharacter();
  }

  Future<void> _loadCharacter() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final char = await CharacterService.fetchCharacter();
    if (!mounted) return;
    setState(() {
      _character = char;
      _loading = false;
    });
  }

  Future<void> _onFeed() async {
    if (_feeding) return;
    setState(() => _feeding = true);
    await CharacterService.feedCharacter();
    await _loadCharacter();
    if (!mounted) return;
    setState(() => _feeding = false);
  }

  Future<void> _onCheckIn() async {
    if (_checkingIn) return;
    setState(() => _checkingIn = true);
    final message = await CharacterService.dailyCheckIn();

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }

    await _loadCharacter();
    if (mounted) {
      setState(() => _checkingIn = false);
    }
  }

  // ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼ 말풍선 텍스트를 결정하는 함수 추가 ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
  String _getCharacterQuote(Character character) {
    if (character.affection < 0.2) {
      return "배고파요... 밥을 주세요...";
    }
    if (character.emotionPoints < 50) {
      return "오늘 하루는 어땠나요? 제게 응원을 보내주세요!";
    }
    if (character.studyMinutes > 60) {
      return "열심히 공부하는 모습이 멋져요!";
    }
    return "오늘도 함께 성장해요!";
  }
  // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲ 말풍선 텍스트를 결정하는 함수 추가 ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_character == null) {
      return const Center(child: Text("❌ 캐릭터 데이터를 불러올 수 없습니다."));
    }

    final c = _character!;
    final affection = c.affection.clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
      child: Center(
        child: Column(
          children: [
            // ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼ 말풍선 UI 추가 ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _getCharacterQuote(c),
                style: const TextStyle(fontSize: 15),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲ 말풍선 UI 추가 ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
            const CharacterWidget(),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const EmotionRecordPage()),
                    ).then((_) => _loadCharacter());
                  },
                  icon: const Icon(Icons.edit_note),
                  label: const Text('응원하기'),
                ),
                ElevatedButton.icon(
                  icon: _feeding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.pets),
                  label: Text(_feeding ? "주는중..." : "밥주기"),
                  onPressed: _feeding ? null : _onFeed,
                ),
                ElevatedButton.icon(
                  icon: _checkingIn
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_checkingIn ? "확인중..." : "출석하기"),
                  onPressed: _checkingIn ? null : _onCheckIn,
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const Text("🟡 나의 현재 상태",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildStatRow("레벨", "${c.level}"),
            _buildStatRow("경험치", c.experience.toStringAsFixed(1)),
            _buildStatRow("❤️ 애정도", "${(affection * 100).toInt()}%"),
            const SizedBox(height: 16),
            const Text("📊 나의 활동 기록",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildStatRow("학습 시간", "${c.studyMinutes}분"),
            _buildStatRow("걸음 수", "${c.stepCount} 걸음"),
            _buildStatRow("수면 시간", "${c.sleepHours.toStringAsFixed(1)} 시간"),
            _buildStatRow("퀴즈 완료", "${c.quizCount} 회"),
            _buildStatRow("감정치", "${c.emotionPoints} 점"),
            _buildStatRow("연차", "${c.tenureYears} 년"),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
              width: 100,
              child: Text("$label:", style: const TextStyle(fontSize: 16))),
          const SizedBox(width: 8),
          Text(value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
