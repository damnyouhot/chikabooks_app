import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../bond_post_card.dart';
import 'bond_colors.dart';

/// 오늘을 나누기 피드 섹션
class BondFeedSection extends StatelessWidget {
  final String? partnerGroupId;
  final Map<String, String>? memberNicknames;
  final VoidCallback onOpenWrite;

  const BondFeedSection({
    super.key,
    required this.partnerGroupId,
    required this.memberNicknames,
    required this.onOpenWrite,
  });

  bool get _hasPartnerGroup =>
      partnerGroupId != null && partnerGroupId!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isPersonalMode = !_hasPartnerGroup;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 타이틀
          Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 16,
                color:
                    isPersonalMode
                        ? BondColors.kText.withOpacity(0.4)
                        : BondColors.kText.withOpacity(0.6),
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
              TextButton(
                onPressed: isPersonalMode ? null : onOpenWrite,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: BondColors.kText.withOpacity(0.7),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('글작성'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 게시물 피드
          StreamBuilder<QuerySnapshot>(
            stream:
                _hasPartnerGroup
                    ? FirebaseFirestore.instance
                        .collection('partnerGroups')
                        .doc(partnerGroupId)
                        .collection('posts')
                        .where('isDeleted', isEqualTo: false)
                        // 6시간 존속: 최근 6시간 내 글만 노출
                        .where(
                          'createdAtClient',
                          isGreaterThanOrEqualTo: Timestamp.fromDate(
                            DateTime.now().subtract(const Duration(hours: 6)),
                          ),
                        )
                        .orderBy('createdAtClient', descending: true)
                        .limit(3)
                        .snapshots()
                    : const Stream<QuerySnapshot>.empty(), // ✅ 개인 모드는 빈 스트림
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snap.hasError) {
                debugPrint('⚠️ [BondFeedSection] 에러: ${snap.error}');
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '데이터 조회 오류',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snap.error}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // ✅ 개인 모드: 파트너 필요 안내
              if (!_hasPartnerGroup) {
                return _buildEmptyState(
                  icon: Icons.group_outlined,
                  text: '파트너와 함께할 때만\n기록할 수 있어요',
                  subtitle: '매칭을 시작해보세요',
                  onTap: null, // 터치 비활성화
                  isPersonalMode: true,
                );
              }

              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return _buildEmptyState(
                  icon: Icons.edit_note_outlined,
                  text: '첫 이야기를 나눠주세요',
                  subtitle: null,
                  onTap: onOpenWrite,
                  isPersonalMode: false,
                );
              }

              return Column(
                children: [
                  ...docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return BondPostCard(
                      post: data,
                      postId: doc.id,
                      bondGroupId: partnerGroupId,
                      memberNicknames: memberNicknames,
                    );
                  }),
                ],
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
    String? subtitle,
    required VoidCallback? onTap,
    required bool isPersonalMode,
  }) {
    return GestureDetector(
      onTap: onTap, // null이면 터치 비활성화
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isPersonalMode ? Colors.grey[100] : BondColors.kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isPersonalMode
                    ? Colors.grey[300]!
                    : BondColors.kShadow2.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color:
                  isPersonalMode
                      ? Colors.grey[400]
                      : BondColors.kText.withOpacity(0.3),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color:
                    isPersonalMode
                        ? Colors.grey[600]
                        : BondColors.kText.withOpacity(0.5),
                height: 1.4,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

