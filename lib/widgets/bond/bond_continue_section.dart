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
  Set<String> _selectedPartnerUids = {};
  String? _myUid;
  bool _loading = true;
  bool _isCollapsed = true; // 처음엔 접혀있음

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid;
    _loadCurrentSelection();
  }

  Future<void> _loadCurrentSelection() async {
    try {
      // 처음엔 아무도 선택 안되게 (기존 선택 무시)
      if (mounted) {
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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _isCollapsed = !_isCollapsed;
              });
            },
            child: Row(
              children: [
                const Icon(
                  Icons.people_outline,
                  color: Color(0xFFCE93D8),
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
                          color: Color(0xFF424242),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedPartnerUids.isEmpty
                            ? '선택하지 않아도 괜찮아'
                            : '${_selectedPartnerUids.length}명 선택함',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _isCollapsed ? Icons.expand_more : Icons.expand_less,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ],
            ),
          ),

          if (!_isCollapsed) ...[
            const SizedBox(height: 16),

            // 파트너 선택 카드
            ...otherMembers.map((member) => _buildPartnerCard(member)),

            const SizedBox(height: 12),

            // 안내 문구
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _selectedPartnerUids.isEmpty
                    ? '선택하지 않으면 새로운 만남으로 시작해요'
                    : _selectedPartnerUids.length == 1
                    ? '한 사람을 선택했어요'
                    : '두 사람 모두 선택했어요',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            if (_selectedPartnerUids.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _completeSelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A5ACD),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '완료',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _cancelAllSelections,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    '선택 취소',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPartnerCard(GroupMemberMeta member) {
    final isSelected = _selectedPartnerUids.contains(member.uid);

    return GestureDetector(
      onTap: () => _togglePartner(member.uid),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF3E5F5) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFCE93D8) : Colors.grey[200]!,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // 아바타
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? const Color(0xFFCE93D8).withOpacity(0.2)
                        : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  member.region.isNotEmpty ? member.region[0] : '?',
                  style: TextStyle(
                    color:
                        isSelected ? const Color(0xFFCE93D8) : Colors.grey[600],
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
                      color: Color(0xFF424242),
                    ),
                  ),
                  if (member.mainConcernShown != null)
                    Text(
                      '#${member.mainConcernShown}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFFCE93D8), size: 22)
            else
              Icon(
                Icons.radio_button_unchecked,
                color: Colors.grey[400],
                size: 22,
              ),
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

  Future<void> _togglePartner(String partnerUid) async {
    setState(() {
      if (_selectedPartnerUids.contains(partnerUid)) {
        _selectedPartnerUids.remove(partnerUid);
      } else {
        _selectedPartnerUids.add(partnerUid);
      }
    });
  }

  void _completeSelection() {
    setState(() {
      _isCollapsed = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_selectedPartnerUids.length}명을 선택했어요!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _cancelAllSelections() async {
    try {
      await UserProfileService.selectContinuePartner(null);
      if (mounted) {
        setState(() {
          _selectedPartnerUids.clear();
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


