import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/hira_update.dart';
import '../services/hira_update_service.dart';
import 'hira_comment_sheet.dart';

// ── 디자인 팔레트 (성장 탭과 통일) ──
const _kText = Color(0xFF5D6B6B);
const _kShadow1 = Color(0xFFDDD3D8);
const _kShadow2 = Color(0xFFD5E5E5);
const _kCardBg = Colors.white;
const _kActiveRed = Color(0xFFE57373); // 🔴 시행 중
const _kSoonOrange = Color(0xFFFFB74D); // 🟠 30일 이내
const _kUpcomingYellow = Color(0xFFFDD835); // 🟡 90일 이내
const _kNoticeGray = Color(0xFFBDBDBD); // ⚪ 사전공지

/// HIRA 업데이트 카드
class HiraUpdateCard extends StatelessWidget {
  final HiraUpdate update;

  const HiraUpdateCard({
    super.key,
    required this.update,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _kShadow2.withOpacity(0.5),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _kShadow1.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 배지 + 제목 + 날짜
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImpactBadge(),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      update.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kText,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(update.publishedAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: _kText.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 업무 영향 체크 (actionHints)
          ...update.actionHints.take(3).map((hint) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 14,
                      color: _kText.withOpacity(0.5),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hint,
                        style: TextStyle(
                          fontSize: 12,
                          color: _kText.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              )),

          const SizedBox(height: 12),

          // 하단: 원문 보기 + 저장 + 댓글 버튼
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildLinkButton(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSaveButton(context),
              ),
              const SizedBox(width: 8),
              _buildCommentButton(context),
            ],
          ),
        ],
      ),
    );
  }

  /// 시행일 기준 배지
  Widget _buildImpactBadge() {
    final badgeLevel = update.getBadgeLevel();
    final badgeText = update.getBadgeText();
    
    Color badgeColor;
    switch (badgeLevel) {
      case 'ACTIVE':
        badgeColor = _kActiveRed; // 🔴 시행 중
        break;
      case 'SOON':
        badgeColor = _kSoonOrange; // 🟠 30일 이내
        break;
      case 'UPCOMING':
        badgeColor = _kUpcomingYellow; // 🟡 90일 이내
        break;
      default:
        badgeColor = _kNoticeGray; // ⚪ 사전공지
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: badgeColor.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
      ),
    );
  }

  /// 원문 보기 버튼
  Widget _buildLinkButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _openLink(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _kShadow2.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _kShadow2.withOpacity(0.5),
            width: 0.5,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.open_in_new,
                size: 14,
                color: _kText.withOpacity(0.6),
              ),
              const SizedBox(width: 4),
              Text(
                '원문 보기',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _kText.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 저장 버튼 (StreamBuilder로 실시간 상태 반영)
  Widget _buildSaveButton(BuildContext context) {
    return StreamBuilder<bool>(
      stream: HiraUpdateService.watchSaved(update.id),
      builder: (context, snapshot) {
        final isSaved = snapshot.data ?? false;

        return GestureDetector(
          onTap: () => _toggleSave(context, isSaved),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSaved
                  ? const Color(0xFFF7CBCA).withOpacity(0.3)
                  : _kShadow2.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSaved
                    ? const Color(0xFFF7CBCA).withOpacity(0.5)
                    : _kShadow2.withOpacity(0.5),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  size: 14,
                  color: _kText.withOpacity(0.6),
                ),
                const SizedBox(width: 3),
                Text(
                  isSaved ? '저장됨' : '저장',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _kText.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 댓글 버튼
  Widget _buildCommentButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _openCommentSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _kShadow2.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _kShadow2.withOpacity(0.5),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mode_comment_outlined,
              size: 14,
              color: _kText.withOpacity(0.6),
            ),
            if (update.commentCount > 0) ...[
              const SizedBox(width: 3),
              Text(
                '${update.commentCount}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kText.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 원문 링크 열기
  Future<void> _openLink(BuildContext context) async {
    try {
      debugPrint('🔗 Opening URL: ${update.link}');
      final uri = Uri.parse(update.link);
      
      final canLaunch = await canLaunchUrl(uri);
      debugPrint('🔗 canLaunchUrl: $canLaunch');
      
      if (canLaunch) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        debugPrint('🔗 launchUrl result: $launched');
        
        if (!launched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('브라우저를 열 수 없습니다')),
          );
        }
      } else {
        debugPrint('⚠️ Cannot launch URL: ${update.link}');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('링크를 열 수 없습니다')),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ URL launch error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    }
  }

  /// 저장 토글
  Future<void> _toggleSave(BuildContext context, bool currentlySaved) async {
    final success = currentlySaved
        ? await HiraUpdateService.unsaveUpdate(update.id)
        : await HiraUpdateService.saveUpdate(update);

    if (context.mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentlySaved ? '저장이 취소되었습니다' : '저장되었습니다'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// 댓글 BottomSheet 열기
  void _openCommentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HiraCommentSheet(update: update),
    );
  }

  /// 날짜 포맷
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '오늘 ${DateFormat('HH:mm').format(date)}';
    } else if (diff.inDays == 1) {
      return '어제 ${DateFormat('HH:mm').format(date)}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}일 전';
    } else {
      return DateFormat('yyyy.MM.dd').format(date);
    }
  }
}

