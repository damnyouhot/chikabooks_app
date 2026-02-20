import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// 아임웹 API 서비스
/// 
/// Firestore의 api_keys/imweb_keys에서 키를 가져와 아임웹 API 호출
class ImwebApiService {
  static final _db = FirebaseFirestore.instance;
  static const _baseUrl = 'https://api.imweb.me/v2';

  /// API 키 캐시 (앱 실행 중 1회만 가져오기)
  static String? _cachedAccessToken;
  static String? _cachedSecretKey;

  /// API 키 가져오기
  static Future<Map<String, String>?> _getApiKeys() async {
    // 캐시가 있으면 재사용
    if (_cachedAccessToken != null && _cachedSecretKey != null) {
      return {
        'access-token': _cachedAccessToken!,
        'secret-key': _cachedSecretKey!,
      };
    }

    try {
      final snapshot = await _db
          .collection('api_keys')
          .doc('imweb_keys')
          .get();

      if (!snapshot.exists) {
        debugPrint('❌ API 키가 Firestore에 없습니다');
        return null;
      }

      final data = snapshot.data();
      _cachedAccessToken = data?['key'] as String?;
      _cachedSecretKey = data?['secret_key'] as String?;

      if (_cachedAccessToken == null || _cachedSecretKey == null) {
        debugPrint('❌ API 키 형식이 잘못되었습니다');
        return null;
      }

      return {
        'access-token': _cachedAccessToken!,
        'secret-key': _cachedSecretKey!,
      };
    } catch (e) {
      debugPrint('❌ API 키 가져오기 실패: $e');
      return null;
    }
  }

  /// 회원 목록 조회
  static Future<Map<String, dynamic>?> getMembers({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final headers = await _getApiKeys();
      if (headers == null) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/members?page=$page&limit=$limit'),
        headers: headers,
      );

      debugPrint('📥 회원 목록 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('❌ API 오류: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ 회원 목록 조회 실패: $e');
      return null;
    }
  }

  /// 주문 목록 조회
  static Future<Map<String, dynamic>?> getOrders({
    int page = 1,
    int limit = 20,
    String? status, // 'PAY_COMPLETE', 'DELIVERY_COMPLETE', etc.
  }) async {
    try {
      final headers = await _getApiKeys();
      if (headers == null) return null;

      var url = '$_baseUrl/orders?page=$page&limit=$limit';
      if (status != null) {
        url += '&status=$status';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      debugPrint('📥 주문 목록 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('❌ API 오류: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ 주문 목록 조회 실패: $e');
      return null;
    }
  }

  /// 상품 목록 조회
  static Future<Map<String, dynamic>?> getProducts({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final headers = await _getApiKeys();
      if (headers == null) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/products?page=$page&limit=$limit'),
        headers: headers,
      );

      debugPrint('📥 상품 목록 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('❌ API 오류: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ 상품 목록 조회 실패: $e');
      return null;
    }
  }

  /// 특정 주문 상세 조회
  static Future<Map<String, dynamic>?> getOrderDetail(String orderId) async {
    try {
      final headers = await _getApiKeys();
      if (headers == null) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/orders/$orderId'),
        headers: headers,
      );

      debugPrint('📥 주문 상세 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('❌ API 오류: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ 주문 상세 조회 실패: $e');
      return null;
    }
  }

  /// 캐시 초기화 (로그아웃 시)
  static void clearCache() {
    _cachedAccessToken = null;
    _cachedSecretKey = null;
  }
}

