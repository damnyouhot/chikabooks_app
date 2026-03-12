import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../bond_post_card.dart';
import '../../core/theme/tab_theme.dart';

const _b = TabTheme.bond;

/// 오늘을 나누기 피드 섹션
class BondFeedSection extends StatefulWidget {
  final String? partnerGroupId;
  final Map<String, String>? memberNicknames;
  final VoidCallback onOpenWrite;

  const BondFeedSection({
    super.key,
    required this.partnerGroupId,
    required this.memberNicknames,
    required this.onOpenWrite,
  });

  @override
  State<BondFeedSection> createState() => _BondFeedSectionState();
}

class _BondFeedSectionState extends State<BondFeedSection> {
  Stream<QuerySnapshot>? _stream;

  bool get _hasPartnerGroup =>
      widget.partnerGroupId != null && widget.partnerGroupId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void didUpdateWidget(BondFeedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.partnerGroupId != widget.partnerGroupId) {
      setState(() {
        _initStream();
      });
    }
  }

  void _initStream() {
    if (_hasPartnerGroup) {
      _stream = FirebaseFirestore.instance
          .collection('partnerGroups')
          .doc(widget.partnerGroupId)
          .collection('posts')
          .where('isDeleted', isEqualTo: false)
          .where(
            'createdAtClient',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              DateTime.now().subtract(const Duration(hours: 6)),
            ),
          )
          .orderBy('createdAtClient', descending: true)
          .limit(3)
          .snapshots();
    } else {
      _stream = const Stream<QuerySnapshot>.empty();
    }
  }

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
                color: _b.onBg.withOpacity(isPersonalMode ? 0.4 : 0.6),
              ),
              const SizedBox(width: 6),
              Text(
                '털어놔',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _b.onBg,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '여기선 괜찮아',
                style: TextStyle(
                  fontSize: 11,
                  color: _b.onBg.withOpacity(0.4),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: isPersonalMode ? null : widget.onOpenWrite,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: isPersonalMode
                      ? Colors.transparent
                      : _b.accent,             // Blue 배경
                  foregroundColor: isPersonalMode
                      ? _b.onBg.withOpacity(0.3)
                      : _b.onAccent,           // White 텍스트
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('글작성'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 게시물 피드
          StreamBuilder<QuerySnapshot>(
            stream: _stream,
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
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
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
                        style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                      ),
                    ],
                  ),
                );
              }

              if (!_hasPartnerGroup) {
                return _buildEmptyState(
                  icon: Icons.group_outlined,
                  text: '파트너와 함께할 때만\n기록할 수 있어요',
                  subtitle: '매칭을 시작해보세요',
                  onTap: null,
                  isPersonalMode: true,
                );
              }

              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return _buildEmptyState(
                  icon: Icons.edit_note_outlined,
                  text: '첫 이야기를 나눠주세요',
                  subtitle: null,
                  onTap: widget.onOpenWrite,
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
                      bondGroupId: widget.partnerGroupId,
                      memberNicknames: widget.memberNicknames,
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
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: isPersonalMode
            ? BoxDecoration(
                color: _b.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _b.shadow1.withOpacity(0.3)),
              )
            : _b.strongCardDecoration(),  // Blue 빈 피드 카드
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: isPersonalMode
                  ? _b.onBg.withOpacity(0.3)
                  : _b.onAccent.withOpacity(0.7),  // White on Blue
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isPersonalMode
                    ? _b.onBg.withOpacity(0.5)
                    : _b.onAccent,  // White on Blue
                height: 1.4,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: isPersonalMode
                      ? _b.accent
                      : _b.cardNeon,   // Neon 서브텍스트 버튼
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isPersonalMode ? _b.onAccent : _b.onCardNeon,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
