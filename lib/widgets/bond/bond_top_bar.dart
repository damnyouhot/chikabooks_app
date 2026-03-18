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
              Text('같은 결을 가진 동료와 연결되어 한 주를 함께하는 공간이에요.', style: TextStyle(fontSize: 13, height: 1.5)),
              SizedBox(height: 16),
              Text('💛 결 점수', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('나 탭의 교감, 파트너와의 이야기, 기록·목표 실천이 함께 반영돼요.', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
              SizedBox(height: 16),
              Text('👥 파트너', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('비슷한 고민을 가진 이들과 7일간 매칭돼요. 원하면 연장할 수 있어요.', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
              SizedBox(height: 16),
              Text('✏️ 글작성 (털어놔)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('파트너가 있으면 오늘의 한 줄을 기록할 수 있어요.\n하루 최대 4편까지, 작성한 글은 최근 6시간 동안 보여요.', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
              SizedBox(height: 16),
              Text('✨ 전국구 게시판', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('파트너 그룹에서 만장일치로 추대된 이야기가\n전국 사용자에게 공유돼요.', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
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
