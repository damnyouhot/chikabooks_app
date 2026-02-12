import 'package:flutter/material.dart';
import '../../models/partner_group.dart';

/// "이번 주 파트너" 상태 카드
class GroupStatusCard extends StatelessWidget {
  final PartnerGroup group;
  final List<GroupMemberMeta> members;

  const GroupStatusCard({
    super.key,
    required this.group,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    final daysLeft = group.daysLeft;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A5ACD).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              const Icon(Icons.people_outline,
                  color: Color(0xFF6A5ACD), size: 20),
              const SizedBox(width: 8),
              const Text(
                '이번 주 파트너',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF424242),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: daysLeft <= 1
                      ? const Color(0xFFFFEBEE)
                      : const Color(0xFFE8EAF6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  daysLeft == 0 ? '오늘 종료' : 'D-$daysLeft',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: daysLeft <= 1
                        ? Colors.redAccent
                        : const Color(0xFF6A5ACD),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 멤버 라벨 (닉네임/사진 없이 뱃지만)
          ...members.map((m) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFCE93D8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      m.displayLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}



