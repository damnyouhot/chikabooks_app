import 'package:flutter/material.dart';
import '../models/enthrone.dart';
import '../services/enthrone_service.dart';

/// 전광판 카드 위젯
class BillboardCard extends StatelessWidget {
  final BillboardPost post;
  final VoidCallback? onTap;

  const BillboardCard({
    super.key,
    required this.post,
    this.onTap,
  });

  String _formatTimeRemaining() {
    final now = DateTime.now();
    final remaining = post.expiresAt.difference(now);

    if (remaining.inHours > 24) {
      return '${remaining.inHours ~/ 24}일 남음';
    } else if (remaining.inHours > 0) {
      return '${remaining.inHours}시간 남음';
    } else if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes}분 남음';
    } else {
      return '곧 만료';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF6A5ACD).withOpacity(0.1),
              const Color(0xFFF7CBCA).withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF6A5ACD).withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6A5ACD).withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                // 추대 아이콘
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6A5ACD).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFF6A5ACD),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                
                // 제목
                const Expanded(
                  child: Text(
                    '✨ 오늘의 추대',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6A5ACD),
                    ),
                  ),
                ),

                // 추대 수
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6A5ACD).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${post.enthroneCount}/${post.requiredCount}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6A5ACD),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 본문 (최대 2줄)
            Text(
              post.textSnapshot,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Color(0xFF333333),
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 12),

            // 하단 정보
            Row(
              children: [
                // 출처
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    post.isAnonymous 
                        ? '${post.bondGroupName}에서'
                        : post.bondGroupName,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),

                // 남은 시간
                Text(
                  _formatTimeRemaining(),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),

                const Spacer(),

                // 더보기 아이콘
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 전광판 섹션 위젯 (Bond 페이지에 삽입)
class BillboardSection extends StatelessWidget {
  const BillboardSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 헤더
          Row(
            children: [
              const Text(
                '🎯 전광판',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D6B6B),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // TODO: 전광판 전체 보기 페이지로 이동
                },
                child: Text(
                  '더보기',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 전광판 카드 (StreamBuilder로 실시간 데이터)
          StreamBuilder<List<BillboardPost>>(
            stream: EnthroneService.watchActiveBillboard(limit: 3),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final posts = snapshot.data ?? [];

              if (posts.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '아직 추대된 글이 없어요',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '좋은 글에 추대를 보내보세요',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: posts.map((post) {
                  return BillboardCard(
                    post: post,
                    onTap: () {
                      // TODO: 상세 보기
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

