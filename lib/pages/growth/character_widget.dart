import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/character.dart';
import '../../models/store_item.dart';
import '../../services/character_service.dart';
import '../../services/store_service.dart';

class CharacterWidget extends StatelessWidget {
  const CharacterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    if (user == null) return const SizedBox(height: 160);

    return StreamBuilder<Character?>(
      stream: CharacterService.watchCharacter(user.uid),
      builder: (context, characterSnapshot) {
        if (!characterSnapshot.hasData) {
          return const SizedBox(
              height: 180, child: Center(child: CircularProgressIndicator()));
        }

        final character = characterSnapshot.data!;

        String baseCharacterAssetPath;
        if (character.emotionPoints < 100)
          baseCharacterAssetPath = 'assets/characters/chick_lv1.png';
        else if (character.emotionPoints < 200)
          baseCharacterAssetPath = 'assets/characters/chick_lv2.png';
        else if (character.emotionPoints < 400)
          baseCharacterAssetPath = 'assets/characters/chick_lv3.png';
        else
          baseCharacterAssetPath = 'assets/characters/chick_lv4.png';

        return Column(
          children: [
            SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(baseCharacterAssetPath),
                  if (character.equippedItemId != null)
                    _buildEquippedItem(context, character.equippedItemId!),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEquippedItem(BuildContext context, String itemId) {
    return FutureBuilder<StoreItem?>(
      future: context.read<StoreService>().fetchItemById(itemId),
      builder: (context, itemSnapshot) {
        if (!itemSnapshot.hasData || itemSnapshot.data == null) {
          return const SizedBox.shrink();
        }
        final item = itemSnapshot.data!;
        return Image.network(
          item.imageUrl,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      },
    );
  }
}
