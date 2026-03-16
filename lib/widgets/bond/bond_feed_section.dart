import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../bond_post_card.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';
import '../../core/widgets/glass_card.dart';

/// 오늘을 나누기 피드 섹션
class BondFeedSection extends StatefulWidget {
  final String? partnerGroupId;
  final Map<String, String>? memberNicknames;
  final VoidCallback onOpenWrite;
  final VoidCallback? onFindPartnerTap; // 파트너 없을 때 '매칭하기' 버튼 콜백
  final bool glassMode;
  final bool isMatching; // 매칭 요청 중 로딩 상태

  const BondFeedSection({
    super.key,
    required this.partnerGroupId,
    required this.memberNicknames,
    required this.onOpenWrite,
    this.onFindPartnerTap,
    this.glassMode = false,
    this.isMatching = false,
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
      setState(() => _initStream());
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
    final titleColor    = widget.glassMode ? AppColors.white : AppColors.textPrimary;
    final subtitleColor = widget.glassMode ? AppColors.white.withOpacity(0.6) : AppColors.textDisabled;
    final btnBg = widget.glassMode
        ? AppColors.white.withOpacity(0.25)
        : (isPersonalMode ? Colors.transparent : AppColors.accent);
    final btnFg = widget.glassMode
        ? AppColors.white
        : (isPersonalMode ? AppColors.textDisabled : AppColors.onAccent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 타이틀
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 16,
                color: isPersonalMode
                    ? (widget.glassMode ? AppColors.white.withOpacity(0.5) : AppColors.textDisabled)
                    : subtitleColor,
              ),
              const SizedBox(width: 6),
              Text(
                '털어놔',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '여기선 괜찮아',
                style: TextStyle(fontSize: 11, color: subtitleColor),
              ),
              const Spacer(),
              TextButton(
                onPressed: isPersonalMode ? null : widget.onOpenWrite,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: btnBg,
                  foregroundColor: btnFg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
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
        ),
        const SizedBox(height: 12),

        // 게시물 피드
        StreamBuilder<QuerySnapshot>(
          stream: _stream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snap.hasError) {
              debugPrint('⚠️ [BondFeedSection] 에러: ${snap.error}');
              return AppMutedCard(
                radius: AppRadius.md,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '데이터 조회 오류',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snap.error}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              );
            }

            if (!_hasPartnerGroup) {
              // 매칭 중이면 로딩 카드, 아니면 매칭하기 버튼
              if (widget.isMatching) {
                return _buildMatchingLoadingCard();
              }
              return _buildEmptyState(
                icon: Icons.group_outlined,
                text: '파트너와 함께할 때만\n기록할 수 있어요',
                subtitle: '매칭하기',
                onTap: widget.onFindPartnerTap,
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

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                children: [
                  ...docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return BondPostCard(
                      key: ValueKey(doc.id),
                      post: data,
                      postId: doc.id,
                      bondGroupId: widget.partnerGroupId,
                      memberNicknames: widget.memberNicknames,
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// 매칭 처리 중 로딩 카드
  Widget _buildMatchingLoadingCard() {
    return SizedBox(
      width: double.infinity,
      child: AppMutedCard(
        radius: AppRadius.xl,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: const Column(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.accent,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '파트너를 연결하고 있어요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '잠시만 기다려주세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textDisabled,
              ),
            ),
          ],
        ),
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
    final iconColor = widget.glassMode
        ? AppColors.white.withOpacity(0.6)
        : AppColors.textDisabled;
    final textColor = widget.glassMode
        ? AppColors.white.withOpacity(0.85)
        : AppColors.textSecondary;

    if (isPersonalMode) {
      // 개인 모드 — 글래스 or Muted
      final content = Column(
        children: [
          Icon(icon, size: 40, color: iconColor),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: textColor, height: 1.4),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: widget.glassMode
                    ? AppColors.white.withOpacity(0.25)
                    : (widget.isMatching
                        ? AppColors.accent.withOpacity(0.5)
                        : AppColors.accent),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: widget.isMatching
                  ? const SizedBox(
                      width: 80,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            '매칭 설정 중',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: widget.glassMode
                            ? AppColors.white
                            : AppColors.onAccent,
                      ),
                    ),
            ),
          ],
        ],
      );

      if (widget.glassMode) {
        return SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: onTap,
            child: GlassCard(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: content,
            ),
          ),
        );
      }

      return SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: onTap,
          child: AppMutedCard(
            radius: AppRadius.xl,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: content,
          ),
        ),
      );
    }

    // 파트너 있음 - 빈 피드 카드 (AppMutedCard 스타일로 통일)
    final partnerContent = Column(
      children: [
        Icon(icon, size: 40,
            color: widget.glassMode
                ? AppColors.white.withOpacity(0.7)
                : AppColors.textDisabled),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: widget.glassMode ? AppColors.white : AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );

    if (widget.glassMode) {
      return SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: onTap,
          child: GlassCard(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: partnerContent,
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onTap,
        child: AppMutedCard(
          radius: AppRadius.xl,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: partnerContent,
        ),
      ),
    );
  }
}
