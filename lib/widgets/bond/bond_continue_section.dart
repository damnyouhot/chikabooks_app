import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/partner_group.dart';
import '../../services/user_profile_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';
import '../../core/widgets/app_primary_button.dart';

/// 이어가기 선택 섹션 (주말에만 표시)
///
/// 규칙:
/// - 2인 그룹: 서로 선택해야 이어가기 성사
/// - 3인 그룹: 전원(나 포함 3명 모두)이 나머지 2명을 선택해야 성사
class BondContinueSection extends StatefulWidget {
  final String groupId;
  final List<GroupMemberMeta> members;

  const BondContinueSection({
    super.key,
    required this.groupId,
    required this.members,
  });

  @override
  State<BondContinueSection> createState() => _BondContinueSectionState();
}

class _BondContinueSectionState extends State<BondContinueSection> {
  Set<String> _selectedPartnerUids = {};
  String? _myUid;
  bool _loading = true;
  bool _saving = false;
  bool _isCollapsed = true;
  bool _saved = false; // 저장 완료 여부

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid;
    _loadCurrentSelection();
  }

  Future<void> _loadCurrentSelection() async {
    try {
      // 기존 저장된 선택값 불러오기
      final profile = await UserProfileService.getMyProfile(forceRefresh: false);
      if (mounted) {
        final saved = profile?.continueWithPartners ?? [];
        setState(() {
          _selectedPartnerUids = saved.toSet();
          _saved = saved.isNotEmpty;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShowContinueSection()) return const SizedBox.shrink();

    final otherMembers = widget.members.where((m) => m.uid != _myUid).toList();
    if (otherMembers.isEmpty || otherMembers.length > 2) {
      return const SizedBox.shrink();
    }
    if (_loading) return const SizedBox.shrink();

    final isGroupOf3 = otherMembers.length == 2; // 나 포함 3명
    final requiredCount = isGroupOf3 ? 2 : 1;    // 선택해야 할 최소 인원

    return AppMutedCard(
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isCollapsed = !_isCollapsed),
            child: Row(
              children: [
                const Icon(
                  Icons.people_outline,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '다음 주에도 같이 나누고 싶은 사람',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _saved
                            ? '✓ ${_selectedPartnerUids.length}명 선택 완료'
                            : _selectedPartnerUids.isEmpty
                            ? '선택하지 않아도 괜찮아'
                                : '${_selectedPartnerUids.length}명 선택 중',
                        style: TextStyle(
                          fontSize: 12,
                          color: _saved
                              ? AppColors.accent
                              : AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _isCollapsed ? Icons.expand_more : Icons.expand_less,
                  color: AppColors.textDisabled,
                  size: 20,
                ),
              ],
            ),
          ),
          if (!_isCollapsed) ...[
            const SizedBox(height: 16),
            ...otherMembers.map((member) => _buildPartnerCard(member)),
            const SizedBox(height: 12),
            // 안내 메시지
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                _getGuideText(isGroupOf3, requiredCount),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            // 완료 / 취소 버튼
            if (_selectedPartnerUids.isNotEmpty) ...[
              AppPrimaryButton(
                label: _saving
                    ? '저장 중...'
                    : _saved
                        ? '✓ 저장됨'
                        : '완료',
                onPressed: (_saving || _saved) ? null : () => _completeSelection(requiredCount),
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                ),
                radius: AppRadius.md,
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : _cancelAllSelections,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textDisabled,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  child: const Text('선택 취소', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _getGuideText(bool isGroupOf3, int requiredCount) {
    if (_selectedPartnerUids.isEmpty) {
      return isGroupOf3
          ? '3명 그룹은 모두 선택해야 이어가기가 성사돼요'
          : '선택하지 않으면 새로운 만남으로 시작해요';
    }
    if (_selectedPartnerUids.length < requiredCount) {
      return '${requiredCount}명 모두 선택해야 이어가기 신청이 완료돼요';
    }
    return _saved
        ? '이어가기 신청 완료! 상대방도 선택하면 다음 주에 이어져요'
        : '${_selectedPartnerUids.length}명 모두 선택했어요. 완료를 눌러주세요';
  }

  Widget _buildPartnerCard(GroupMemberMeta member) {
    final isSelected = _selectedPartnerUids.contains(member.uid);

    return GestureDetector(
      onTap: _saved ? null : () => _togglePartner(member.uid),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withOpacity(0.08)
              : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accent.withOpacity(0.15)
                    : AppColors.disabledBg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  member.region.isNotEmpty ? member.region[0] : '?',
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.accent
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (member.mainConcerns.isNotEmpty)
                    Text(
                      member.mainConcerns.take(2).map((t) => '#$t').join('  '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textDisabled,
                      ),
                    )
                  else if (member.mainConcernShown != null)
                    Text(
                      '#${member.mainConcernShown}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textDisabled,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.accent : AppColors.textDisabled,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowContinueSection() {
    final kst       = DateTime.now().toUtc().add(const Duration(hours: 9));
    final dayOfWeek = kst.weekday;
    final hour      = kst.hour;
    if (dayOfWeek == 7 && hour >= 18) return true;
    if (dayOfWeek == 1 && hour < 9) return true;
    return false;
  }

  Future<void> _togglePartner(String partnerUid) async {
    setState(() {
      if (_selectedPartnerUids.contains(partnerUid)) {
        _selectedPartnerUids.remove(partnerUid);
      } else {
        _selectedPartnerUids.add(partnerUid);
      }
    });
  }

  Future<void> _completeSelection(int requiredCount) async {
    // 3명 그룹은 나머지 2명 모두 선택해야 함
    if (_selectedPartnerUids.length < requiredCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            requiredCount == 2
                ? '3명 그룹은 두 사람 모두 선택해야 이어가기가 돼요'
                : '한 사람을 선택해주세요',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await UserProfileService.selectContinuePartners(
        _selectedPartnerUids.toList(),
      );
      if (mounted) {
        setState(() {
          _saved = true;
          _saving = false;
          _isCollapsed = true;
        });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
            content: Text('${_selectedPartnerUids.length}명과 이어가기 신청했어요! 🌱'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('저장에 실패했어요. 다시 시도해주세요'),
        behavior: SnackBarBehavior.floating,
      ),
    );
      }
    }
  }

  Future<void> _cancelAllSelections() async {
    setState(() => _saving = true);
    try {
      await UserProfileService.cancelContinuePartners();
      if (mounted) {
        setState(() {
          _selectedPartnerUids.clear();
          _saved = false;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('선택을 모두 취소했어요'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('취소에 실패했어요'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
