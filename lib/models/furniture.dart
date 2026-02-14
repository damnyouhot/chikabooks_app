import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/reward_constants.dart';

/// 가구 방향 (L: 왼쪽 벽, R: 오른쪽 벽)
enum FurnitureDirection { L, R }

/// 가구 정의 (구매 가능한 가구 목록)
class FurnitureDefinition {
  final String id;
  final String name;
  final String assetPath;
  final FurnitureDirection direction;
  final int widthTiles; // 가로 타일 수
  final int heightTiles; // 세로 타일 수 (기본 2)

  const FurnitureDefinition({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.direction,
    this.widthTiles = 1,
    this.heightTiles = 2,
  });

  /// 가격은 RewardPolicy에서 가져옴
  int get price {
    switch (id) {
      case 'bed':
        return RewardPolicy.furnitureBed;
      case 'closet':
        return RewardPolicy.furnitureCloset;
      case 'table':
        return RewardPolicy.furnitureTable;
      case 'desk':
        return RewardPolicy.furnitureDesk;
      case 'door':
        return RewardPolicy.furnitureDoor;
      case 'window':
        return RewardPolicy.furnitureWindow;
      default:
        return 100;
    }
  }

  /// 모든 가구 정의
  static const List<FurnitureDefinition> all = [
    // 왼쪽 벽 가구 (L)
    FurnitureDefinition(
      id: 'bed',
      name: '침대',
      assetPath: 'assets/home/bed-L.png',
      direction: FurnitureDirection.L,
    ),
    FurnitureDefinition(
      id: 'closet',
      name: '옷장',
      assetPath: 'assets/home/closet-L.png',
      direction: FurnitureDirection.L,
    ),
    FurnitureDefinition(
      id: 'table',
      name: '테이블',
      assetPath: 'assets/home/table_L.png',
      direction: FurnitureDirection.L,
    ),
    // 오른쪽 벽 가구 (R)
    FurnitureDefinition(
      id: 'desk',
      name: '책상',
      assetPath: 'assets/home/desk_R.png',
      direction: FurnitureDirection.R,
    ),
    FurnitureDefinition(
      id: 'door',
      name: '문',
      assetPath: 'assets/home/Door_R.png',
      direction: FurnitureDirection.R,
    ),
    FurnitureDefinition(
      id: 'window',
      name: '창문',
      assetPath: 'assets/home/window_R.png',
      direction: FurnitureDirection.R,
    ),
  ];

  static FurnitureDefinition? getById(String id) {
    try {
      return all.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// 배치된 가구 (사용자가 구매 후 배치한 가구)
class PlacedFurniture {
  final String id; // Firestore document ID
  final String furnitureId; // FurnitureDefinition의 id
  final int gridX; // 그리드 X 위치 (0부터 시작)
  final int gridY; // 그리드 Y 위치 (0부터 시작)

  PlacedFurniture({
    required this.id,
    required this.furnitureId,
    required this.gridX,
    required this.gridY,
  });

  FurnitureDefinition? get definition =>
      FurnitureDefinition.getById(furnitureId);

  factory PlacedFurniture.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PlacedFurniture(
      id: doc.id,
      furnitureId: data['furnitureId'] ?? '',
      gridX: data['gridX'] ?? 0,
      gridY: data['gridY'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'furnitureId': furnitureId,
    'gridX': gridX,
    'gridY': gridY,
  };
}

/// 사용자가 보유한 가구 (구매했지만 아직 배치 안 한 것 포함)
class OwnedFurniture {
  final String id;
  final String furnitureId;
  final bool isPlaced;
  final DateTime purchasedAt;

  OwnedFurniture({
    required this.id,
    required this.furnitureId,
    required this.isPlaced,
    required this.purchasedAt,
  });

  FurnitureDefinition? get definition =>
      FurnitureDefinition.getById(furnitureId);

  factory OwnedFurniture.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OwnedFurniture(
      id: doc.id,
      furnitureId: data['furnitureId'] ?? '',
      isPlaced: data['isPlaced'] ?? false,
      purchasedAt:
          (data['purchasedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'furnitureId': furnitureId,
    'isPlaced': isPlaced,
    'purchasedAt': Timestamp.fromDate(purchasedAt),
  };
}













































