import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/character.dart';
import '../services/character_service.dart';

class FeedingPage extends StatefulWidget {
  const FeedingPage({super.key});

  @override
  State<FeedingPage> createState() => _FeedingPageState();
}

class _FeedingPageState extends State<FeedingPage>
    with SingleTickerProviderStateMixin {
  static const _bgGradientTop = Color(0xFF8B6914);
  static const _bgGradientBottom = Color(0xFF5D4A1F);
  static const _accentYellow = Color(0xFFFFD54F);

  late AnimationController _eatController;
  late Animation<double> _eatAnimation;
  bool _isEating = false;
  int? _selectedFood;

  final List<Map<String, dynamic>> _foods = [
    {'name': '사과', 'emoji': '🍎'},
    {'name': '당근', 'emoji': '🥕'},
    {'name': '씨앗', 'emoji': '🌾'},
    {'name': '벌레', 'emoji': '🐛'},
  ];

  @override
  void initState() {
    super.initState();
    _eatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _eatAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _eatController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    // 페이지 나갈 때 스낵바 제거
    ScaffoldMessenger.of(context).clearSnackBars();
    _eatController.dispose();
    super.dispose();
  }

  Future<void> _feedCharacter() async {
    if (_isEating) return;
    setState(() => _isEating = true);
    _eatController.forward(from: 0);

    final message = await CharacterService.feedCharacter();

    if (mounted) {
      setState(() => _isEating = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: _bgGradientTop,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

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
          '밥먹기',
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
    String assetPath = 'assets/characters/chick_lv1.png';
    if (character.emotionPoints >= 400) {
      assetPath = 'assets/characters/chick_lv4.png';
    } else if (character.emotionPoints >= 200) {
      assetPath = 'assets/characters/chick_lv3.png';
    } else if (character.emotionPoints >= 100) {
      assetPath = 'assets/characters/chick_lv2.png';
    }

    final hunger = character.hunger.clamp(0.0, 1.0);

    return Column(
      children: [
        const SizedBox(height: 20),
        _buildInfoCard(character),
        const SizedBox(height: 16),
        _buildHungerBar(hunger),
        const Spacer(),
        _buildCharacterWithTable(assetPath),
        const SizedBox(height: 40),
        _buildFoodMenu(),
        const SizedBox(height: 24),
        _buildFeedButton(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildInfoCard(Character character) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem(
            Icons.favorite,
            '애정도',
            '${(character.affection * 100).toInt()}%',
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildInfoItem(Icons.star, '레벨', 'Lv.${character.level}'),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildInfoItem(
            Icons.monetization_on,
            '포인트',
            '${character.emotionPoints}P',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: _accentYellow, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildHungerBar(double hunger) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🍽️ 배부름',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${(hunger * 100).toInt()}%',
                style: const TextStyle(
                  color: _accentYellow,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: hunger,
              minHeight: 10,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(
                hunger < 0.3 ? Colors.red : _accentYellow,
              ),
            ),
          ),
          if (hunger < 0.3)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                '배가 고파요! 밥을 주세요~ 🥺',
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCharacterWithTable(String assetPath) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(bottom: 0, child: _buildDiningTable()),
        AnimatedBuilder(
          animation: _eatAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _isEating ? -20 * _eatAnimation.value : 0),
              child: Transform.scale(
                scale: _isEating ? 1 + 0.1 * _eatAnimation.value : 1,
                child: child,
              ),
            );
          },
          child: Image.asset(assetPath, width: 200, height: 200),
        ),
        if (_isEating)
          const Positioned(
            top: 20,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('냠냠', style: TextStyle(fontSize: 24, color: Colors.white)),
                SizedBox(width: 8),
                Text('😋', style: TextStyle(fontSize: 32)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDiningTable() {
    return Container(
      width: 280,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF8B4513),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(140)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 100,
          height: 40,
          margin: const EdgeInsets.only(top: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Center(
            child: Text(
              _selectedFood != null ? _foods[_selectedFood!]['emoji'] : '🍽️',
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFoodMenu() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _foods.length,
        itemBuilder: (context, index) {
          final food = _foods[index];
          final isSelected = _selectedFood == index;

          return GestureDetector(
            onTap: () => setState(() => _selectedFood = index),
            child: Container(
              width: 80,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected ? _accentYellow : Colors.black26,
                borderRadius: BorderRadius.circular(16),
                border:
                    isSelected
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(food['emoji'], style: const TextStyle(fontSize: 32)),
                  const SizedBox(height: 4),
                  Text(
                    food['name'],
                    style: TextStyle(
                      color: isSelected ? Colors.black87 : Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeedButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isEating ? null : _feedCharacter,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentYellow,
            foregroundColor: Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child:
              _isEating
                  ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black54,
                    ),
                  )
                  : const Text(
                    '🍽️ 밥 주기',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
        ),
      ),
    );
  }
}
