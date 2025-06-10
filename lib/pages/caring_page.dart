import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/character.dart';
import '../models/store_item.dart';
import '../services/character_service.dart';
import '../services/store_service.dart';
import 'growth/character_widget.dart';
import 'growth/emotion_record_page.dart';

// UI의 시각적 효과(애니메이션) 상태를 관리하기 위해 StatelessWidget -> StatefulWidget으로 변경
class CaringPage extends StatefulWidget {
  const CaringPage({super.key});

  @override
  State<CaringPage> createState() => _CaringPageState();
}

class _CaringPageState extends State<CaringPage> {
  // 하트 애니메이션 표시 여부를 제어하는 상태 변수
  bool _showHeart = false;

  // '밥주기' 버튼을 눌렀을 때 실행될 함수
  void _onFeed() {
    CharacterService.feedCharacter(); // Firestore 데이터 업데이트
    if (mounted) {
      // 하트 표시 상태를 true로 변경하여 애니메이션 시작
      setState(() => _showHeart = true);
      // 1초 뒤에 하트가 사라지도록 타이머 설정
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() => _showHeart = false);
        }
      });
    }
  }

  // 인벤토리 UI를 보여주는 함수
  void _showInventory(BuildContext context, Character character) {
    // ... (이전 코드와 동일)
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    if (user == null) return const Center(child: Text('로그인이 필요합니다.'));

    return StreamBuilder<Character?>(
      stream: CharacterService.watchCharacter(user.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final character = snapshot.data!;

        // 캐릭터 정보를 UI 빌드 함수로 전달
        return _buildCaringUI(context, character);
      },
    );
  }

  Widget _buildCaringUI(BuildContext context, Character character) {
    final affection = character.affection.clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
      child: Center(
        child: Column(
          children: [
            // ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼ 캐릭터와 하트 효과를 겹치기 위해 Stack 사용 ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
            Stack(
              alignment: Alignment.topCenter,
              children: [
                const CharacterWidget(),
                // AnimatedOpacity를 사용하여 하트가 부드럽게 나타났다 사라지게 함
                AnimatedOpacity(
                  opacity: _showHeart ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: const Icon(Icons.favorite,
                      color: Colors.pinkAccent, size: 50),
                ),
              ],
            ),
            // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲ 캐릭터와 하트 효과를 겹치기 위해 Stack 사용 ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
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
                            builder: (_) => const EmotionRecordPage()));
                  },
                  icon: const Icon(Icons.edit_note),
                  label: const Text('응원하기'),
                ),
                ElevatedButton.icon(
                  onPressed: _onFeed, // 수정된 밥주기 함수 연결
                  icon: const Icon(Icons.pets),
                  label: const Text("밥주기"),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final message = await CharacterService.dailyCheckIn();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(message)));
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("출석하기"),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showInventory(context, character),
                  icon: const Icon(Icons.checkroom),
                  label: const Text('꾸미기'),
                ),
              ],
            ),
            // ... (이하 스탯 표시는 이전 코드와 동일) ...
          ],
        ),
      ),
    );
  }
}
