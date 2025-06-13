// lib/pages/growth/selfcare_tab.dart

import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:chikabooks_app/services/growth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SelfCareTab extends StatefulWidget {
  const SelfCareTab({super.key});

  @override
  // ▼▼▼ State 클래스를 public으로 변경 ▼▼▼
  SelfCareTabState createState() => SelfCareTabState();
}

// ▼▼▼ State 클래스를 public으로 변경 ▼▼▼
class SelfCareTabState extends State<SelfCareTab> {
  late Stream<StepCount> _stepStream;
  int _steps = 0;
  bool _isExercising = false;
  int _startSteps = 0;
  DateTime? _sleepStart;

  final String uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _stepStream = Pedometer.stepCountStream;
    _stepStream.listen((event) {
      if (mounted) {
        setState(() => _steps = event.steps);
      }
    });
  }

  void _toggleExercise() async {
    if (!_isExercising) {
      _startSteps = _steps;
      setState(() => _isExercising = true);
    } else {
      final delta = _steps - _startSteps;
      final km = delta * 0.0008;
      await GrowthService.recordEvent(uid: uid, type: 'exercise', value: km);
      setState(() => _isExercising = false);
    }
  }

  void _toggleSleep() async {
    if (_sleepStart == null) {
      _sleepStart = DateTime.now();
    } else {
      final duration = DateTime.now().difference(_sleepStart!);
      final hours = duration.inMinutes / 60.0;
      await GrowthService.recordEvent(uid: uid, type: 'sleep', value: hours);
      _sleepStart = null;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.directions_walk),
            title: const Text('운동하기'),
            subtitle: Text('걸음수: $_steps'),
            trailing: ElevatedButton(
              onPressed: _toggleExercise,
              child: Text(_isExercising ? '종료' : '시작'),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.bedtime),
            title: const Text('수면 기록'),
            subtitle: Text(
              _sleepStart == null
                  ? '수면 전'
                  : '수면 중: ${DateTime.now().difference(_sleepStart!).inMinutes}분',
            ),
            trailing: ElevatedButton(
              onPressed: _toggleSleep,
              child: Text(_sleepStart == null ? '시작' : '종료'),
            ),
          ),
        ),
      ],
    );
  }
}
