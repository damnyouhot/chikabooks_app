import 'package:flutter/material.dart';
import '../../pages/settings/settings_page.dart';
import '../../core/theme/app_colors.dart';

/// 결 탭 상단 타이틀 바
class BondTopBar extends StatelessWidget {
  /// 개발자 전용 롱프레스 (테스트 데이터 페이지) — 내부적으로만 사용
  final VoidCallback onSettingsLongPress;
  final String weekLabel;

  /// 파트너가 있을 때 소모임 나가기 콜백 — null이면 다이얼로그에 버튼 미노출
  final VoidCallback? onLeaveGroupTap;

  /// 글래스 모드: true면 텍스트/아이콘을 흰색 계열로 렌더
  final bool glassMode;

  const BondTopBar({
    super.key,
    required this.onSettingsLongPress,
    required this.weekLabel,
    this.onLeaveGroupTap,
    this.glassMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = glassMode ? AppColors.white : AppColors.textPrimary;
    final labelColor = glassMode
        ? AppColors.white.withOpacity(0.75)
        : AppColors.textSecondary;
    final iconColor  = glassMode
        ? AppColors.white.withOpacity(0.6)
        : AppColors.textDisabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 타이틀 + 아이콘 (한 행으로 통합) ──
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '같이',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
              const Spacer(),
              // ℹ️ Info 버튼 — 소모임 나가기 기능도 여기서 접근 가능
              IconButton(
                icon: Icon(Icons.info_outline, color: iconColor, size: 18),
                onPressed: () => _showConceptDialog(context),
              ),
              // ⚙️ 설정 버튼 — 다른 탭과 동일하게 바로 SettingsPage로 이동
              IconButton(
                icon: Icon(Icons.settings_outlined, color: iconColor, size: 20),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                ),
              ),
            ],
          ),
        ),
        // ── 서브타이틀 (WeekLabel) ──
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(
            weekLabel,
            style: TextStyle(fontSize: 12, color: labelColor),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

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
              Text('결(結):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('나를 단단하게 만드는 결이 같은 동료들과 연결', style: TextStyle(fontSize: 13, height: 1.5)),
              SizedBox(height: 12),
              Text('치과생활에서의 고민, 감정, 일상을\n파트너들과 나누고, 스스로를 돌보며\n조용히 쌓아가는 공간입니다.', style: TextStyle(fontSize: 13, height: 1.5)),
              SizedBox(height: 16),
              Text('💛 결 점수', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('결은, 나를 방치하지 않은 시간의 축적입니다.', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
              SizedBox(height: 8),
              Text('캐릭터와의 교감,\n파트너와의 이야기,\n하루를 기록하고 목표를 세우는 작은 실천들이\n함께 반영되어 올라갑니다.', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
              SizedBox(height: 8),
              Text('경쟁이나 순위는 없습니다.\n결은 오직 쌓이는 기록입니다.', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
              SizedBox(height: 16),
              Text('🤝 파트너 매칭', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('파트너는 7일 동안 함께 걷는 동행입니다.', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
              SizedBox(height: 8),
              Text('비슷한 고민과 결을 가진 사람들과 연결되어\n한 주를 함께 버티게 됩니다.\n성과보다 안전과 지속을 우선합니다.', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
              SizedBox(height: 16),
              Text('🔁 파트너 연장', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('한 주가 끝나면,\n서로 원할 경우 조용히 이어집니다.', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
              SizedBox(height: 8),
              Text('억지로 붙잡지 않아도 되고,\n떠난다고 실패가 아닙니다.', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
              SizedBox(height: 8),
              Text('이 탭은 경쟁이 아니라\n리듬을 맞추는 공간입니다.', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
              SizedBox(height: 16),
              Text('🗓️ 이번 주 우리 스탬프', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('파트너 3명이 함께 투표/리액션/목표 체크를 하면\n하루 1칸씩 채워져요.', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
            ],
          ),
        ),
        actions: [
          // 소모임 나가기 — 파트너가 있을 때만 표시
          if (onLeaveGroupTap != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onLeaveGroupTap?.call();
              },
              child: const Text(
                '소모임 나가기',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}
