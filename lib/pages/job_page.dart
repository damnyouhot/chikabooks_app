import 'package:flutter/material.dart';
import '../screen/jobs/job_list_screen.dart';
import '../screen/jobs/job_map_screen.dart';

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
      // JobPage에서 AppBar를 관리하여 뷰 전환 버튼을 제공
      appBar: AppBar(
        // main.dart의 AppBar와 중복되지 않도록 일부 속성 조정
        title: Text(_isMapView ? '지도로 보기' : '목록으로 보기'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 1,
        titleTextStyle: Theme.of(context).textTheme.titleMedium,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isMapView = !_isMapView;
              });
            },
            icon: Icon(_isMapView ? Icons.list_alt : Icons.map_outlined),
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
