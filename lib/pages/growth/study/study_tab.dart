import 'package:flutter/material.dart';
import 'mydesk_tab.dart';

class StudyTab extends StatelessWidget {
  const StudyTab({super.key});

  @override
  Widget build(BuildContext context) {
    // caring_page에서 Navigator.push로 왔는지 확인
    final canPop = Navigator.canPop(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading:
              canPop
                  ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded),
                    onPressed: () => Navigator.pop(context),
                  )
                  : null,
          title: const Text('나의 기록'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '나의 서재'),
              Tab(text: '나의 노트'),
            ],
          ),
        ),
        body: const TabBarView(children: [MyDeskTab(), Center(child: Text('준비 중인 기능입니다.'))]),
      ),
    );
  }
}
