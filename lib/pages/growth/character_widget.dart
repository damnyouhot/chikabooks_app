import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/character.dart';
import '../../services/character_service.dart';
import '../../widgets/unicorn_sprite_widget.dart';

class CharacterWidget extends StatelessWidget {
  const CharacterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    if (user == null) {
      return const SizedBox(height: 200, child: Center(child: Text("로그인 필요")));
    }

    return StreamBuilder<Character?>(
      stream: CharacterService.watchCharacter(user.uid),
      builder: (context, characterSnapshot) {
        if (!characterSnapshot.hasData) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final character = characterSnapshot.data!;

        return Column(
          children: [
            // 유니콘 스프라이트 애니메이션
            const UnicornSpriteWidget(
              size: 180,
              fps: 12,
              showDialogue: true,
            ),
            const SizedBox(height: 8),
            // 감정 점수 표시
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite, color: Colors.pink.shade300, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '교감 포인트: ${character.emotionPoints}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.pink.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
