import 'package:flutter/material.dart';
import 'package:chikabooks_app/pages/growth/growth_tab.dart';
import 'package:chikabooks_app/pages/job_page.dart';
import 'package:chikabooks_app/pages/store/store_tab.dart';
import '../models/character.dart';
import '../services/character_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0; // 하단 탭 상태 관리

  Character? _character;
  bool _loading = true;
  bool _feeding = false;

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

  @override
  Widget build(BuildContext context) {
    // 4개의 탭에 해당하는 페이지 리스트 정의
    final pages = [
      _buildCharacterDashboard(), // 홈 탭
      const StoreTab(), // 스토어 탭
      const GrowthTab(), // 성장 탭
      const JobPage(), // 구직 탭
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('치과책방')), // AppBar 추가
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: '스토어'),
          BottomNavigationBarItem(
              icon: Icon(Icons.emoji_emotions), label: '성장'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: '구직'),
        ],
      ),
    );
  }

  // 홈 탭에 들어갈 상세 스탯 위젯
  Widget _buildCharacterDashboard() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_character == null) {
      return const Center(child: Text("❌ 캐릭터 데이터를 불러올 수 없습니다."));
    }

    final c = _character!;
    final affection = c.affection.clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                const Text("🟡 캐릭터 상태",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text("레벨: ${c.level}", style: const TextStyle(fontSize: 18)),
                Text("경험치: ${c.experience.toStringAsFixed(1)}",
                    style: const TextStyle(fontSize: 18)),
              ],
            ),
          ),
          const Divider(height: 32),
          _buildStatRow("학습 시간", "${c.studyMinutes}분"),
          _buildStatRow("걸음 수", "${c.stepCount} 걸음"),
          _buildStatRow("수면 시간", "${c.sleepHours} 시간"),
          _buildStatRow("퀴즈 완료", "${c.quizCount} 회"),
          _buildStatRow("감정치", "${c.emotionPoints} 점"),
          _buildStatRow("연차", "${c.tenureYears} 년"),
          const SizedBox(height: 24),
          const Text("❤️ 애정도",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: affection,
                  minHeight: 10,
                  backgroundColor: Colors.grey[300],
                ),
              ),
              const SizedBox(width: 8),
              Text("${(affection * 100).toInt()}%",
                  style: const TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _feeding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.pets),
              label: Text(_feeding ? "주시는 중..." : "밥 주기"),
              onPressed: _feeding ? null : _onFeed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("$label:", style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
