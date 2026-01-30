import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/growth_service.dart';
import '../../models/character.dart';
import '../../services/character_service.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  // 각 항목별 일일 목표
  static const Map<String, double> dailyGoals = {
    '운동': 5.0,      // 5km
    '수면': 8.0,      // 8시간
    '공부': 60.0,     // 60분
    '교류': 10.0,     // 10포인트
    '퀴즈': 3.0,      // 3회
  };

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<Character?>(
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

          final activityData = {
            '운동': km,
            '수면': character.sleepHours,
            '공부': character.studyMinutes.toDouble(),
            '교류': character.emotionPoints.toDouble(),
            '퀴즈': character.quizCount.toDouble(),
          };

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 인사이트 카드
              _buildInsightCard(activityData),
              const SizedBox(height: 16),

              // 오늘의 목표 달성률
              _buildGoalProgressCard(activityData),
              const SizedBox(height: 16),

              // 주간 차트
              _buildWeeklyChart(),
              const SizedBox(height: 16),

              // 활동 비율 파이차트
              _pieChart(activityData),
              const SizedBox(height: 16),

              // 개별 활동 막대
              const Text(
                '상세 활동',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _activityProgressBar('운동', km, dailyGoals['운동']!, 'km', Icons.directions_walk, Colors.green),
              _activityProgressBar('수면', character.sleepHours, dailyGoals['수면']!, '시간', Icons.bedtime, Colors.indigo),
              _activityProgressBar('공부', character.studyMinutes.toDouble(), dailyGoals['공부']!, '분', Icons.menu_book, Colors.orange),
              _activityProgressBar('교류', character.emotionPoints.toDouble(), dailyGoals['교류']!, 'pt', Icons.favorite, Colors.pink),
              _activityProgressBar('퀴즈', character.quizCount.toDouble(), dailyGoals['퀴즈']!, '회', Icons.quiz, Colors.purple),
            ],
          );
        },
      ),
    );
  }

  /// 인사이트 카드 - 오늘의 요약과 격려 메시지
  Widget _buildInsightCard(Map<String, double> data) {
    final totalProgress = _calculateTotalProgress(data);
    final bestActivity = _findBestActivity(data);
    final weakActivity = _findWeakActivity(data);

    String encouragement;
    IconData icon;
    Color color;

    if (totalProgress >= 80) {
      encouragement = '🎉 대단해요! 오늘 목표를 거의 달성했어요!';
      icon = Icons.emoji_events;
      color = Colors.amber;
    } else if (totalProgress >= 50) {
      encouragement = '💪 잘하고 있어요! 조금만 더 힘내봐요!';
      icon = Icons.trending_up;
      color = Colors.green;
    } else if (totalProgress >= 20) {
      encouragement = '🌱 좋은 시작이에요! 꾸준히 해봐요!';
      icon = Icons.spa;
      color = Colors.teal;
    } else {
      encouragement = '☀️ 오늘도 건강한 하루 시작해봐요!';
      icon = Icons.wb_sunny;
      color = Colors.orange;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 8),
                const Text(
                  '오늘의 인사이트',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              encouragement,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _miniStat(
                    '가장 잘한 활동',
                    bestActivity,
                    Icons.star,
                    Colors.amber,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                Expanded(
                  child: _miniStat(
                    '더 노력해봐요',
                    weakActivity,
                    Icons.fitness_center,
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  /// 오늘의 목표 달성률 카드
  Widget _buildGoalProgressCard(Map<String, double> data) {
    final totalProgress = _calculateTotalProgress(data);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '오늘의 목표 달성률',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getProgressColor(totalProgress).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${totalProgress.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getProgressColor(totalProgress),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 원형 진행률
            Center(
              child: SizedBox(
                height: 120,
                width: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 120,
                      width: 120,
                      child: CircularProgressIndicator(
                        value: (totalProgress / 100).clamp(0.0, 1.0),
                        strokeWidth: 12,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation(
                          _getProgressColor(totalProgress),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${totalProgress.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _getProgressColor(totalProgress),
                          ),
                        ),
                        Text(
                          '달성',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 각 항목별 미니 진행률
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: data.entries.map((e) {
                final goal = dailyGoals[e.key] ?? 1.0;
                final progress = ((e.value / goal) * 100).clamp(0.0, 100.0);
                return _miniProgressCircle(e.key, progress);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniProgressCircle(String label, double progress) {
    return Column(
      children: [
        SizedBox(
          height: 40,
          width: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: (progress / 100).clamp(0.0, 1.0),
                strokeWidth: 4,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(
                  _getProgressColor(progress),
                ),
              ),
              Text(
                '${progress.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 80) return Colors.green;
    if (progress >= 50) return Colors.orange;
    if (progress >= 20) return Colors.amber;
    return Colors.grey;
  }

  double _calculateTotalProgress(Map<String, double> data) {
    double totalProgress = 0;
    int count = 0;
    for (final entry in data.entries) {
      final goal = dailyGoals[entry.key] ?? 1.0;
      totalProgress += ((entry.value / goal) * 100).clamp(0.0, 100.0);
      count++;
    }
    return count > 0 ? totalProgress / count : 0;
  }

  String _findBestActivity(Map<String, double> data) {
    String best = '-';
    double bestProgress = -1;
    for (final entry in data.entries) {
      final goal = dailyGoals[entry.key] ?? 1.0;
      final progress = entry.value / goal;
      if (progress > bestProgress) {
        bestProgress = progress;
        best = entry.key;
      }
    }
    return best;
  }

  String _findWeakActivity(Map<String, double> data) {
    String weak = '-';
    double weakProgress = double.infinity;
    for (final entry in data.entries) {
      final goal = dailyGoals[entry.key] ?? 1.0;
      final progress = entry.value / goal;
      if (progress < weakProgress) {
        weakProgress = progress;
        weak = entry.key;
      }
    }
    return weak;
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
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
                                width: 20,
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
    final colors = [
      Colors.green,
      Colors.indigo,
      Colors.orange,
      Colors.pink,
      Colors.purple,
    ];
    int colorIndex = 0;

    final sections = data.entries.map((e) {
      final value = isAllZero
          ? 1.0
          : (e.value.toDouble() == 0 ? 0.01 : e.value.toDouble());
      final color = colors[colorIndex % colors.length];
      colorIndex++;
      return PieChartSectionData(
        value: value,
        title: e.key,
        color: color,
        radius: 45,
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: PieChart(PieChartData(
                sections: sections,
                centerSpaceRadius: 35,
                sectionsSpace: 2,
              )),
            ),
            const SizedBox(height: 12),
            // 범례
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: List.generate(data.length, (i) {
                final entry = data.entries.elementAt(i);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors[i % colors.length],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(entry.key, style: const TextStyle(fontSize: 11)),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  /// 개별 활동 진행률 바 (개선된 버전)
  Widget _activityProgressBar(
    String label,
    double value,
    double goal,
    String unit,
    IconData icon,
    Color color,
  ) {
    final progress = (value / goal).clamp(0.0, 1.0);
    final percentage = (progress * 100).toStringAsFixed(0);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // 아이콘
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            // 라벨 + 프로그레스
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${value.toStringAsFixed(1)} / ${goal.toStringAsFixed(0)} $unit',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 퍼센트
            Container(
              width: 45,
              alignment: Alignment.centerRight,
              child: Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
