import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/transportation_info.dart';

/// Cloud Function `lookupNearbyStation` 래퍼
///
/// 주소 또는 좌표 기반으로 가장 가까운 지하철역 정보를 자동 조회한다.
/// 결과가 없으면 null 반환.
class TransportationLookupResult {
  final TransportationInfo info;
  final double lat;
  final double lng;
  const TransportationLookupResult({
    required this.info,
    required this.lat,
    required this.lng,
  });
}

class TransportationLookupService {
  TransportationLookupService._();

  static final _callable =
      FirebaseFunctions.instance.httpsCallable('lookupNearbyStation');

  /// 주소 텍스트로 가까운 역 자동 조회 (서버에서 지오코딩 + 역 조회 일괄 처리).
  /// 지오코딩된 lat/lng도 함께 반환.
  static Future<TransportationLookupResult?> lookupByAddress(
      String address) async {
    try {
      final result = await _callable.call({'address': address});
      final data = Map<String, dynamic>.from(result.data as Map);

      if (data['found'] != true) return null;

      return TransportationLookupResult(
        lat: (data['lat'] as num).toDouble(),
        lng: (data['lng'] as num).toDouble(),
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

  /// 좌표 기반 가까운 역 자동 조회.
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
