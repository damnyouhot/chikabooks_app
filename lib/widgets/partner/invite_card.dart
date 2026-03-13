import 'package:flutter/material.dart';
import '../../services/partner_service.dart';
import '../../services/user_profile_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';
import '../partner_gate_sheet.dart';
import '../profile_gate_sheet.dart';

/// 추천/초대 카드
///
/// "추천으로 찾기" → Cloud Function(requestPartnerMatching) 호출
/// 결과에 따라 matched / waiting / error UI 피드백
class InviteCard extends StatefulWidget {
  /// 매칭 성공 시 부모(PartnerPage)가 데이터를 갱신할 수 있도록 콜백
  final VoidCallback? onMatchSuccess;

  const InviteCard({super.key, this.onMatchSuccess});

  @override
  State<InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends State<InviteCard> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AppMutedCard(
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.lg + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.all_inclusive,
                  color: AppColors.accent.withOpacity(0.6), size: 20),
              const SizedBox(width: 8),
              const Text(
                '파트너 찾기',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '비슷한 고민을 가진 3명이\n1주일간 서로의 하루를 나눕니다.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textDisabled,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // 직접 초대
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('직접 초대는 곧 준비될 예정이에요.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_outlined,
                            size: 14, color: AppColors.textDisabled),
                        const SizedBox(width: 6),
                        const Text(
                          '직접 초대',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textDisabled,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 추천으로 찾기
              Expanded(
                child: GestureDetector(
                  onTap: _isLoading ? null : () => _onRecommend(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      color: AppColors.accent,
                    ),
                    child: _isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.auto_awesome,
                                  size: 14, color: AppColors.onAccent),
                              SizedBox(width: 6),
                              Text(
                                '추천으로 찾기',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onAccent,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 추천으로 찾기: Step A → Step B → 서버 매칭 요청
  void _onRecommend(BuildContext context) async {
    final hasBasic = await UserProfileService.hasBasicProfile();
    if (!context.mounted) return;

    if (!hasBasic) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.white,
        builder: (_) => ProfileGateSheet(
          onComplete: () {
            if (context.mounted) _checkStepB(context);
          },
        ),
      );
      return;
    }

    _checkStepB(context);
  }

  void _checkStepB(BuildContext context) async {
    final hasPartner = await UserProfileService.hasPartnerProfile();
    if (!context.mounted) return;

    if (!hasPartner) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.white,
        builder: (_) => PartnerGateSheet(
          onComplete: () {
            if (context.mounted) _doMatch(context);
          },
        ),
      );
      return;
    }

    _doMatch(context);
  }

  /// Cloud Functions callable 호출 → 결과 피드백
  void _doMatch(BuildContext context) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final result = await PartnerService.requestMatching();

      if (!context.mounted) return;

      switch (result.status) {
        case MatchingStatus.matched:
          _showResultDialog(
            context,
            icon: Icons.celebration_outlined,
            title: '파트너를 찾았어요!',
            subtitle: '1주일간 서로의 하루를 나눠보세요.',
            buttonText: '확인',
            onButton: () {
              Navigator.pop(context); // dialog만 닫기
              // PartnerPage를 pop하지 않고, 콜백으로 데이터 갱신
              widget.onMatchSuccess?.call();
            },
          );
          break;

        case MatchingStatus.waiting:
          _showResultDialog(
            context,
            icon: Icons.hourglass_empty_outlined,
            title: '매칭 대기 중',
            subtitle: result.message ?? '아직 함께할 사람이 부족해요.',
            buttonText: '알겠어요',
            onButton: () => Navigator.pop(context),
          );
          break;

        case MatchingStatus.error:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? '문제가 생겼어요.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          break;
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 매칭 결과 다이얼로그 (미니멀 디자인)
  void _showResultDialog(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onButton,
  }) {
    showDialog(
      context: context,
      barrierColor: AppColors.black.withOpacity(0.12),
      builder: (_) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.xl + 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withOpacity(0.08),
                ),
                child: Icon(icon, size: 28,
                    color: AppColors.accent.withOpacity(0.7)),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textDisabled,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onButton,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    buttonText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onAccent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
