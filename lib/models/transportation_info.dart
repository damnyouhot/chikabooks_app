/// 공고에 노출할 지하철역 1개.
class TransportationStation {
  final String name;
  final List<String> lines;
  final int? walkingDistanceMeters;
  final int? walkingMinutes;
  final String? exitNumber;

  const TransportationStation({
    required this.name,
    this.lines = const [],
    this.walkingDistanceMeters,
    this.walkingMinutes,
    this.exitNumber,
  });

  bool get hasValue => name.trim().isNotEmpty;

  String get displayLine {
    final parts = <String>[name.trim()];
    if (lines.isNotEmpty) parts.add(lines.join('·'));
    if (exitNumber != null && exitNumber!.trim().isNotEmpty) {
      parts.add('${exitNumber!.trim()}번 출구');
    }
    if (walkingMinutes != null) parts.add('도보 $walkingMinutes분');
    if (walkingDistanceMeters != null) {
      parts.add('${walkingDistanceMeters}m');
    }
    return parts.join(' · ');
  }

  static int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  factory TransportationStation.fromJson(Map<String, dynamic> json) {
    final distance =
        json['walkingDistanceMeters'] ??
        json['distanceMeters'] ??
        json['walkingDistance'];
    return TransportationStation(
      name: (json['name'] ?? json['subwayStationName'] ?? '').toString().trim(),
      lines: List<String>.from(json['lines'] ?? json['subwayLines'] ?? []),
      walkingDistanceMeters: _intValue(distance),
      walkingMinutes: (json['walkingMinutes'] as num?)?.toInt(),
      exitNumber: json['exitNumber'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (lines.isNotEmpty) 'lines': lines,
    if (walkingDistanceMeters != null)
      'walkingDistanceMeters': walkingDistanceMeters,
    if (walkingMinutes != null) 'walkingMinutes': walkingMinutes,
    if (exitNumber != null && exitNumber!.trim().isNotEmpty)
      'exitNumber': exitNumber,
  };
}

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
  final List<TransportationStation> selectedStations;

  const TransportationInfo({
    this.subwayLines = const [],
    this.subwayStationName,
    this.walkingDistanceMeters,
    this.walkingMinutes,
    this.parking = false,
    this.exitNumber,
    this.selectedStations = const [],
  });

  /// 역세권 판정 (도보 10분 이내)
  bool get isNearStation =>
      selectedStations.any(
        (s) =>
            s.hasValue && s.walkingMinutes != null && s.walkingMinutes! <= 10,
      ) ||
      (subwayStationName != null &&
          walkingMinutes != null &&
          walkingMinutes! <= 10);

  /// 목록/카드용 한줄 요약 (예: "강남역 도보 4분")
  String? get summaryLine {
    final firstStation =
        selectedStations.where((s) => s.hasValue).isNotEmpty
            ? selectedStations.firstWhere((s) => s.hasValue)
            : null;
    if (firstStation != null) {
      if (firstStation.walkingMinutes != null) {
        return '${firstStation.name} 도보 ${firstStation.walkingMinutes}분';
      }
      return firstStation.name;
    }
    if (subwayStationName == null || subwayStationName!.isEmpty) return null;
    if (walkingMinutes != null) {
      return '$subwayStationName 도보 $walkingMinutes분';
    }
    return subwayStationName;
  }

  /// 상세 화면용 전체 문구 (예: "강남역 도보 4분 (280m) · 11번 출구")
  String? get detailLine {
    final stationLines =
        selectedStations
            .where((s) => s.hasValue)
            .map((s) => s.displayLine)
            .toList();
    if (stationLines.isNotEmpty) return stationLines.join('\n');
    if (subwayStationName == null || subwayStationName!.isEmpty) return null;
    final buf = StringBuffer(subwayStationName!);
    if (walkingMinutes != null) {
      buf.write(' 도보 $walkingMinutes분');
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
    final rawStations = json['selectedStations'];
    final stations =
        rawStations is List
            ? rawStations
                .whereType<Map>()
                .map(
                  (e) => TransportationStation.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .where((s) => s.hasValue)
                .toList()
            : <TransportationStation>[];
    final legacyStation = TransportationStation(
      name: (json['subwayStationName'] as String? ?? '').trim(),
      lines: List<String>.from(json['subwayLines'] ?? []),
      walkingDistanceMeters: (json['walkingDistanceMeters'] as num?)?.toInt(),
      walkingMinutes: (json['walkingMinutes'] as num?)?.toInt(),
      exitNumber: json['exitNumber'] as String?,
    );
    return TransportationInfo(
      subwayLines: List<String>.from(json['subwayLines'] ?? []),
      subwayStationName: json['subwayStationName'] as String?,
      walkingDistanceMeters: (json['walkingDistanceMeters'] as num?)?.toInt(),
      walkingMinutes: (json['walkingMinutes'] as num?)?.toInt(),
      exitNumber: json['exitNumber'] as String?,
      parking: (json['parking'] as bool?) ?? false,
      selectedStations:
          stations.isNotEmpty
              ? stations
              : (legacyStation.hasValue ? [legacyStation] : const []),
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
    if (selectedStations.isNotEmpty)
      'selectedStations':
          selectedStations
              .where((s) => s.hasValue)
              .map((s) => s.toJson())
              .toList(),
  };

  TransportationInfo copyWith({
    List<String>? subwayLines,
    String? subwayStationName,
    int? walkingDistanceMeters,
    int? walkingMinutes,
    String? exitNumber,
    bool? parking,
    List<TransportationStation>? selectedStations,
  }) {
    return TransportationInfo(
      subwayLines: subwayLines ?? this.subwayLines,
      subwayStationName: subwayStationName ?? this.subwayStationName,
      walkingDistanceMeters:
          walkingDistanceMeters ?? this.walkingDistanceMeters,
      walkingMinutes: walkingMinutes ?? this.walkingMinutes,
      exitNumber: exitNumber ?? this.exitNumber,
      parking: parking ?? this.parking,
      selectedStations: selectedStations ?? this.selectedStations,
    );
  }
}
