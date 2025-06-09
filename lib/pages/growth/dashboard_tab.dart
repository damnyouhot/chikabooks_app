import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final docStream =
        FirebaseFirestore.instance.collection('users').doc(uid).snapshots();

    return StreamBuilder<DocumentSnapshot>(
      stream: docStream,
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = snap.data!.data()! as Map<String, dynamic>;

        final km = ((d['stepCount'] ?? 0).toDouble() / 1250); // 1250보 ≈ 1 km
        final sleep = (d['sleepHours'] ?? 0) as num;
        final studyMin = (d['studyMinutes'] ?? 0) as num;
        final interact = (d['emotionPoints'] ?? 0) as num;
        final stamps = (d['quizCount'] ?? 0) as num; // 도장 = quizCount

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _pieChart({
                '운동': km,
                '수면': sleep,
                '공부': studyMin,
                '교류': interact,
                '도장': stamps,
              }),
              const SizedBox(height: 24),
              _bar('운동(km)', km),
              _bar('수면(시간)', sleep),
              _bar('공부(분)', studyMin),
              _bar('교류 pt', interact),
              _bar('도장 개', stamps),
            ],
          ),
        );
      },
    );
  }

  Widget _pieChart(Map<String, num> data) {
    final sections = data.entries.map((e) {
      final v = e.value == 0 ? 0.01 : e.value.toDouble();
      return PieChartSectionData(
        value: v,
        title: e.key,
        radius: 48,
        titleStyle: const TextStyle(fontSize: 10),
      );
    }).toList();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text('총 활동 비율',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: PieChart(PieChartData(
                sections: sections,
                centerSpaceRadius: 38,
                sectionsSpace: 2,
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(String label, num value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text(label)),
            Expanded(
              flex: 5,
              child: LinearProgressIndicator(
                value: (value / 100).clamp(0, 1).toDouble(),
              ),
            ),
            const SizedBox(width: 8),
            Text(value.toStringAsFixed(1)),
          ],
        ),
      ),
    );
  }
}
