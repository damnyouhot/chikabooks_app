import 'package:flutter/material.dart';
import '../../services/user_profile_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';

/// 파트너 쉬기/활동 상태 관리 카드
class BondPauseCard extends StatefulWidget {
  const BondPauseCard({super.key});

  @override
  State<BondPauseCard> createState() => _BondPauseCardState();
}

class _BondPauseCardState extends State<BondPauseCard> {
  String _partnerStatus = 'active';
  bool _willMatchNextWeek = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final profile = await UserProfileService.getMyProfile(forceRefresh: true);
      if (mounted && profile != null) {
        setState(() {
          _partnerStatus    = profile.partnerStatus;
          _willMatchNextWeek = profile.willMatchNextWeek;
          _loading          = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    return _partnerStatus == 'active'
        ? _buildActiveState()
        : _buildPauseState();
  }

  Widget _buildActiveState() {
    return AppMutedCard(
      radius: AppRadius.md,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          const Icon(Icons.people, color: AppColors.accent, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '매주 월요일 09시에 자동 매칭',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '알아서 새로운 파트너와 함께해요',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _showPauseDialog,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
            ),
            child: const Text('쉬기'),
          ),
        ],
      ),
    );
  }

  Widget _buildPauseState() {
    return AppMutedCard(
      radius: AppRadius.md,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pause_circle_outline,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '지금은 쉬는 중',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _resumeActive,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                ),
                child: const Text('다시 시작'),
              ),
            ],
          ),
          const Divider(height: 24, color: AppColors.divider),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '다음 주 매칭 되기',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _willMatchNextWeek
                          ? '다음 주엔 다시, 페이지를 펼칠래요'
                          : '조금 더 조용히 있을래요',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _willMatchNextWeek,
                onChanged: _updateWillMatch,
                activeColor: AppColors.accent,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '💡 매칭 시간: 월요일 오전 9시',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  void _showPauseDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('잠시 쉬어갈까요?'),
        content: const Text(
          '쉬는 동안에는 새로운 파트너가 매칭되지 않아요.\n'
          '언제든 다시 시작할 수 있어요.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _setPauseStatus();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: AppColors.white,
              elevation: 0,
            ),
            child: const Text('쉬기'),
          ),
        ],
      ),
    );
  }

  Future<void> _setPauseStatus() async {
    try {
      await UserProfileService.updatePartnerStatus('pause');
      if (mounted) {
        setState(() => _partnerStatus = 'pause');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('쉬기 상태로 변경되었어요'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('오류가 발생했어요'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _resumeActive() async {
    try {
      await UserProfileService.updatePartnerStatus('active');
      if (mounted) {
        setState(() => _partnerStatus = 'active');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('다시 활동을 시작해요!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('오류가 발생했어요'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _updateWillMatch(bool value) async {
    try {
      await UserProfileService.updateWillMatchNextWeek(value);
      if (mounted) {
        setState(() => _willMatchNextWeek = value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value ? '다음 주에 매칭됩니다' : '다음 주에는 매칭되지 않아요',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('설정 변경에 실패했어요'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
