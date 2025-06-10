import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/character.dart';
import '../models/store_item.dart';
import '../services/character_service.dart';
import '../services/store_service.dart';
import 'growth/character_widget.dart';
import 'growth/emotion_record_page.dart';

class CaringPage extends StatefulWidget {
  const CaringPage({super.key});

  @override
  State<CaringPage> createState() => _CaringPageState();
}

class _CaringPageState extends State<CaringPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartAnimationController;
  late Animation<double> _heartAnimation;

  @override
  void initState() {
    super.initState();
    _heartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _heartAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _heartAnimationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _heartAnimationController.dispose();
    super.dispose();
  }

  void _onFeed() {
    CharacterService.feedCharacter();
    if (mounted) {
      _heartAnimationController.forward(from: 0.0);
    }
  }

  void _showInventory(BuildContext context, Character character) {
    final storeService = context.read<StoreService>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return FutureBuilder<List<StoreItem>>(
          future: storeService.fetchMyItems(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('보유한 아이템이 없습니다.'));
            }
            final myItems = snapshot.data!;
            return GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: myItems.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Tooltip(
                    message: "아이템 해제",
                    child: InkWell(
                      onTap: () {
                        CharacterService.equipItem(null);
                        Navigator.pop(context);
                      },
                      child: const CircleAvatar(
                        backgroundColor: Colors.grey,
                        child:
                            Icon(Icons.do_not_disturb_on, color: Colors.white),
                      ),
                    ),
                  );
                }
                final item = myItems[index - 1];
                final isEquipped = character.equippedItemId == item.id;
                return Tooltip(
                  message: item.name,
                  child: InkWell(
                    onTap: () {
                      CharacterService.equipItem(item.id);
                      Navigator.pop(context);
                    },
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(item.imageUrl),
                      child: isEquipped
                          ? Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.green, width: 3),
                              ),
                            )
                          : null,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    if (user == null) {
      return const Center(child: Text('로그인이 필요합니다.'));
    }

    return StreamBuilder<Character?>(
      stream: CharacterService.watchCharacter(user.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final character = snapshot.data!;
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
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                const CharacterWidget(),
                Positioned(
                  top: -20,
                  child: FadeTransition(
                    opacity: _heartAnimation
                        .drive(CurveTween(curve: Curves.easeOut)),
                    child: SlideTransition(
                      position: _heartAnimation.drive(Tween(
                          begin: const Offset(0.2, 0.2),
                          end: const Offset(0.2, -1.5))),
                      child: const Icon(Icons.favorite,
                          color: Colors.pinkAccent, size: 40),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const EmotionRecordPage())),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('응원하기'),
                ),
                ElevatedButton.icon(
                  onPressed: _onFeed,
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
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const Text("🟡 나의 현재 상태",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildStatRow("레벨", "${character.level}"),
            _buildStatRow("경험치", character.experience.toStringAsFixed(1)),
            _buildStatRow("❤️ 애정도", "${(affection * 100).toInt()}%"),
            _buildStatRow("💰 보유 포인트", "${character.emotionPoints} P"),
            const SizedBox(height: 16),
            const Text("📊 나의 활동 기록",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildStatRow("학습 시간", "${character.studyMinutes}분"),
            _buildStatRow("걸음 수", "${character.stepCount} 걸음"),
            _buildStatRow(
                "수면 시간", "${character.sleepHours.toStringAsFixed(1)} 시간"),
            _buildStatRow("퀴즈 완료", "${character.quizCount} 회"),
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
