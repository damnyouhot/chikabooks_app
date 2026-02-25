import 'package:flutter/material.dart';
import '../../pages/settings/settings_page.dart';
import 'bond_colors.dart';

/// 결 탭 상단 타이틀 바
class BondTopBar extends StatelessWidget {
  final VoidCallback onSettingsLongPress;
  final String weekLabel; // 예: "2월 4주차: 16~22일"

  const BondTopBar({
    super.key,
    required this.onSettingsLongPress,
    required this.weekLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.info_outline,
                  color: BondColors.kText.withOpacity(0.5),
                  size: 18,
                ),
                onPressed: () => _showConceptDialog(context),
              ),
              const Spacer(),
              GestureDetector(
                onLongPress: onSettingsLongPress,
                child: IconButton(
                  icon: Icon(
                    Icons.settings_outlined,
                    color: BondColors.kText.withOpacity(0.4),
                    size: 20,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    );
                  },
                  tooltip: '설정',
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 20),
          child: Text(
            '같이',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: BondColors.kText,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(
            weekLabel,
            style: TextStyle(
              fontSize: 12,
              color: BondColors.kText.withOpacity(0.55),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // 설명 다이얼로그
  void _showConceptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text(
              '같이 탭에 대해서',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            content: const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '결(結):',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: BondColors.kText,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '나를 단단하게 만드는 결이 같은 동료들과 연결',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '치과생활에서의 고민, 감정, 일상을\n파트너들과 나누고, 스스로를 돌보며\n조용히 쌓아가는 공간입니다.',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '💛 결 점수',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '결은, 나를 방치하지 않은 시간의 축적입니다.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF666666),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '캐릭터와의 교감,\n파트너와의 이야기,\n하루를 기록하고 목표를 세우는 작은 실천들이\n함께 반영되어 올라갑니다.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF666666),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '경쟁이나 순위는 없습니다.\n결은 오직 쌓이는 기록입니다.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF666666),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '🤝 파트너 매칭',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '파트너는 7일 동안 함께 걷는 동행입니다.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF666666),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '비슷한 고민과 결을 가진 사람들과 연결되어\n한 주를 함께 버티게 됩니다.\n성과보다 안전과 지속을 우선합니다.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF666666),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '🔁 파트너 연장',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '한 주가 끝나면,\n서로 원할 경우 조용히 이어집니다.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF666666),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '억지로 붙잡지 않아도 되고,\n떠난다고 실패가 아닙니다.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF666666),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '이 탭은 경쟁이 아니라\n리듬을 맞추는 공간입니다.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF666666),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '🗓️ 이번 주 우리 스탬프',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '파트너 3명이 함께 투표/리액션/목표 체크를 하면\n'
                    '하루 1칸씩 채워져요.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ],
          ),
    );
  }
}
