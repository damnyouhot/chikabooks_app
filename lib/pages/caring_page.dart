import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/character.dart';
import '../models/furniture.dart';
import '../services/character_service.dart';
import '../services/furniture_service.dart';
import 'dressup_page.dart';
import 'feeding_page.dart';
import 'furniture_page.dart';
import 'rest_page.dart';
import 'growth/study/study_tab.dart';

/// 홈 화면 - 아이소메트릭 방 UI
class CaringPage extends StatefulWidget {
  const CaringPage({super.key});

  @override
  State<CaringPage> createState() => _CaringPageState();
}

class _CaringPageState extends State<CaringPage> with TickerProviderStateMixin {
  // 캐릭터 터치/문지르기 애니메이션
  late AnimationController _heartController;
  late Animation<double> _heartAnimation;

  // 문지르기 감지용
  int _petCount = 0;
  DateTime? _lastPetTime;

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
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  // 캐릭터 터치 시
  void _onCharacterTap() async {
    _heartController.forward(from: 0.0);
    final message = await CharacterService.petCharacter();
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  // 일일 출석 체크
  void _onCheckIn() async {
    final message = await CharacterService.dailyCheckIn();
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.accent,
          ),
        );
    }
  }

  // 캐릭터 문지르기 시
  void _onCharacterPan(DragUpdateDetails details) async {
    final now = DateTime.now();
    if (_lastPetTime == null ||
        now.difference(_lastPetTime!).inMilliseconds > 100) {
      _petCount++;
      _lastPetTime = now;

      // 5번 문지를 때마다 하트 이펙트 + 포인트
      if (_petCount % 5 == 0) {
        _heartController.forward(from: 0.0);
        final message = await CharacterService.petCharacter();
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(message),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      }
    }
  }

  void _onCharacterPanEnd(DragEndDetails details) {
    _petCount = 0;
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
          return Container(
            color: AppColors.background,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final character = snapshot.data!;
        return _buildHomeUI(context, character);
      },
    );
  }

  Widget _buildHomeUI(BuildContext context, Character character) {
    final screenSize = MediaQuery.of(context).size;

    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            // 상단 헤더 (레벨, 포인트)
            _buildHeader(character),

            // 중앙: 아이소메트릭 방 + 버튼들
            Expanded(flex: 3, child: _buildRoomSection(context, screenSize)),

            // 하단: 캐릭터 (터치/문지르기)
            Expanded(flex: 2, child: _buildCharacterSection(character)),
          ],
        ),
      ),
    );
  }

  /// 상단 헤더: 레벨 (좌) / 출석 (중) / 포인트 (우)
  Widget _buildHeader(Character character) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 레벨 배지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: AppColors.gold, size: 18),
                const SizedBox(width: 4),
                Text(
                  'Lv. ${character.level}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // 출석 체크 버튼
          GestureDetector(
            onTap: _onCheckIn,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    '출석',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 포인트 배지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      '\$',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${character.emotionPoints}P',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 중앙 섹션: 아이소메트릭 방 + 가구 + 버튼들
  Widget _buildRoomSection(BuildContext context, Size screenSize) {
    return StreamBuilder<List<PlacedFurniture>>(
      stream: FurnitureService.watchPlacedFurniture(),
      builder: (context, furnitureSnapshot) {
        final placedFurniture = furnitureSnapshot.data ?? [];

        return Center(
          child: AspectRatio(
            aspectRatio: 1.0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 아이소메트릭 방 배경 이미지
                Positioned.fill(
                  child: Image.asset(
                    'assets/home/home_basic.png',
                    fit: BoxFit.contain,
                  ),
                ),

                // 배치된 가구들 표시
                ...placedFurniture.map((placed) {
                  return _buildPlacedFurniture(placed, screenSize.width);
                }),

                // 가구 상점 버튼 (우측 상단)
                Positioned(
                  top: screenSize.width * 0.05,
                  right: screenSize.width * 0.05,
                  child: _buildRoomButton(
                    context,
                    label: '🛋️ 가구',
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FurniturePage(),
                          ),
                        ),
                  ),
                ),

                // 공부 버튼 (책상 위치 - 좌측 상단)
                Positioned(
                  top: screenSize.width * 0.18,
                  left: screenSize.width * 0.12,
                  child: _buildRoomButton(
                    context,
                    label: '공부',
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const StudyTab()),
                        ),
                  ),
                ),

                // 꾸미기 버튼 (옷장 위치 - 중앙 상단)
                Positioned(
                  top: screenSize.width * 0.22,
                  left: screenSize.width * 0.30,
                  child: _buildRoomButton(
                    context,
                    label: '꾸미기',
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DressUpPage(),
                          ),
                        ),
                  ),
                ),

                // 휴식 버튼 (침대 위치 - 좌측)
                Positioned(
                  top: screenSize.width * 0.32,
                  left: screenSize.width * 0.02,
                  child: _buildRoomButton(
                    context,
                    label: '휴식',
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RestPage()),
                        ),
                  ),
                ),

                // 밥먹기 버튼 (식탁 위치 - 중앙 하단)
                Positioned(
                  top: screenSize.width * 0.48,
                  left: screenSize.width * 0.28,
                  child: _buildRoomButton(
                    context,
                    label: '밥먹기',
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FeedingPage(),
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 배치된 가구 위젯 (아이소메트릭 좌표로 변환)
  Widget _buildPlacedFurniture(PlacedFurniture placed, double roomSize) {
    final definition = placed.definition;
    if (definition == null) return const SizedBox.shrink();

    // 아이소메트릭 타일 크기 (방 이미지 기준)
    const tileHeight = 0.12; // 타일 높이 비율

    // gridY에 따른 세로 위치 계산 (2칸씩 차지)
    final baseY = 0.15 + (placed.gridY * tileHeight * 2);

    // L(왼쪽 벽) / R(오른쪽 벽)에 따른 가로 위치
    double baseX;
    if (definition.direction == FurnitureDirection.L) {
      // 왼쪽 벽: 왼쪽에서 약간 안쪽으로
      baseX = 0.02 + (placed.gridY * 0.08); // 아이소메트릭 보정
    } else {
      // 오른쪽 벽: 오른쪽에서 약간 안쪽으로
      baseX = 0.55 - (placed.gridY * 0.08); // 아이소메트릭 보정
    }

    return Positioned(
      top: roomSize * baseY,
      left: roomSize * baseX,
      child: Image.asset(
        definition.assetPath,
        width: roomSize * 0.25,
        height: roomSize * 0.25,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  /// 방 안의 인터랙티브 버튼
  Widget _buildRoomButton(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 하단 섹션: 캐릭터 (터치/문지르기)
  Widget _buildCharacterSection(Character character) {
    // 감정 점수에 따른 캐릭터 이미지
    String assetPath;
    if (character.emotionPoints < 100) {
      assetPath = 'assets/characters/chick_lv1.png';
    } else if (character.emotionPoints < 200) {
      assetPath = 'assets/characters/chick_lv2.png';
    } else if (character.emotionPoints < 400) {
      assetPath = 'assets/characters/chick_lv3.png';
    } else {
      assetPath = 'assets/characters/chick_lv4.png';
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // 캐릭터 (터치/문지르기 가능)
        GestureDetector(
          onTap: _onCharacterTap,
          onPanUpdate: _onCharacterPan,
          onPanEnd: _onCharacterPanEnd,
          child: Image.asset(
            assetPath,
            width: 180,
            height: 180,
            fit: BoxFit.contain,
          ),
        ),

        // 하트 이펙트
        Positioned(
          top: 0,
          child: FadeTransition(
            opacity: _heartAnimation.drive(CurveTween(curve: Curves.easeOut)),
            child: SlideTransition(
              position: _heartAnimation.drive(
                Tween(begin: const Offset(0, 0), end: const Offset(0, -1.5)),
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
    );
  }
}
