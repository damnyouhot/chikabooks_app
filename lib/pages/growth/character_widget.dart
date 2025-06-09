import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/emotion_service.dart';

class CharacterWidget extends StatelessWidget {
  const CharacterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<int>(
      stream: EmotionService.emotionPointStream(uid),
      builder: (context, snapshot) {
        final points = snapshot.data ?? 0;

        // ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼ 레벨 계산 로직 원상 복구 ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
        String assetPath;
        if (points < 100) {
          assetPath = 'assets/characters/chick_lv1.png';
        } else if (points < 200) {
          assetPath = 'assets/characters/chick_lv2.png';
        } else if (points < 400) {
          assetPath = 'assets/characters/chick_lv3.png';
        } else {
          assetPath = 'assets/characters/chick_lv4.png';
        }
        // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲ 레벨 계산 로직 원상 복구 ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              assetPath,
              width: 160,
              height: 160,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.error, size: 160);
              },
            ),
            const SizedBox(height: 12),
            Text(
              '감정 점수: $points',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        );
      },
    );
  }
}
