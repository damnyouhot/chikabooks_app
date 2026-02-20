import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../services/imweb_api_service.dart';

/// 아임웹 API 테스트 페이지 (관리자 전용)
class ImwebApiTestPage extends StatefulWidget {
  const ImwebApiTestPage({super.key});

  @override
  State<ImwebApiTestPage> createState() => _ImwebApiTestPageState();
}

class _ImwebApiTestPageState extends State<ImwebApiTestPage> {
  bool _isLoading = false;
  String _result = '';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  /// 관리자 권한 확인 (로그인만 체크)
  Future<void> _checkAdminAccess() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _isAdmin = false;
        _result = '❌ 로그인이 필요합니다';
      });
      return;
    }

    // 로그인만 되어 있으면 OK
    setState(() {
      _isAdmin = true;
    });
  }

  /// 회원 목록 테스트
  Future<void> _testGetMembers() async {
    setState(() {
      _isLoading = true;
      _result = '회원 목록 조회 중...';
    });

    final data = await ImwebApiService.getMembers(limit: 5);
    
    setState(() {
      _isLoading = false;
      if (data != null) {
        _result = '✅ 회원 목록 조회 성공!\n\n${_formatJson(data)}';
      } else {
        _result = '❌ 회원 목록 조회 실패\n\n권한이 없거나 API 키가 잘못되었습니다.';
      }
    });
  }

  /// 주문 목록 테스트
  Future<void> _testGetOrders() async {
    setState(() {
      _isLoading = true;
      _result = '주문 목록 조회 중...';
    });

    final data = await ImwebApiService.getOrders(limit: 5);
    
    setState(() {
      _isLoading = false;
      if (data != null) {
        _result = '✅ 주문 목록 조회 성공!\n\n${_formatJson(data)}';
      } else {
        _result = '❌ 주문 목록 조회 실패\n\n권한이 없거나 API 키가 잘못되었습니다.';
      }
    });
  }

  /// 상품 목록 테스트
  Future<void> _testGetProducts() async {
    setState(() {
      _isLoading = true;
      _result = '상품 목록 조회 중...';
    });

    final data = await ImwebApiService.getProducts(limit: 5);
    
    setState(() {
      _isLoading = false;
      if (data != null) {
        _result = '✅ 상품 목록 조회 성공!\n\n${_formatJson(data)}';
      } else {
        _result = '❌ 상품 목록 조회 실패\n\n권한이 없거나 API 키가 잘못되었습니다.';
      }
    });
  }

  /// JSON 포맷팅
  String _formatJson(Map<String, dynamic> data) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(data);
    } catch (e) {
      return data.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('아임웹 API 테스트'),
        backgroundColor: const Color(0xFF5D6B6B),
        foregroundColor: Colors.white,
      ),
      body: !_isAdmin
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _result,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                // 버튼 영역
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[100],
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _testGetMembers,
                              icon: const Icon(Icons.people),
                              label: const Text('회원 목록'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5D6B6B),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _testGetOrders,
                              icon: const Icon(Icons.shopping_cart),
                              label: const Text('주문 목록'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5D6B6B),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _testGetProducts,
                          icon: const Icon(Icons.inventory),
                          label: const Text('상품 목록'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5D6B6B),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 로딩 인디케이터
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                
                // 결과 영역
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      _result,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

