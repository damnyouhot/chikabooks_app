import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// 아임웹 API 서비스 (Old REST API - 2단계 인증)
/// 
/// 1. /auth로 access_token 발급
/// 2. 실제 API 호출 시 헤더에 access-token 포함
class ImwebApiService {
  static final _db = FirebaseFirestore.instance;
  static const _baseUrl = 'https://api.imweb.me/v2';

  /// API 키 캐시
  static String? _cachedKey;
  static String? _cachedSecret;
  static String? _cachedAccessToken;

  /// Firestore에서 API 키 가져오기
  static Future<Map<String, String>?> _getApiKeys() async {
    // 캐시가 있으면 재사용
    if (_cachedKey != null && _cachedSecret != null) {
      return {
        'key': _cachedKey!,
        'secret': _cachedSecret!,
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
      _cachedKey = data?['key'] as String?;
      _cachedSecret = data?['secret_key'] as String?;

      if (_cachedKey == null || _cachedSecret == null) {
        debugPrint('❌ API 키 형식이 잘못되었습니다');
        return null;
      }

      return {
        'key': _cachedKey!,
        'secret': _cachedSecret!,
      };
    } catch (e) {
      debugPrint('❌ API 키 가져오기 실패: $e');
      return null;
    }
  }

  /// STEP 1: access_token 발급
  static Future<String?> _getAccessToken() async {
    // 캐시된 토큰이 있으면 재사용
    if (_cachedAccessToken != null) {
      return _cachedAccessToken;
    }

    try {
      final keys = await _getApiKeys();
      if (keys == null) return null;

      final url = '$_baseUrl/auth?key=${keys['key']}&secret=${keys['secret']}';
      debugPrint('🔑 토큰 발급 요청: $url');

      final response = await http.get(Uri.parse(url));
      
      debugPrint('🔑 토큰 발급 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _cachedAccessToken = data['access_token'] as String?;
        
        if (_cachedAccessToken != null) {
          debugPrint('✅ 토큰 발급 성공: ${_cachedAccessToken!.substring(0, 10)}...');
          return _cachedAccessToken;
        } else {
          debugPrint('❌ 응답에 access_token이 없음: ${response.body}');
          return null;
        }
      } else {
        debugPrint('❌ 토큰 발급 실패: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ 토큰 발급 오류: $e');
      return null;
    }
  }

  /// STEP 2: API 호출 (공통 헤더)
  static Future<Map<String, String>?> _getAuthHeaders() async {
    final token = await _getAccessToken();
    if (token == null) return null;

    return {
      'access-token': token,
      'Content-Type': 'application/json',
    };
  }

  /// 상품 목록 조회 (테스트용 - 가장 쉬운 엔드포인트)
  static Future<Map<String, dynamic>?> getProducts({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/shop/products?page=$page&limit=$limit'),
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

  /// 회원 목록 조회 (정확한 엔드포인트)
  static Future<Map<String, dynamic>?> getMembers({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/member/members?page=$page&limit=$limit'),
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
    String? status,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) return null;

      var url = '$_baseUrl/shop/orders?page=$page&limit=$limit';
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

  /// 특정 주문 상세 조회
  static Future<Map<String, dynamic>?> getOrderDetail(String orderId) async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/shop/orders/$orderId'),
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
    _cachedKey = null;
    _cachedSecret = null;
    _cachedAccessToken = null;
  }
}

