import 'package:flutter/material.dart';
import '../models/enthrone.dart';
import '../services/enthrone_service.dart';

// ── 디자인 팔레트 (bond_page와 통일) ──
const _kAccent = Color(0xFFF7CBCA);
const _kText = Color(0xFF5D6B6B);
const _kShadow2 = Color(0xFFD5E5E5);
const _kCardBg = Colors.white;

/// 전광판 카드 위젯
class BillboardCard extends StatelessWidget {
  final BillboardPost post;
  final VoidCallback? onTap;

  const BillboardCard({
    super.key,
    required this.post,
    this.onTap,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays}일 전';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}시간 전';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}분 전';
    } else {
      return '방금';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _kShadow2.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _kShadow2.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // 헤더: 닉네임 + 작성일
            Row(
              children: [
                Text(
                  post.authorNickname ?? '익명',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(post.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: _kText.withOpacity(0.5),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 본문 (고정 높이 2줄)
            SizedBox(
              height: 50,
              child: Text(
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
            ),

            const SizedBox(height: 12),

            // 이모지 반응
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildReactionChip('👏', post.reactions?['👏'] ?? 0),
                _buildReactionChip('❤️', post.reactions?['❤️'] ?? 0),
                _buildReactionChip('🔥', post.reactions?['🔥'] ?? 0),
                _buildReactionChip('👀', post.reactions?['👀'] ?? 0),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionChip(String emoji, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: count > 0
            ? _kAccent.withOpacity(0.2)
            : _kShadow2.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: count > 0
            ? Border.all(color: _kAccent.withOpacity(0.4), width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 16),
          ),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
          ],
        ],
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

