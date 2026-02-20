import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../utils/add_test_data.dart';
import 'imweb_api_test_page.dart';

/// 디버그용 테스트 데이터 추가 페이지
class DebugTestDataPage extends StatefulWidget {
  const DebugTestDataPage({super.key});

  @override
  State<DebugTestDataPage> createState() => _DebugTestDataPageState();
}

class _DebugTestDataPageState extends State<DebugTestDataPage> {
  bool _loading = false;
  String _message = '';

  Future<void> _addTestData() async {
    setState(() {
      _loading = true;
      _message = '테스트 데이터 추가 중...';
    });

    try {
      await TestDataHelper.addTestData();
      setState(() {
        _loading = false;
        _message = '✅ 테스트 데이터가 추가되었습니다!';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _message = '⚠️ 오류 발생: $e';
      });
    }
  }

  Future<void> _clearTestData() async {
    setState(() {
      _loading = true;
      _message = '테스트 데이터 삭제 중...';
    });

    try {
      await TestDataHelper.clearTestBillboardPosts();
      await TestDataHelper.clearTestBondPosts();
      setState(() {
        _loading = false;
        _message = '✅ 테스트 데이터가 삭제되었습니다!';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _message = '⚠️ 오류 발생: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔧 개발자 도구'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '테스트 데이터 관리',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            ElevatedButton.icon(
              onPressed: _loading ? null : _addTestData,
              icon: const Icon(Icons.add),
              label: const Text('테스트 데이터 추가'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: const Color(0xFF6A5ACD),
                foregroundColor: Colors.white,
              ),
            ),
            
            const SizedBox(height: 12),
            
            ElevatedButton.icon(
              onPressed: _loading ? null : _clearTestData,
              icon: const Icon(Icons.delete),
              label: const Text('테스트 데이터 삭제'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            
            const SizedBox(height: 20),
            
            if (_loading)
              const Center(child: CircularProgressIndicator()),
            
            if (_message.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _message.contains('✅') 
                      ? Colors.green.shade50 
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _message,
                  style: TextStyle(
                    color: _message.contains('✅') 
                        ? Colors.green.shade900 
                        : Colors.red.shade900,
                  ),
                ),
              ),
            
            const SizedBox(height: 20),
            
            const Divider(),

            const SizedBox(height: 20),

            const Text(
              'API 테스트',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            // 현재 UID 표시
            FutureBuilder<String?>(
              future: Future.value(FirebaseAuth.instance.currentUser?.uid),
              builder: (context, snapshot) {
                final uid = snapshot.data ?? '로그인 필요';
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '내 UID: $uid',
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: uid));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('UID 복사됨')),
                          );
                        },
                        tooltip: 'UID 복사',
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ImwebApiTestPage(),
                  ),
                );
              },
              icon: const Icon(Icons.api),
              label: const Text('아임웹 API 테스트 (관리자 전용)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: const Color(0xFF5D6B6B),
                foregroundColor: Colors.white,
              ),
            ),
            
            const SizedBox(height: 20),
            
            const Divider(),
            
            const SizedBox(height: 20),
            
            const Text(
              '추가될 데이터:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text('• 전광판 게시물 3개 (다양한 파트너 그룹)'),
            const Text('• 오늘을 나누기 게시물 3개 (민지, 지은, 나)'),
          ],
        ),
      ),
    );
  }
}

