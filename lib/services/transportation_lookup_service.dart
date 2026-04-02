import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/transportation_info.dart';

/// 개별 역 정보 (서버에서 반환하는 stations 배열 항목)
class NearbyStation {
  final String name;
  final List<String> lines;
  /// 표시·정렬용 거리(m). 서버는 `distanceMeters`로 반환.
  final int distanceMeters;
  final int walkingMinutes;

  const NearbyStation({
    required this.name,
    this.lines = const [],
    required this.distanceMeters,
    required this.walkingMinutes,
  });

  factory NearbyStation.fromMap(Map<String, dynamic> m) {
    final dm = (m['distanceMeters'] as num?)?.toInt() ??
        (m['walkingDistanceMeters'] as num?)?.toInt() ??
        0;
    return NearbyStation(
      name: m['name'] as String? ?? '',
      lines: List<String>.from(m['lines'] ?? []),
      distanceMeters: dm,
      walkingMinutes: (m['walkingMinutes'] as num?)?.toInt() ?? 0,
    );
  }
}

class TransportationLookupResult {
  final TransportationInfo info;
  final double lat;
  final double lng;
  final String? failReason;
  final List<NearbyStation> stations;

  const TransportationLookupResult({
    required this.info,
    required this.lat,
    required this.lng,
    this.failReason,
    this.stations = const [],
  });
}

class TransportationLookupService {
  TransportationLookupService._();

  static final _callable =
      FirebaseFunctions.instance.httpsCallable('lookupNearbyStation');

  static List<NearbyStation> _parseStations(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .map((e) => NearbyStation.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<TransportationLookupResult?> lookupByAddress(
      String address) async {
    try {
      final result = await _callable.call({'address': address});
      final data = Map<String, dynamic>.from(result.data as Map);

      if (data['found'] != true) {
        final reason = data['reason'] as String?;
        debugPrint('⚠️ lookupByAddress not found: $reason');
        if (reason != null) {
          return TransportationLookupResult(
            lat: 0, lng: 0, failReason: reason,
            info: const TransportationInfo(),
          );
        }
        return null;
      }

      return TransportationLookupResult(
        lat: (data['lat'] as num).toDouble(),
        lng: (data['lng'] as num).toDouble(),
        stations: _parseStations(data['stations']),
        info: TransportationInfo(
          subwayStationName: data['subwayStationName'] as String?,
          subwayLines: List<String>.from(data['subwayLines'] ?? []),
          walkingDistanceMeters:
              (data['walkingDistanceMeters'] as num?)?.toInt(),
          walkingMinutes: (data['walkingMinutes'] as num?)?.toInt(),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ TransportationLookupService.lookupByAddress: $e');
      return null;
    }
  }

  static Future<TransportationLookupResult?> lookup({
    required double lat,
    required double lng,
  }) async {
    try {
      final result = await _callable.call({'lat': lat, 'lng': lng});
      final data = Map<String, dynamic>.from(result.data as Map);

      if (data['found'] != true) return null;

      return TransportationLookupResult(
        lat: (data['lat'] as num?)?.toDouble() ?? lat,
        lng: (data['lng'] as num?)?.toDouble() ?? lng,
        stations: _parseStations(data['stations']),
        info: TransportationInfo(
          subwayStationName: data['subwayStationName'] as String?,
          subwayLines: List<String>.from(data['subwayLines'] ?? []),
          walkingDistanceMeters:
              (data['walkingDistanceMeters'] as num?)?.toInt(),
          walkingMinutes: (data['walkingMinutes'] as num?)?.toInt(),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ TransportationLookupService.lookup: $e');
      return null;
    }
  }
}
