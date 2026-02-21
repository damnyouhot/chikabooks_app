import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/partner_group.dart';
import '../../services/user_profile_service.dart';

/// 이어가기 선택 섹션 (주말에만 표시)
/// 일요일 18:00 ~ 월요일 08:30 사이에만 노출
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
  String? _selectedPartnerUid;
  String? _myUid;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid;
    _loadCurrentSelection();
  }

  Future<void> _loadCurrentSelection() async {
    try {
      final profile = await UserProfileService.getMyProfile(forceRefresh: true);
      if (mounted && profile?.continueWithPartner != null) {
        setState(() {
          _selectedPartnerUid = profile!.continueWithPartner;
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 노출 시점 체크: 일요일 18:00 ~ 월요일 08:30
    if (!_shouldShowContinueSection()) {
      return const SizedBox.shrink();
    }

    // 내가 아닌 다른 멤버들
    final otherMembers = widget.members.where((m) => m.uid != _myUid).toList();

    if (otherMembers.isEmpty || otherMembers.length > 2) {
      return const SizedBox.shrink();
    }

    if (_loading) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFFFB74D), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '💛',
                style: TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '다음 주에도 같이 걸을 사람(1명)을\n고를래요?',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF424242),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 파트너 선택 카드
          ...otherMembers.map((member) => _buildPartnerCard(member)),

          const SizedBox(height: 12),

          // 안내 문구
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _selectedPartnerUid == null
                  ? '선택 안 해도 괜찮아요\n(자동으로 새로 시작해요)'
                  : '선택이 서로 맞으면 다음 주에도 함께해요',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[700],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          if (_selectedPartnerUid != null) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _cancelSelection,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  '선택 취소',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPartnerCard(GroupMemberMeta member) {
    final isSelected = _selectedPartnerUid == member.uid;

    return GestureDetector(
      onTap: () => _selectPartner(member.uid),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E88E5) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1E88E5).withOpacity(0.2),
                    blurRadius: 8,
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            // 아바타
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFE3F2FD),
              child: Text(
                member.region.isNotEmpty ? member.region[0] : '?',
                style: const TextStyle(
                  color: Color(0xFF1E88E5),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${member.careerBucket} · ${member.region}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF424242),
                    ),
                  ),
                  if (member.mainConcernShown != null)
                    Text(
                      '#${member.mainConcernShown}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF1E88E5), size: 24)
            else
              Icon(Icons.radio_button_unchecked, color: Colors.grey[400], size: 24),
          ],
        ),
      ),
    );
  }

  bool _shouldShowContinueSection() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    final dayOfWeek = kst.weekday; // 1=월, 7=일
    final hour = kst.hour;

    // 일요일 18:00 ~ 23:59
    if (dayOfWeek == 7 && hour >= 18) {
      return true;
    }

    // 월요일 00:00 ~ 08:30
    if (dayOfWeek == 1 && hour < 9) {
      return true;
    }

    return false;
  }

  Future<void> _selectPartner(String partnerUid) async {
    try {
      await UserProfileService.selectContinuePartner(partnerUid);
      if (mounted) {
        setState(() {
          _selectedPartnerUid = partnerUid;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('선택했어요! 상대도 나를 선택하면 함께해요'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('선택에 실패했어요'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _cancelSelection() async {
    try {
      await UserProfileService.selectContinuePartner(null);
      if (mounted) {
        setState(() {
          _selectedPartnerUid = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('선택을 취소했어요'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
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

