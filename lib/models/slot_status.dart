/// 서버 시간 기준 슬롯 상태
class SlotStatus {
  final String nowKst;
  final bool isOpen;
  final String? slotId;
  final String? slotKey;
  final String? windowEndsAt;
  final String? nextOpensAt;

  const SlotStatus({
    required this.nowKst,
    required this.isOpen,
    this.slotId,
    this.slotKey,
    this.windowEndsAt,
    this.nextOpensAt,
  });

  factory SlotStatus.fromMap(Map<String, dynamic> m) => SlotStatus(
        nowKst: m['nowKst'] ?? '',
        isOpen: m['isOpen'] ?? false,
        slotId: m['slotId'],
        slotKey: m['slotKey'],
        windowEndsAt: m['windowEndsAt'],
        nextOpensAt: m['nextOpensAt'],
      );

  /// 슬롯 시간 라벨 (12:30 or 19:00)
  String get timeLabel {
    if (slotKey == '1230') return '12:30';
    if (slotKey == '1900') return '19:00';
    return '';
  }
}



