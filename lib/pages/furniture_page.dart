import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/character.dart';
import '../models/furniture.dart';
import '../services/character_service.dart';
import '../services/furniture_service.dart';

/// 가구 상점 & 배치 페이지
class FurniturePage extends StatefulWidget {
  const FurniturePage({super.key});

  @override
  State<FurniturePage> createState() => _FurniturePageState();
}

class _FurniturePageState extends State<FurniturePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    if (user == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다.')));
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('가구 상점'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '상점', icon: Icon(Icons.shopping_cart)),
            Tab(text: '내 가구', icon: Icon(Icons.inventory_2)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FurnitureShopTab(userId: user.uid),
          _MyFurnitureTab(userId: user.uid),
        ],
      ),
    );
  }
}

/// 가구 상점 탭
class _FurnitureShopTab extends StatelessWidget {
  final String userId;
  const _FurnitureShopTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Character?>(
      stream: CharacterService.watchCharacter(userId),
      builder: (context, snapshot) {
        final character = snapshot.data;
        final currentPoints = character?.emotionPoints ?? 0;

        return Column(
          children: [
            // 보유 포인트 표시
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppColors.cardBg,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.monetization_on, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Text(
                    '보유 포인트: ${currentPoints}P',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 가구 목록
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemCount: FurnitureDefinition.all.length,
                itemBuilder: (context, index) {
                  final furniture = FurnitureDefinition.all[index];
                  final canAfford = currentPoints >= furniture.price;

                  return _FurnitureCard(
                    furniture: furniture,
                    canAfford: canAfford,
                    onBuy: () => _buyFurniture(context, furniture),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _buyFurniture(
    BuildContext context,
    FurnitureDefinition furniture,
  ) async {
    final result = await FurnitureService.purchaseFurniture(furniture.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text(result), behavior: SnackBarBehavior.floating),
        );
    }
  }
}

/// 가구 카드 위젯
class _FurnitureCard extends StatelessWidget {
  final FurnitureDefinition furniture;
  final bool canAfford;
  final VoidCallback onBuy;

  const _FurnitureCard({
    required this.furniture,
    required this.canAfford,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 가구 이미지
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Image.asset(
                furniture.assetPath,
                fit: BoxFit.contain,
                errorBuilder:
                    (_, __, ___) => const Icon(
                      Icons.chair,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
          ),
          // 가구 정보
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      furniture.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            furniture.direction == FurnitureDirection.L
                                ? Colors.blue[100]
                                : Colors.orange[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        furniture.direction == FurnitureDirection.L
                            ? '왼쪽'
                            : '오른쪽',
                        style: TextStyle(
                          fontSize: 10,
                          color:
                              furniture.direction == FurnitureDirection.L
                                  ? Colors.blue[800]
                                  : Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canAfford ? onBuy : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          canAfford ? AppColors.accent : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('${furniture.price}P'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 내 가구 탭
class _MyFurnitureTab extends StatelessWidget {
  final String userId;
  const _MyFurnitureTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OwnedFurniture>>(
      stream: FurnitureService.watchOwnedFurniture(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final ownedList = snapshot.data!;
        if (ownedList.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                SizedBox(height: 16),
                Text(
                  '보유한 가구가 없습니다.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                SizedBox(height: 8),
                Text(
                  '상점에서 가구를 구매해보세요!',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        // 배치됨 / 보관중 분리
        final placed = ownedList.where((f) => f.isPlaced).toList();
        final stored = ownedList.where((f) => !f.isPlaced).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (stored.isNotEmpty) ...[
              const Text(
                '📦 보관 중',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...stored.map(
                (f) => _OwnedFurnitureItem(furniture: f, isPlaced: false),
              ),
              const SizedBox(height: 24),
            ],
            if (placed.isNotEmpty) ...[
              const Text(
                '🏠 배치됨',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...placed.map(
                (f) => _OwnedFurnitureItem(furniture: f, isPlaced: true),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// 보유 가구 아이템 위젯
class _OwnedFurnitureItem extends StatelessWidget {
  final OwnedFurniture furniture;
  final bool isPlaced;

  const _OwnedFurnitureItem({required this.furniture, required this.isPlaced});

  @override
  Widget build(BuildContext context) {
    final definition = furniture.definition;
    if (definition == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Image.asset(
            definition.assetPath,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.chair),
          ),
        ),
        title: Text(definition.name),
        subtitle: Text(
          definition.direction == FurnitureDirection.L ? '왼쪽 벽' : '오른쪽 벽',
          style: const TextStyle(fontSize: 12),
        ),
        trailing:
            isPlaced
                ? TextButton(
                  onPressed: () => _removeFurniture(context),
                  child: const Text('수납', style: TextStyle(color: Colors.red)),
                )
                : ElevatedButton(
                  onPressed: () => _showPlaceDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('배치'),
                ),
      ),
    );
  }

  void _showPlaceDialog(BuildContext context) {
    final definition = furniture.definition;
    if (definition == null) return;

    // 배치 위치 선택 다이얼로그
    int selectedY = 0;
    final maxY =
        definition.direction == FurnitureDirection.L
            ? 2
            : 2; // 2칸씩 차지하므로 최대 3개 배치 가능

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text('${definition.name} 배치'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('배치 위치를 선택하세요:'),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(3, (i) {
                          final isSelected = selectedY == i;
                          return GestureDetector(
                            onTap: () => setState(() => selectedY = i),
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? AppColors.accent
                                        : AppColors.cardBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? AppColors.accentDark
                                          : Colors.grey,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}번',
                                  style: TextStyle(
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        final result = await FurnitureService.placeFurniture(
                          ownedFurnitureId: furniture.id,
                          gridX:
                              definition.direction == FurnitureDirection.L
                                  ? 0
                                  : 1,
                          gridY: selectedY,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(result),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                      ),
                      child: const Text('배치'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _removeFurniture(BuildContext context) async {
    final result = await FurnitureService.removeFurniture(furniture.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text(result), behavior: SnackBarBehavior.floating),
        );
    }
  }
}
