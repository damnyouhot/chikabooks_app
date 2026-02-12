import 'package:flutter/material.dart';
import '../screen/jobs/job_list_screen.dart';
import '../screen/jobs/job_map_screen.dart';

// ── 디자인 팔레트 (2탭과 통일) ──
const _kText = Color(0xFF5D6B6B);
const _kBg = Color(0xFFF1F7F7);

class JobPage extends StatefulWidget {
  const JobPage({super.key});

  @override
  State<JobPage> createState() => _JobPageState();
}

class _JobPageState extends State<JobPage> {
  bool _isMapView = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(
          _isMapView ? '지도로 보기' : '목록으로 보기',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _kText,
          ),
        ),
        backgroundColor: _kBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isMapView = !_isMapView;
              });
            },
            icon: Icon(
              _isMapView ? Icons.list_alt : Icons.map_outlined,
              color: _kText,
            ),
          )
        ],
      ),
      body: IndexedStack(
        index: _isMapView ? 1 : 0,
        children: const [
          JobListScreen(),
          JobMapScreen(),
        ],
      ),
    );
  }
}
