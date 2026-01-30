import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/reward_constants.dart';
import '../main.dart';
import '../providers/character_status_provider.dart';
import '../widgets/unicorn_sprite_widget.dart';

/// 홈 화면 - 캐릭터 교감 UI
class CaringPage extends StatefulWidget {
  const CaringPage({super.key});

  @override
  State<CaringPage> createState() => _CaringPageState();
}

class _CaringPageState extends State<CaringPage> with TickerProviderStateMixin {
  // 유니콘 위젯 제어용 키
  final GlobalKey<UnicornSpriteWidgetState> _unicornKey = GlobalKey();

  // 캐릭터 터치 애니메이션
  late AnimationController _heartController;
  late Animation<double> _heartAnimation;

  // 말풍선 애니메이션
  late AnimationController _dialogueController;
  String _currentDialogue = '';
  bool _showDialogue = false;

  // 쿨타임 표시용 타이머
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _heartAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _heartController, curve: Curves.easeOut));

    _dialogueController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // 쿨타임 갱신 타이머
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _heartController.dispose();
    _dialogueController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  /// 말풍선 표시
  void _showDialogueBubble(String message) {
    setState(() {
      _currentDialogue = message;
      _showDialogue = true;
    });
    _dialogueController.forward(from: 0.0);

    // 3초 후 자동으로 사라짐
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showDialogue = false);
      }
    });
  }

  /// 캐릭터 터치 (쓰다듬기) - UnicornSpriteWidget의 onTap에서 호출됨
  void _onCharacterTap() async {
    final provider = context.read<CharacterStatusProvider>();
    final message = await provider.pet();

    _heartController.forward(from: 0.0);
    _showDialogueBubble(message);
    
    // playTouchReaction()은 UnicornSpriteWidget 내부에서 이미 호출됨
    // 이중 호출 방지를 위해 여기서는 호출하지 않음
  }

  /// 확인하기 버튼
  void _onCheck() async {
    final provider = context.read<CharacterStatusProvider>();
    final message = await provider.checkCharacter();
    _showDialogueBubble(message);
  }

  /// 일반식 먹기
  void _onEatMeal() async {
    final provider = context.read<CharacterStatusProvider>();
    
    // 포만감 100이면 거부 애니메이션
    if (provider.fullness >= 100) {
      _unicornKey.currentState?.playNo();
      _showDialogueBubble('배가 너무 불러요~ 🙅');
      return;
    }
    
    final message = await provider.eatMeal();
    _showDialogueBubble(message);
    // 먹기 애니메이션 재생
    _unicornKey.currentState?.playEating();
  }

  /// 간식 먹기
  void _onEatSnack() async {
    final provider = context.read<CharacterStatusProvider>();
    
    // 포만감 100이면 거부 애니메이션
    if (provider.fullness >= 100) {
      _unicornKey.currentState?.playNo();
      _showDialogueBubble('배가 너무 불러요~ 🙅');
      return;
    }
    
    final message = await provider.eatSnack();
    _showDialogueBubble(message);
    // 먹기 애니메이션 재생
    _unicornKey.currentState?.playEating();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    if (user == null) {
      return const Center(child: Text('로그인이 필요합니다.'));
    }

    return Consumer<CharacterStatusProvider>(
      builder: (context, status, _) {
        return Stack(
          children: [
            // 배경 이미지 (화면 꽉 채우기, 좌우 잘림)
            Positioned.fill(
              child: Image.asset(
                'assets/dreamy background/dreamy background.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
            // 콘텐츠
            SafeArea(
              child: Column(
                children: [
                  // 상단: 상태 바들
                  _buildStatusBars(status),

                  // 중앙: 캐릭터 + 말풍선
                  Expanded(child: _buildCharacterArea(status)),

                  // 하단: 액션 버튼들
                  _buildActionButtons(status),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// 상단 상태 바들
  Widget _buildStatusBars(CharacterStatusProvider status) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          // 포만감
          _buildStatusBar(
            icon: Icons.restaurant,
            label: '포만감',
            value: status.fullness,
            color: Colors.orange,
          ),
          const SizedBox(height: 8),
          // 애정도
          _buildStatusBar(
            icon: Icons.favorite,
            label: '애정도',
            value: status.affection,
            color: Colors.pinkAccent,
          ),
          const SizedBox(height: 8),
          // 건강
          _buildStatusBar(
            icon: Icons.health_and_safety,
            label: '건강',
            value: status.health,
            color: Colors.green,
          ),
          const SizedBox(height: 8),
          // 정신력
          _buildStatusBar(
            icon: Icons.psychology,
            label: '정신',
            value: status.spirit,
            color: Colors.purple,
          ),
          const SizedBox(height: 8),
          // 지혜 (무제한이라 다르게 표시)
          _buildWisdomBar(status.wisdom),
        ],
      ),
    );
  }

  Widget _buildStatusBar({
    required IconData icon,
    required String label,
    required double value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '${value.toInt()}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildWisdomBar(double wisdom) {
    return Row(
      children: [
        const Icon(Icons.auto_stories, color: Colors.amber, size: 20),
        const SizedBox(width: 8),
        const SizedBox(
          width: 50,
          child: Text(
            '지혜',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [Colors.amber, Colors.orange],
              ),
            ),
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '${wisdom.toInt()} ✨',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const SizedBox(
          width: 40,
          child: Text(
            '∞',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.amber,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  /// 중앙: 캐릭터 영역 (배경 단상 위에 배치 + 그림자)
  Widget _buildCharacterArea(CharacterStatusProvider status) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 감정 상태 배지
        Positioned(top: 10, child: _buildEmotionBadge(status.currentEmotion)),

        // 캐릭터 + 그림자 (터치 가능) - 단상 위에 배치
        Positioned(
          bottom: 20,  // 단상 위에 위치하도록 조정
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 말풍선
              if (_showDialogue)
                FadeTransition(
                  opacity: _dialogueController,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 250),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      _currentDialogue,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              // 유니콘 캐릭터 + 하트 이펙트
              Stack(
                alignment: Alignment.center,
                children: [
                  UnicornSpriteWidget(
                    key: _unicornKey,
                    size: 280,  // 단상에 맞게 크기 조정
                    fps: 12,
                    showDialogue: false,
                    onTap: _onCharacterTap,  // 터치 콜백을 여기서 전달
                  ),

                  // 하트 이펙트
                  Positioned(
                    top: -20,
                    child: FadeTransition(
                      opacity: _heartAnimation,
                      child: SlideTransition(
                        position: _heartAnimation.drive(
                          Tween(
                            begin: const Offset(0, 0),
                            end: const Offset(0, -1.5),
                          ),
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.pinkAccent,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // 쓰다듬기 상태
              const SizedBox(height: 15),
              _buildPetStatus(status),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmotionBadge(CharacterEmotion emotion) {
    String label;
    Color color;
    IconData icon;

    switch (emotion) {
      case CharacterEmotion.burnout:
        label = '번아웃';
        color = Colors.grey;
        icon = Icons.battery_0_bar;
        break;
      case CharacterEmotion.hungry:
        label = '배고파요';
        color = Colors.orange;
        icon = Icons.restaurant;
        break;
      case CharacterEmotion.lonely:
        label = '외로워요';
        color = Colors.blue;
        icon = Icons.sentiment_dissatisfied;
        break;
      case CharacterEmotion.bestCondition:
        label = '최고 컨디션!';
        color = Colors.green;
        icon = Icons.star;
        break;
      case CharacterEmotion.idle:
        label = '평온해요';
        color = AppColors.accent;
        icon = Icons.sentiment_satisfied;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetStatus(CharacterStatusProvider status) {
    if (!status.canPet) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '쉬는 중... ${status.petCooldownRemaining}초',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.pink[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('터치해서 쓰다듬기 ', style: TextStyle(fontSize: 12)),
          ...List.generate(
            CharacterStats.petMaxConsecutive,
            (i) => Icon(
              Icons.favorite,
              size: 14,
              color: i < status.petCount ? Colors.pinkAccent : Colors.grey[300],
            ),
          ),
        ],
      ),
    );
  }

  /// 하단: 액션 버튼들
  Widget _buildActionButtons(CharacterStatusProvider status) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          // 첫 번째 줄: 확인하기, 일반식, 간식
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.visibility,
                  label: '확인하기',
                  sublabel: '${status.checkRemaining}회 남음',
                  color: Colors.blue,
                  onTap: status.canCheck ? _onCheck : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.restaurant,
                  label: '일반식',
                  sublabel: '+${CharacterStats.mealFullnessIncrease.toInt()}',
                  color: Colors.orange,
                  onTap: _onEatMeal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.cookie,
                  label: '간식',
                  sublabel: '+${CharacterStats.snackFullnessIncrease.toInt()}',
                  color: Colors.amber,
                  onTap: _onEatSnack,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey[200] : color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDisabled ? Colors.grey[300]! : color.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isDisabled ? Colors.grey : color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isDisabled ? Colors.grey : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            Text(
              sublabel,
              style: TextStyle(
                color: isDisabled ? Colors.grey : color,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
