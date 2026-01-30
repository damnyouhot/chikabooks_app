import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/character.dart';
import '../services/character_service.dart';
import '../widgets/unicorn_sprite_widget.dart';

/// 휴식 페이지 - 캐릭터 피로도 회복
class RestPage extends StatefulWidget {
  const RestPage({super.key});

  @override
  State<RestPage> createState() => _RestPageState();
}

class _RestPageState extends State<RestPage>
    with SingleTickerProviderStateMixin {
  // 컬러 팔레트 - 편안한 밤 분위기
  static const _bgGradientTop = Color(0xFF2C3E50);
  static const _bgGradientBottom = Color(0xFF1A252F);
  static const _accentBlue = Color(0xFF74B9FF);
  static const _moonYellow = Color(0xFFFEF9C3);

  late AnimationController _sleepController;
  late Animation<double> _sleepAnimation;
  bool _isResting = false;

  @override
  void initState() {
    super.initState();
    _sleepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _sleepAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _sleepController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _sleepController.dispose();
    super.dispose();
  }

  Future<void> _onRest() async {
    if (_isResting) return;

    setState(() => _isResting = true);
    _sleepController.repeat(reverse: true);

    // 2초 대기 후 휴식 완료
    await Future.delayed(const Duration(seconds: 2));
    final message = await CharacterService.rest();

    if (mounted) {
      _sleepController.stop();
      setState(() => _isResting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: _bgGradientTop,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
              child: CircularProgressIndicator(color: _accentBlue),
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
          '휴식',
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
    final fatigue = character.fatigue.clamp(0.0, 1.0);

    return Column(
      children: [
        const SizedBox(height: 20),

        // 상단 정보
        _buildInfoCard(character),

        const Spacer(),

        // 침대 + 캐릭터
        Stack(
          alignment: Alignment.center,
          children: [
            // 침대
            _buildBed(),
            // 유니콘 캐릭터
            AnimatedBuilder(
              animation: _sleepAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    0,
                    _isResting ? -10 * _sleepAnimation.value : 0,
                  ),
                  child: Opacity(
                    opacity:
                        _isResting ? 0.7 + 0.3 * _sleepAnimation.value : 1.0,
                    child: child,
                  ),
                );
              },
              child: const UnicornSpriteWidget(
                size: 150,
                fps: 8,
                showDialogue: false,
              ),
            ),
            // 수면 이펙트 (Z Z Z)
            if (_isResting)
              Positioned(top: 20, right: 60, child: _buildSleepEffect()),
          ],
        ),

        const SizedBox(height: 40),

        // 피로도 바
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '😴 피로도',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${(fatigue * 100).toInt()}%',
                    style: const TextStyle(
                      color: _accentBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: fatigue,
                  minHeight: 12,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    fatigue > 0.7 ? Colors.red : _accentBlue,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // 휴식하기 버튼
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isResting ? null : _onRest,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child:
                  _isResting
                      ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('쉬는 중...', style: TextStyle(fontSize: 18)),
                        ],
                      )
                      : const Text(
                        '💤 휴식하기',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // 수면 시간 기록
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bedtime_rounded, color: _moonYellow, size: 24),
              const SizedBox(width: 12),
              Text(
                '총 수면 시간: ${character.sleepHours.toStringAsFixed(1)} 시간',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),

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
            icon: Icons.favorite,
            label: '애정도',
            value: '${(character.affection * 100).toInt()}%',
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildInfoItem(
            icon: Icons.monetization_on,
            label: '교감 포인트',
            value: '${character.emotionPoints}P',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: _accentBlue, size: 24),
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

  Widget _buildBed() {
    return Container(
      width: 240,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF5D4E6D),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 이불
          Positioned(
            top: 10,
            left: 20,
            right: 20,
            bottom: 20,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF8B7DA8),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // 베개
          Positioned(
            top: 15,
            left: 30,
            child: Container(
              width: 60,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepEffect() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: const Column(
            children: [
              Text('Z', style: TextStyle(color: Colors.white70, fontSize: 24)),
              Text('Z', style: TextStyle(color: Colors.white54, fontSize: 20)),
              Text('z', style: TextStyle(color: Colors.white38, fontSize: 16)),
            ],
          ),
        );
      },
    );
  }
}
