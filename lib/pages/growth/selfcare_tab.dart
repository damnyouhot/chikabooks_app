// lib/pages/growth/selfcare_tab.dart

import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:chikabooks_app/services/growth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SelfCareTab extends StatefulWidget {
  const SelfCareTab({super.key});

  @override
  _SelfCareTabState createState() => _SelfCareTabState();
}

class _SelfCareTabState extends State<SelfCareTab> {
  late Stream<StepCount> _stepStream;
  int _steps = 0;

  // 운동 세션
  bool _isExercising = false;
  int _startSteps = 0;

  // 수면 세션
  DateTime? _sleepStart;

  final String uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _stepStream = Pedometer.stepCountStream;
    _stepStream.listen((event) {
      setState(() => _steps = event.steps);
    });
  }

  void _toggleExercise() async {
    if (!_isExercising) {
      // 시작
      _startSteps = _steps;
      setState(() => _isExercising = true);
    } else {
      // 종료
      final delta = _steps - _startSteps;
      final km = delta * 0.0008; // 1걸음 ≒ 0.8m
      await GrowthService.recordEvent(uid: uid, type: 'exercise', value: km);
      setState(() => _isExercising = false);
    }
  }

  void _toggleSleep() async {
    if (_sleepStart == null) {
      // 수면 시작
      _sleepStart = DateTime.now();
    } else {
      // 수면 종료
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
