import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/character.dart';
import '../models/store_item.dart';
import '../services/character_service.dart';
import '../services/store_service.dart';

class DressUpPage extends StatefulWidget {
  const DressUpPage({super.key});

  @override
  State<DressUpPage> createState() => _DressUpPageState();
}

class _DressUpPageState extends State<DressUpPage> {
  static const _bgGradientTop = Color(0xFF5C4A6B);
  static const _bgGradientBottom = Color(0xFF3D3D5C);
  static const _accentYellow = Color(0xFFFFD54F);
  static const _cardColor = Color(0xFF4A4A6A);

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    if (user == null) {
      return _buildScaffold(
        body: const Center(
          child: Text(
            '로그인이 필요합니다.',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ),
      );
    }

    return StreamBuilder<Character?>(
      stream: CharacterService.watchCharacter(user.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildScaffold(
            body: const Center(
              child: CircularProgressIndicator(color: _accentYellow),
            ),
          );
        }
        final character = snapshot.data!;
        return _buildScaffold(body: _buildContent(character));
      },
    );
  }

  Widget _buildScaffold({required Widget body}) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '꾸미기',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgGradientTop, _bgGradientBottom],
          ),
        ),
        child: SafeArea(child: body),
      ),
    );
  }

  Widget _buildContent(Character character) {
    return Column(
      children: [
        const SizedBox(height: 20),
        _buildCharacterPreview(character),
        const SizedBox(height: 24),
        _buildEquippedInfo(character),
        const SizedBox(height: 16),
        Expanded(child: _buildItemGrid(character)),
      ],
    );
  }

  Widget _buildCharacterPreview(Character character) {
    String assetPath = 'assets/characters/chick_lv1.png';
    if (character.emotionPoints >= 400) {
      assetPath = 'assets/characters/chick_lv4.png';
    } else if (character.emotionPoints >= 200) {
      assetPath = 'assets/characters/chick_lv3.png';
    } else if (character.emotionPoints >= 100) {
      assetPath = 'assets/characters/chick_lv2.png';
    }

    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.1),
        border: Border.all(color: _accentYellow.withOpacity(0.3), width: 3),
      ),
      child: Center(child: Image.asset(assetPath, width: 140, height: 140)),
    );
  }

  Widget _buildEquippedInfo(Character character) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.checkroom_rounded, color: _accentYellow, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              character.equippedItemId != null ? '아이템 장착중' : '착용 중인 아이템 없음',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          if (character.equippedItemId != null)
            TextButton(
              onPressed: () => CharacterService.equipItem(null),
              child: const Text('해제', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Widget _buildItemGrid(Character character) {
    final storeService = context.read<StoreService>();

    return FutureBuilder<List<StoreItem>>(
      future: storeService.fetchMyItems(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _accentYellow),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inventory_2_rounded,
                  color: Colors.white.withOpacity(0.3),
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  '보유한 아이템이 없습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
              ],
            ),
          );
        }

        final items = snapshot.data!;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final isEquipped = character.equippedItemId == item.id;

            return GestureDetector(
              onTap: () {
                if (isEquipped) {
                  CharacterService.equipItem(null);
                } else {
                  CharacterService.equipItem(item.id);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      isEquipped
                          ? Border.all(color: _accentYellow, width: 3)
                          : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.network(
                          item.imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder:
                              (_, __, ___) => const Icon(
                                Icons.image_not_supported,
                                color: Colors.white30,
                              ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        item.name,
                        style: TextStyle(
                          color: isEquipped ? _accentYellow : Colors.white70,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}































