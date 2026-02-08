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
      padding: const EdgeInsets.all(20),
      children: [
        _buildActionCard(
          icon: Icons.directions_walk_rounded,
          title: '운동하기',
          subtitle: '오늘의 걸음수: $_steps',
          buttonText: _isExercising ? '종료하기' : '시작하기',
          color: Colors.greenAccent.shade700,
          onPressed: _toggleExercise,
          isActive: _isExercising,
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          icon: Icons.bedtime_rounded,
          title: '수면 기록',
          subtitle: _sleepStart == null
              ? '편안한 잠자리를 준비하세요'
              : '수면 중: ${DateTime.now().difference(_sleepStart!).inMinutes}분 경과',
          buttonText: _sleepStart == null ? '수면 시작' : '수면 종료',
          color: Colors.indigoAccent,
          onPressed: _toggleSleep,
          isActive: _sleepStart != null,
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required Color color,
    required VoidCallback onPressed,
    required bool isActive,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? Colors.grey[100] : color,
              foregroundColor: isActive ? Colors.black54 : Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              buttonText,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
