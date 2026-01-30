/// 유니콘 색상 타입
enum UnicornColor {
  pink,      // 핑크 (기본)
  blue,      // 블루
  purple,    // 퍼플
  mint,      // 민트
  gold,      // 골드
  rainbow,   // 레인보우 (특별)
}

/// 유니콘 색상별 정보
class UnicornColorInfo {
  final UnicornColor color;
  final String name;
  final String description;
  final String folderName;    // 애셋 폴더명
  final bool isUnlocked;      // 해금 여부 (기본: 핑크만 해금)
  final int unlockCost;       // 해금 비용 (포인트)

  const UnicornColorInfo({
    required this.color,
    required this.name,
    required this.description,
    required this.folderName,
    this.isUnlocked = false,
    this.unlockCost = 0,
  });

  static const Map<UnicornColor, UnicornColorInfo> colorInfoMap = {
    UnicornColor.pink: UnicornColorInfo(
      color: UnicornColor.pink,
      name: '핑키',
      description: '사랑스럽고 따뜻한 핑크 유니콘',
      folderName: 'unicorn_pink',
      isUnlocked: true, // 기본 해금
      unlockCost: 0,
    ),
    UnicornColor.blue: UnicornColorInfo(
      color: UnicornColor.blue,
      name: '스카이',
      description: '차분하고 지적인 블루 유니콘',
      folderName: 'unicorn_blue',
      unlockCost: 500,
    ),
    UnicornColor.purple: UnicornColorInfo(
      color: UnicornColor.purple,
      name: '라벤더',
      description: '신비롭고 우아한 퍼플 유니콘',
      folderName: 'unicorn_purple',
      unlockCost: 500,
    ),
    UnicornColor.mint: UnicornColorInfo(
      color: UnicornColor.mint,
      name: '민티',
      description: '상쾌하고 활발한 민트 유니콘',
      folderName: 'unicorn_mint',
      unlockCost: 800,
    ),
    UnicornColor.gold: UnicornColorInfo(
      color: UnicornColor.gold,
      name: '골디',
      description: '고귀하고 빛나는 골드 유니콘',
      folderName: 'unicorn_gold',
      unlockCost: 1500,
    ),
    UnicornColor.rainbow: UnicornColorInfo(
      color: UnicornColor.rainbow,
      name: '레인보우',
      description: '모든 빛을 품은 특별한 유니콘',
      folderName: 'unicorn_rainbow',
      unlockCost: 3000,
    ),
  };

  static UnicornColorInfo getInfo(UnicornColor color) {
    return colorInfoMap[color] ?? colorInfoMap[UnicornColor.pink]!;
  }
}

/// 유니콘 캐릭터 모델
class Unicorn {
  final String id;
  final UnicornColor color;
  final String nickname;      // 유저가 지어준 이름
  final DateTime createdAt;
  final DateTime lastInteraction;
  
  // 교감 상태
  final double affection;     // 애정도 (0.0 ~ 100.0)
  final double happiness;     // 행복도 (0.0 ~ 100.0)
  final int totalInteractions; // 총 교감 횟수

  const Unicorn({
    required this.id,
    required this.color,
    required this.nickname,
    required this.createdAt,
    required this.lastInteraction,
    this.affection = 50.0,
    this.happiness = 50.0,
    this.totalInteractions = 0,
  });

  /// 색상 정보 가져오기
  UnicornColorInfo get colorInfo => UnicornColorInfo.getInfo(color);

  /// 기본 이름 (닉네임이 없을 때)
  String get displayName => nickname.isNotEmpty ? nickname : colorInfo.name;

  /// Idle 애니메이션 프레임 경로 리스트 생성
  List<String> getIdleFramePaths({int frameCount = 24}) {
    final List<String> paths = [];
    for (int i = 1; i <= frameCount; i++) {
      final frameNumber = i.toString().padLeft(4, '0');
      paths.add('assets/characters/${colorInfo.folderName}/idle_$frameNumber.png');
    }
    return paths;
  }

  /// Firestore에서 생성
  factory Unicorn.fromMap(Map<String, dynamic> map, String id) {
    return Unicorn(
      id: id,
      color: UnicornColor.values.firstWhere(
        (e) => e.name == map['color'],
        orElse: () => UnicornColor.pink,
      ),
      nickname: map['nickname'] ?? '',
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt']) 
          : DateTime.now(),
      lastInteraction: map['lastInteraction'] != null 
          ? DateTime.parse(map['lastInteraction']) 
          : DateTime.now(),
      affection: (map['affection'] ?? 50.0).toDouble(),
      happiness: (map['happiness'] ?? 50.0).toDouble(),
      totalInteractions: map['totalInteractions'] ?? 0,
    );
  }

  /// Firestore에 저장
  Map<String, dynamic> toMap() {
    return {
      'color': color.name,
      'nickname': nickname,
      'createdAt': createdAt.toIso8601String(),
      'lastInteraction': lastInteraction.toIso8601String(),
      'affection': affection,
      'happiness': happiness,
      'totalInteractions': totalInteractions,
    };
  }

  /// 복사본 생성 (수정용)
  Unicorn copyWith({
    String? id,
    UnicornColor? color,
    String? nickname,
    DateTime? createdAt,
    DateTime? lastInteraction,
    double? affection,
    double? happiness,
    int? totalInteractions,
  }) {
    return Unicorn(
      id: id ?? this.id,
      color: color ?? this.color,
      nickname: nickname ?? this.nickname,
      createdAt: createdAt ?? this.createdAt,
      lastInteraction: lastInteraction ?? this.lastInteraction,
      affection: affection ?? this.affection,
      happiness: happiness ?? this.happiness,
      totalInteractions: totalInteractions ?? this.totalInteractions,
    );
  }
}




