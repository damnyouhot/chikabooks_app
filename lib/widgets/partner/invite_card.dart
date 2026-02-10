import 'package:flutter/material.dart';
import '../../services/partner_service.dart';
import '../../services/user_profile_service.dart';
import '../partner_gate_sheet.dart';
import '../profile_gate_sheet.dart';

/// 추천/초대 카드
/// "추천으로 찾기" 버튼에 Step A → Step B 게이트 적용
class InviteCard extends StatelessWidget {
  const InviteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA5D6A7).withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.group_add_outlined,
                  color: Color(0xFFA5D6A7), size: 20),
              SizedBox(width: 8),
              Text(
                '파트너 찾기',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF424242),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // 직접 초대는 MVP에서 미구현 안내
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('직접 초대는 곧 준비될 예정이에요')),
                    );
                  },
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('직접 초대'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6A5ACD),
                    side: const BorderSide(color: Color(0xFF6A5ACD)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _onRecommend(context),
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('추천으로 찾기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A5ACD),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 추천으로 찾기: Step A → Step B → 매칭풀 등록
  void _onRecommend(BuildContext context) async {
    // Step A 검사
    final hasBasic = await UserProfileService.hasBasicProfile();
    if (!context.mounted) return;

    if (!hasBasic) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ProfileGateSheet(
          onComplete: () {
            if (context.mounted) {
              // Step A 완료 → Step B 검사
              _checkStepB(context);
            }
          },
        ),
      );
      return;
    }

    // Step B 검사
    _checkStepB(context);
  }

  void _checkStepB(BuildContext context) async {
    final hasPartner = await UserProfileService.hasPartnerProfile();
    if (!context.mounted) return;

    if (!hasPartner) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
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

  void _doMatch(BuildContext context) async {
    await PartnerService.joinMatchingPool();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('매칭풀에 등록되었어요!\n비슷한 동료를 찾으면 알려드릴게요 ✨'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}

