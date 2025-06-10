import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/growth_service.dart';
import '../../models/character.dart';
import '../../services/character_service.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildWeeklyChart(),
          const SizedBox(height: 24),
          StreamBuilder<Character?>(
            stream: CharacterService.watchCharacter(uid),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(80.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (!snap.hasData || snap.data == null) {
                return const Center(child: Text("데이터가 없습니다."));
              }
              final character = snap.data!;
              final km = character.stepCount / 1250.0;

              final pieData = {
                '운동': km,
                '수면': character.sleepHours,
                '공부': character.studyMinutes.toDouble(),
                '교류': character.emotionPoints.toDouble(),
                '퀴즈': character.quizCount.toDouble(),
              };

              return Column(
                children: [
                  _pieChart(pieData),
                  const SizedBox(height: 24),
                  _bar('운동(km)', km),
                  _bar('수면(시간)', character.sleepHours),
                  _bar('공부(분)', character.studyMinutes),
                  _bar('교류 pt', character.emotionPoints),
                  _bar('퀴즈(회)', character.quizCount),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('주간 학습 시간 (분)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: FutureBuilder<Map<int, double>>(
                future: GrowthService.fetchWeeklyStudyData(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snapshot.data!;
                  final maxYValue = data.values.isEmpty
                      ? 10.0
                      : data.values.reduce((a, b) => a > b ? a : b);
                  return BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (maxYValue * 1.2).clamp(10, double.infinity),
                      barGroups: data.entries.map((entry) {
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                                toY: entry.value,
                                color: Colors.pinkAccent,
                                width: 22,
                                borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    topRight: Radius.circular(6)))
                          ],
                        );
                      }).toList(),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              const days = ['월', '화', '수', '목', '금', '토', '일'];
                              return Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(days[value.toInt() - 1]),
                              );
                            },
                            reservedSize: 28,
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData:
                          const FlGridData(show: true, horizontalInterval: 10),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pieChart(Map<String, num> data) {
    final isAllZero = data.values.every((v) => v == 0);
    final sections = data.entries.map((e) {
      final value = isAllZero
          ? 1.0
          : (e.value.toDouble() == 0 ? 0.01 : e.value.toDouble());
      return PieChartSectionData(
        value: value,
        title: e.key,
        radius: 48,
        titleStyle: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        showTitle: !isAllZero,
      );
    }).toList();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('총 활동 비율',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
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
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
                width: 80,
                child: Text(label, style: const TextStyle(fontSize: 14))),
            Expanded(
              child: LinearProgressIndicator(
                value: (value.toDouble() / 100).clamp(0.0, 1.0),
                minHeight: 8,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
                width: 40,
                child:
                    Text(value.toStringAsFixed(1), textAlign: TextAlign.right)),
          ],
        ),
      ),
    );
  }
}
