import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/store_item.dart';
import '../services/store_service.dart';
import '../services/user_action_service.dart';

/// 꾸미기 페이지 — 원 스킨 / 오라 스킨 장착
///
/// 캐릭터 삭제 후, 꾸미기 대상이 "원 + 오라"로 전환됨.
/// Phase 1~3에서는 장착 효과를 최소로 유지 (텍스처/테두리 미세 변화).
class DressUpPage extends StatefulWidget {
  const DressUpPage({super.key});

  @override
  State<DressUpPage> createState() => _DressUpPageState();
}

class _DressUpPageState extends State<DressUpPage> {
  String? _equippedSkinId;

  @override
  void initState() {
    super.initState();
    _loadEquipped();
  }

  Future<void> _loadEquipped() async {
    final skinId = await UserActionService.getEquippedSkinId();
    if (mounted) setState(() => _equippedSkinId = skinId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF424242)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '꾸미기',
          style: TextStyle(
            color: Color(0xFF424242),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // ── 원 프리뷰 ──
            _buildCirclePreview(),

            const SizedBox(height: 24),

            // ── 장착 상태 ──
            _buildEquippedInfo(),

            const SizedBox(height: 16),

            // ── 아이템 그리드 ──
            Expanded(child: _buildItemGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildCirclePreview() {
    return Center(
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E88E5).withOpacity(0.15),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Center(
          child: Text(
            _equippedSkinId != null ? '✨' : '○',
            style: TextStyle(
              fontSize: _equippedSkinId != null ? 40 : 48,
              color: Colors.grey[300],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEquippedInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.palette_outlined, color: Colors.grey[400], size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _equippedSkinId != null ? '스킨 장착중' : '장착 중인 스킨 없음',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          if (_equippedSkinId != null)
            TextButton(
              onPressed: () async {
                await UserActionService.equipSkin(null);
                if (mounted) setState(() => _equippedSkinId = null);
              },
              child: Text(
                '해제',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemGrid() {
    final storeService = context.read<StoreService>();

    return FutureBuilder<List<StoreItem>>(
      future: storeService.fetchMyItems(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_outlined,
                    color: Colors.grey[300], size: 48),
                const SizedBox(height: 12),
                Text(
                  '보유한 아이템이 없습니다.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
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
            final isEquipped = _equippedSkinId == item.id;

            return GestureDetector(
              onTap: () async {
                if (isEquipped) {
                  await UserActionService.equipSkin(null);
                  if (mounted) setState(() => _equippedSkinId = null);
                } else {
                  await UserActionService.equipSkin(item.id);
                  if (mounted) setState(() => _equippedSkinId = item.id);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: isEquipped
                      ? Border.all(
                          color: const Color(0xFF1E88E5).withOpacity(0.5),
                          width: 2,
                        )
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
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.grey[300],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        item.name,
                        style: TextStyle(
                          color: isEquipped
                              ? const Color(0xFF1E88E5)
                              : Colors.grey[600],
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



