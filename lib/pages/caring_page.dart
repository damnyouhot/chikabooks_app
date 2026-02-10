import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/character.dart';
import '../models/store_item.dart';
import '../services/activity_log_service.dart';
import '../services/bond_score_service.dart';
import '../services/character_service.dart';
import '../services/partner_dialogue_service.dart';
import '../services/store_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/daily_wall_sheet.dart';
import '../widgets/partner_summary_card.dart';
import '../widgets/profile_gate_sheet.dart';
import 'growth/character_widget.dart';
import 'growth/emotion_record_page.dart';
import 'partner_page.dart';

class CaringPage extends StatefulWidget {
  const CaringPage({super.key});

  @override
  State<CaringPage> createState() => _CaringPageState();
}

class _CaringPageState extends State<CaringPage>
    with TickerProviderStateMixin {
  late AnimationController _heartAnimationController;
  late Animation<double> _heartAnimation;
  late AnimationController _sparkleAnimationController;
  late Animation<double> _sparkleAnimation;

  // 파트너 소식 관련
  String? _partnerGroupId;
  String? _ambientLine; // 캐릭터 우회 멘트

  @override
  void initState() {
    super.initState();
    _heartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _heartAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _heartAnimationController, curve: Curves.easeOut),
    );
    _sparkleAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _sparkleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _sparkleAnimationController, curve: Curves.easeInOut),
    );
    _loadPartnerState();
  }

  /// 파트너 그룹 + 결 중심회귀 + 캐릭터 우회 멘트
  Future<void> _loadPartnerState() async {
    try {
      final groupId = await UserProfileService.getPartnerGroupId();

      // 결 점수 중심 회귀 (하루 1회)
      await BondScoreService.applyCenterGravity();

      if (groupId != null) {
        // unread 로그로 캐릭터 우회 멘트 생성
        final logs = await ActivityLogService.getUnreadLogs(groupId);
        final line = PartnerDialogueService.generateAmbientLine(logs);

        if (mounted) {
          setState(() {
            _partnerGroupId = groupId;
            _ambientLine = line;
          });
        }
      }
    } catch (_) {
      // 에러 무시 (파트너 기능 없어도 앱은 동작)
    }
  }

  @override
  void dispose() {
    _heartAnimationController.dispose();
    _sparkleAnimationController.dispose();
    super.dispose();
  }

  void _onFeed() {
    CharacterService.feedCharacter();
    if (mounted) {
      _heartAnimationController.forward(from: 0.0);
    }
  }

  void _onCheerUp() async {
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EmotionRecordPage()),
    );
    if (success == true && mounted) {
      _sparkleAnimationController.forward(from: 0.0);
    }
  }

  /// 프로필 게이트 → DailyWallSheet 열기
  void _openDailyWall(BuildContext context) async {
    final hasProfile = await UserProfileService.hasBasicProfile();
    if (!context.mounted) return;

    if (!hasProfile) {
      // Step A 프로필 입력 먼저
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ProfileGateSheet(
          onComplete: () {
            // 프로필 저장 완료 → DailyWallSheet 열기
            if (context.mounted) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const DailyWallSheet(),
              );
            }
          },
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const DailyWallSheet(),
      );
    }
  }

  /// 파트너 진입: Step A 게이트 → PartnerPage
  void _openPartner(BuildContext context) async {
    final hasProfile = await UserProfileService.hasBasicProfile();
    if (!context.mounted) return;

    if (!hasProfile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ProfileGateSheet(
          onComplete: () {
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PartnerPage()),
              );
            }
          },
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PartnerPage()),
      );
    }
  }

  void _showInventory(BuildContext context, Character character) {
    final storeService = context.read<StoreService>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FutureBuilder<List<StoreItem>>(
          future: storeService.fetchMyItems(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox(
                height: 200,
                child: Center(child: Text('보유한 아이템이 없습니다.')),
              );
            }
            final myItems = snapshot.data!;
            return GridView.builder(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
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
                        child: Icon(Icons.do_not_disturb_on,
                            color: Colors.white),
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
                                border: Border.all(
                                    color: Colors.green, width: 3),
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
    return Stack(
      children: [
        // ── 배경 이미지 ──
        Positioned.fill(
          child: Image.asset(
            'assets/dreamy background/dreamy background.png',
            fit: BoxFit.cover,
          ),
        ),

        // ── 콘텐츠 ──
        SafeArea(
          child: Column(
            children: [
              // ── 상단: 레벨 & 포인트 뱃지 ──
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildBadge(
                      icon: Icons.star_rounded,
                      label: 'Lv.${character.level}',
                      color: const Color(0xFFFFD54F),
                    ),
                    _buildBadge(
                      icon: Icons.favorite,
                      label: '${character.emotionPoints} P',
                      color: const Color(0xFFFF8A80),
                    ),
                  ],
                ),
              ),

              // ── 캐릭터 영역 ──
              Expanded(
                flex: 5,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    const CharacterWidget(),
                    // 하트 애니메이션
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
                    // 반짝임 애니메이션
                    Positioned.fill(
                      child: IgnorePointer(
                        child: FadeTransition(
                          opacity: _sparkleAnimation.drive(CurveTween(
                              curve: const Interval(0.0, 0.2,
                                  curve: Curves.easeIn))),
                          child: FadeTransition(
                            opacity: _sparkleAnimation.drive(CurveTween(
                                curve: const Interval(0.8, 1.0,
                                    curve: Curves.easeOut))),
                            child: const Icon(Icons.auto_awesome,
                                color: Colors.amber, size: 80),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── 캐릭터 우회 멘트 (파트너 소식 기반) ──
              if (_ambientLine != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _ambientLine!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),

              // ── 캡슐 버튼 행: 오늘의 한 문장 + 파트너 ──
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 오늘의 한 문장
                    _buildCapsuleButton(
                      icon: '✍️',
                      label: '오늘의 한 문장',
                      onTap: () => _openDailyWall(context),
                    ),
                    const SizedBox(width: 10),
                    // 파트너
                    _buildCapsuleButton(
                      icon: '🤝',
                      label: '파트너',
                      onTap: () => _openPartner(context),
                    ),
                  ],
                ),
              ),

              // ── 파트너 소식 요약 카드 ──
              if (_partnerGroupId != null)
                PartnerSummaryCard(groupId: _partnerGroupId!),

              // ── 액션 버튼 ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.edit_note,
                      label: '응원',
                      onTap: _onCheerUp,
                      color: const Color(0xFFCE93D8),
                    ),
                    _buildActionButton(
                      icon: Icons.restaurant,
                      label: '밥주기',
                      onTap: _onFeed,
                      color: const Color(0xFFFFAB91),
                    ),
                    _buildActionButton(
                      icon: Icons.check_circle_outline,
                      label: '출석',
                      onTap: () async {
                        final message =
                            await CharacterService.dailyCheckIn();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(message)));
                        }
                      },
                      color: const Color(0xFF81D4FA),
                    ),
                    _buildActionButton(
                      icon: Icons.checkroom,
                      label: '꾸미기',
                      onTap: () => _showInventory(context, character),
                      color: const Color(0xFFA5D6A7),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── 능력치 게이지 패널 ──
              Expanded(
                flex: 4,
                child: _buildStatPanel(character),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 상단 뱃지 위젯 ──
  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  // ── 액션 버튼 ──
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.95),
              shadows: const [
                Shadow(color: Colors.black26, blurRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 캡슐 버튼 빌더 ──
  Widget _buildCapsuleButton({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6A5ACD).withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6A5ACD),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 능력치 게이지 패널 (하단 카드) ──
  Widget _buildStatPanel(Character character) {
    final affection = character.affection.clamp(0.0, 1.0);
    final hunger = character.hunger.clamp(0.0, 1.0);
    final energy = (1.0 - character.fatigue).clamp(0.0, 1.0);

    // 지혜: 학습분 + 퀴즈수 기반 (최대 100으로 정규화)
    final wisdomRaw =
        (character.studyMinutes / 60.0) + (character.quizCount * 10);
    final wisdom = (wisdomRaw / 100.0).clamp(0.0, 1.0);

    // 경험치 진행률
    final expNeeded = character.level * character.level * 100;
    final expProgress =
        expNeeded > 0 ? (character.experience / expNeeded).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            const Center(
              child: Text(
                '✨ 나의 상태',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6A5ACD),
                ),
              ),
            ),
            const SizedBox(height: 12),

            _buildGaugeBar(
              label: '❤️ 애정도',
              value: affection,
              color: const Color(0xFFFF8A80),
            ),
            _buildGaugeBar(
              label: '🍽️ 포만감',
              value: hunger,
              color: const Color(0xFFFFAB91),
              warningThreshold: 0.3,
              warningText: '배고파요!',
            ),
            _buildGaugeBar(
              label: '💪 기력',
              value: energy,
              color: const Color(0xFF81D4FA),
              warningThreshold: 0.3,
              warningText: '피곤해요..',
            ),
            _buildGaugeBar(
              label: '📚 지혜',
              value: wisdom,
              color: const Color(0xFFCE93D8),
            ),
            _buildGaugeBar(
              label: '⭐ 경험치',
              value: expProgress,
              color: const Color(0xFFFFD54F),
              suffix: ' (Lv.${character.level})',
            ),
          ],
        ),
      ),
    );
  }

  // ── 게이지 바 위젯 ──
  Widget _buildGaugeBar({
    required String label,
    required double value,
    required Color color,
    double? warningThreshold,
    String? warningText,
    String? suffix,
  }) {
    final percentage = (value * 100).toInt();
    final isWarning =
        warningThreshold != null && value < warningThreshold;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF424242),
                    ),
                  ),
                  if (suffix != null)
                    Text(
                      suffix,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  if (isWarning && warningText != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        warningText,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isWarning ? Colors.redAccent : color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 10,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                isWarning ? Colors.redAccent : color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
