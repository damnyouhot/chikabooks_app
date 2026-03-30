/// 교통편 정보 (Firestore `jobs.transportation` 중첩 객체)
///
/// 자동 계산 필드: [subwayLines], [subwayStationName],
/// [walkingDistanceMeters], [walkingMinutes]
/// 수동 입력 필드: [exitNumber], [parking]
class TransportationInfo {
  final List<String> subwayLines;
  final String? subwayStationName;
  final int? walkingDistanceMeters;
  final int? walkingMinutes;
  final String? exitNumber;
  final bool parking;

  const TransportationInfo({
    this.subwayLines = const [],
    this.subwayStationName,
    this.walkingDistanceMeters,
    this.walkingMinutes,
    this.parking = false,
    this.exitNumber,
  });

  /// 역세권 판정 (도보 10분 이내)
  bool get isNearStation =>
      subwayStationName != null &&
      walkingMinutes != null &&
      walkingMinutes! <= 10;

  /// 목록/카드용 한줄 요약 (예: "강남역 도보 4분")
  String? get summaryLine {
    if (subwayStationName == null || subwayStationName!.isEmpty) return null;
    if (walkingMinutes != null) {
      return '$subwayStationName 도보 ${walkingMinutes}분';
    }
    return subwayStationName;
  }

  /// 상세 화면용 전체 문구 (예: "강남역 도보 4분 (280m) · 11번 출구")
  String? get detailLine {
    if (subwayStationName == null || subwayStationName!.isEmpty) return null;
    final buf = StringBuffer(subwayStationName!);
    if (walkingMinutes != null) {
      buf.write(' 도보 ${walkingMinutes}분');
      if (walkingDistanceMeters != null) {
        buf.write(' (${walkingDistanceMeters}m)');
      }
    }
    if (exitNumber != null && exitNumber!.isNotEmpty) {
      buf.write(' · $exitNumber');
    }
    return buf.toString();
  }

  factory TransportationInfo.fromJson(Map<String, dynamic> json) {
    return TransportationInfo(
      subwayLines: List<String>.from(json['subwayLines'] ?? []),
      subwayStationName: json['subwayStationName'] as String?,
      walkingDistanceMeters: (json['walkingDistanceMeters'] as num?)?.toInt(),
      walkingMinutes: (json['walkingMinutes'] as num?)?.toInt(),
      exitNumber: json['exitNumber'] as String?,
      parking: (json['parking'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'subwayLines': subwayLines,
        if (subwayStationName != null) 'subwayStationName': subwayStationName,
        if (walkingDistanceMeters != null)
          'walkingDistanceMeters': walkingDistanceMeters,
        if (walkingMinutes != null) 'walkingMinutes': walkingMinutes,
        if (exitNumber != null) 'exitNumber': exitNumber,
        'parking': parking,
      };

  TransportationInfo copyWith({
    List<String>? subwayLines,
    String? subwayStationName,
    int? walkingDistanceMeters,
    int? walkingMinutes,
    String? exitNumber,
    bool? parking,
  }) {
    return TransportationInfo(
      subwayLines: subwayLines ?? this.subwayLines,
      subwayStationName: subwayStationName ?? this.subwayStationName,
      walkingDistanceMeters:
          walkingDistanceMeters ?? this.walkingDistanceMeters,
      walkingMinutes: walkingMinutes ?? this.walkingMinutes,
      exitNumber: exitNumber ?? this.exitNumber,
      parking: parking ?? this.parking,
    );
  }
}
