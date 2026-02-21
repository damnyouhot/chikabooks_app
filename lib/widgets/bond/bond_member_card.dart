import 'package:flutter/material.dart';
import '../../models/partner_group.dart';

/// 파트너 그룹 멤버 카드 (개선된 디자인)
/// - 연차/지역/태그 표시
/// - 보충 멤버 배지
/// - 이어가기 페어 표시
class BondMemberCard extends StatelessWidget {
  final GroupMemberMeta member;
  final bool isMe;
  final bool isSupplemented;
  final bool isContinuePair;

  const BondMemberCard({
    super.key,
    required this.member,
    this.isMe = false,
    this.isSupplemented = false,
    this.isContinuePair = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? const Color(0xFF1E88E5).withOpacity(0.5)
              : Colors.grey[200]!,
          width: isMe ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 아바타 + 기본 정보
          Row(
            children: [
              // 아바타
              _buildAvatar(),
              
              const SizedBox(width: 14),
              
              // 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          member.careerBucket.isNotEmpty
                              ? member.careerBucket
                              : '연차 미표시',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF424242),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (isMe)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E88E5).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '나',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E88E5),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      member.region.isNotEmpty
                          ? '📍 ${member.region}'
                          : '📍 지역 미표시',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // 배지
              if (isSupplemented)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[300]!),
                  ),
                  child: const Text(
                    '🍃 보충',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
              
              if (isContinuePair && !isSupplemented)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber[300]!),
                  ),
                  child: const Text(
                    '💛 이어가기',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFF57C00),
                    ),
                  ),
                ),
            ],
          ),
          
          // 태그 (있을 경우)
          if (member.mainConcernShown != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                _buildTag(member.mainConcernShown!),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E88E5).withOpacity(0.8),
            const Color(0xFF42A5F5),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E88E5).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          member.region.isNotEmpty ? member.region[0] : '?',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '#$tag',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[700],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 그룹 멤버 목록 섹션
class BondMemberListSection extends StatelessWidget {
  final String? myUid;
  final List<GroupMemberMeta> members;
  final List<String>? previousPair; // 이어가기 페어 UID 목록
  final bool needsSupplementation; // 보충 필요 여부

  const BondMemberListSection({
    super.key,
    this.myUid,
    required this.members,
    this.previousPair,
    this.needsSupplementation = false,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              const Text(
                '이번 주 파트너',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF424242),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${members.length}명',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E88E5),
                ),
              ),
            ],
          ),
        ),
        
        // 멤버 카드들
        ...members.map((member) {
          final isMe = member.uid == myUid;
          final isContinuePair = previousPair?.contains(member.uid) ?? false;
          final isSupplemented = member.isSupplemented;
          
          return BondMemberCard(
            member: member,
            isMe: isMe,
            isSupplemented: isSupplemented,
            isContinuePair: isContinuePair,
          );
        }),
        
        // 보충 대기 안내
        if (needsSupplementation && members.length < 3)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '곧 한 명 더 함께할 거예요',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 16),
      ],
    );
  }
}

