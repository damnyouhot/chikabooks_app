import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/growth_service.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    // ... (기존 docStream 정의는 동일) ...

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildWeeklyChart(), // ◀◀◀ 주간 성장 그래프 추가
          const SizedBox(height: 24),
          // ... (기존 StreamBuilder와 하위 위젯들은 동일) ...
        ],
      ),
    );
  }

  // ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼ 주간 학습량 차트 위젯 추가 ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
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
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final data = snapshot.data!;
                  return BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (data.values.reduce((a, b) => a > b ? a : b) * 1.2)
                          .clamp(10, double.infinity), // 최대값의 120%로 Y축 설정
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
                                  topRight: Radius.circular(6),
                                ))
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
                              return Text(days[value.toInt() - 1]);
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
  // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲ 주간 학습량 차트 위젯 추가 ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲

  // ... (_pieChart, _bar 함수는 기존과 동일)
}
