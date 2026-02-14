import 'package:flutter/material.dart';
import '../../pages/settings/communion_profile_page.dart';
import 'bond_colors.dart';

/// 결 탭 상단 타이틀 바
class BondTopBar extends StatelessWidget {
  final VoidCallback onSettingsLongPress;

  const BondTopBar({
    super.key,
    required this.onSettingsLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          // '결' 타이틀 제거하고 설명 버튼만 표시
          IconButton(
            onPressed: () => _showConceptDialog(context),
            icon: Icon(
              Icons.info_outline,
              size: 18,
              color: BondColors.kText.withOpacity(0.5),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: '같이 탭 설명',
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CommunionProfilePage(),
              ),
            ),
            onLongPress: onSettingsLongPress,
            child: Icon(
              Icons.settings_outlined,
              color: BondColors.kText.withOpacity(0.4),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // 설명 다이얼로그
  void _showConceptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                '결(結): 함께 엮어가는 관계',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: BondColors.kText,
                ),
              ),
              SizedBox(height: 12),
              Text(
                '치과위생사로서의 고민, 감정, 일상을 파트너들과 나누고 교감을 쌓아가는 공간입니다.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              SizedBox(height: 16),
              Text(
                '🧵 결 점수',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                '파트너와 함께 활동할수록 쌓이는 관계의 깊이. 이야기를 나누고, 공감하고, 응원할 때마다 올라갑니다.',
                style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF666666)),
              ),
              SizedBox(height: 12),
              Text(
                '💬 오늘을 나누기',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                '파트너들에게만 보이는 하루 한 줄. 업무 고민, 소소한 일상, 속내 모두 환영합니다. 이모지와 댓글로 서로 위로하고 공감해요.',
                style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF666666)),
              ),
              SizedBox(height: 12),
              Text(
                '✨ 전광판',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                '파트너들이 추대한 이야기가 전광판에 올라갑니다. 많은 공감을 받은 글이 다른 그룹에도 공유되어 더 많은 사람들에게 위로와 힘이 됩니다.',
                style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF666666)),
              ),
              SizedBox(height: 12),
              Text(
                '📊 공감 투표',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                '매일 바뀌는 질문에 답하며 동료들의 생각과 감정을 엿봅니다. 나만 그런 게 아니구나 싶을 때, 조금 더 가벼운 마음이 될 수 있어요.',
                style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF666666)),
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



