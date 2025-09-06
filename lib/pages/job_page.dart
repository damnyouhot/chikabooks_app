// lib/pages/job_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../screen/jobs/job_map_screen.dart'; // ← 지도 화면
// 리스트 화면이 분리돼 있으면 import 수정
import '../screen/jobs/job_list_screen.dart';

class JobPage extends StatefulWidget {
  const JobPage({Key? key}) : super(key: key);

  @override
  State<JobPage> createState() => _JobPageState();
}

class _JobPageState extends State<JobPage> {
  bool _isMapView = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isMapView ? '지도로 보기' : '목록 보기'),
        actions: [
          IconButton(
            icon: Icon(_isMapView ? Icons.list : Icons.map),
            onPressed: () => setState(() => _isMapView = !_isMapView),
          ),
        ],
      ),
      // ───────────────────────────────────────────────────────
      // 목록은 Firestore 바로 읽고, 지도는 JobMapScreen 재사용
      body: _isMapView ? const JobMapScreen() : _buildListView(),
      // ───────────────────────────────────────────────────────
    );
  }

  /// Firestore → 리스트
  Widget _buildListView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('jobs').snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) return Center(child: Text('오류: ${snap.error}'));
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('채용 정보가 없습니다.'));
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final d = docs[i].data()! as Map<String, dynamic>;
            return ListTile(
              title: Text(d['title'] as String? ?? '제목 없음'),
              subtitle: Text(d['company'] as String? ?? ''),
            );
          },
        );
      },
    );
  }
}
