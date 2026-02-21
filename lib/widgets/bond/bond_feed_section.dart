import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../bond_post_card.dart';
import 'bond_colors.dart';

/// 오늘을 나누기 피드 섹션
class BondFeedSection extends StatelessWidget {
  final String? partnerGroupId;
  final VoidCallback onOpenWrite;

  const BondFeedSection({
    super.key,
    required this.partnerGroupId,
    required this.onOpenWrite,
  });

  // 파트너 그룹 가입 여부
  bool get _hasPartnerGroup => partnerGroupId != null && partnerGroupId!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 타이틀 (다른 항목들처럼)
          Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 16,
                color: BondColors.kText.withOpacity(0.6),
              ),
              const SizedBox(width: 6),
              const Text(
                '털어놔',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: BondColors.kText,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '여기선 괜찮아',
                style: TextStyle(
                  fontSize: 11,
                  color: BondColors.kText.withOpacity(0.4),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),

          // 게시물 피드
          StreamBuilder<QuerySnapshot?>(
            stream: partnerGroupId != null && partnerGroupId!.isNotEmpty
                ? FirebaseFirestore.instance
                    .collection('partnerGroups')
                    .doc(partnerGroupId)
                    .collection('posts')
                    .where('isDeleted', isEqualTo: false)
                    .orderBy('createdAtClient', descending: true)
                    .limit(3)
                    .snapshots()
                : Stream.value(null),
            builder: (context, snap) {
              if (!_hasPartnerGroup) {
                return _buildEmptyState(
                  icon: Icons.people_outline,
                  text: '파트너 그룹에 가입하면 사용할 수 있어요',
                  onTap: null, // 가입 전에는 터치 불가
                );
              }

              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snap.hasError) {
                return Center(
                  child: Text(
                    '불러오는 중 문제가 생겼어요.',
                    style: TextStyle(
                      fontSize: 13,
                      color: BondColors.kText.withOpacity(0.5),
                    ),
                  ),
                );
              }

              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return _buildEmptyState(
                  icon: Icons.edit_note_outlined,
                  text: '첫 이야기를 나눠주세요',
                  onTap: onOpenWrite,
                );
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return BondPostCard(
                    post: data,
                    postId: doc.id,
                    bondGroupId: partnerGroupId,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String text,
    required VoidCallback? onTap, // nullable로 변경
  }) {
    return GestureDetector(
      onTap: onTap, // null이면 터치 불가
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: BondColors.kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: BondColors.kShadow2.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: BondColors.kText.withOpacity(0.3),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: BondColors.kText.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



