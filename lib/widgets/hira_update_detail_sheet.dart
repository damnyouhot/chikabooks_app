import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/hira_update.dart';
import '../services/hira_update_service.dart';
import 'hira_comment_sheet.dart';

// ── 디자인 팔레트 ──
const _kText = Color(0xFF5D6B6B);
const _kBg = Color(0xFFF1F7F7);
const _kShadow2 = Color(0xFFD5E5E5);
const _kHighRed = Color(0xFFE57373);
const _kMidOrange = Color(0xFFFFB74D);
const _kLowGray = Color(0xFFBDBDBD);

/// HIRA 업데이트 상세 BottomSheet
class HiraUpdateDetailSheet extends StatelessWidget {
  final HiraUpdate update;

  const HiraUpdateDetailSheet({super.key, required this.update});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 헤더
          _buildHeader(context),
          
          // 내용
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 배지 + 제목
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImpactBadge(),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          update.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _kText,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // 날짜
                  Text(
                    DateFormat('yyyy년 MM월 dd일 발표').format(update.publishedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: _kText.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // 업무 영향
                  if (update.actionHints.isNotEmpty) ...[
                    Text(
                      '업무 영향 체크',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kText.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...update.actionHints.map((hint) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 16,
                                color: _kText.withOpacity(0.5),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  hint,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _kText.withOpacity(0.7),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 20),
                  ],
                  
                  // 버튼들
                  Row(
                    children: [
                      Expanded(
                        child: _buildLinkButton(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSaveButton(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildCommentButton(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _kShadow2.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          const Text(
            '상세 정보',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _kText,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(
              Icons.close,
              size: 22,
              color: _kText.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactBadge() {
    Color badgeColor;
    String badgeText;

    switch (update.impactLevel) {
      case 'HIGH':
        badgeColor = _kHighRed;
        badgeText = '중요';
        break;
      case 'MID':
        badgeColor = _kMidOrange;
        badgeText = '보통';
        break;
      default:
        badgeColor = _kLowGray;
        badgeText = '참고만';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
      ),
    );
  }

  Widget _buildLinkButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _openLink(context),
      icon: const Icon(Icons.open_in_new, size: 16),
      label: const Text('원문 보기'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _kShadow2.withOpacity(0.3),
        foregroundColor: _kText.withOpacity(0.7),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: _kShadow2.withOpacity(0.5)),
        ),
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return StreamBuilder<bool>(
      stream: HiraUpdateService.watchSaved(update.id),
      builder: (context, snapshot) {
        final isSaved = snapshot.data ?? false;
        return ElevatedButton.icon(
          onPressed: () => _toggleSave(context, isSaved),
          icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border, size: 16),
          label: Text(isSaved ? '저장됨' : '저장'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSaved
                ? const Color(0xFFF7CBCA).withOpacity(0.3)
                : _kShadow2.withOpacity(0.3),
            foregroundColor: _kText.withOpacity(0.7),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isSaved
                    ? const Color(0xFFF7CBCA).withOpacity(0.5)
                    : _kShadow2.withOpacity(0.5),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pop(context);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => HiraCommentSheet(update: update),
          );
        },
        icon: const Icon(Icons.mode_comment_outlined, size: 16),
        label: Text(
          update.commentCount > 0 ? '댓글 ${update.commentCount}개' : '댓글 쓰기',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kShadow2.withOpacity(0.3),
          foregroundColor: _kText.withOpacity(0.7),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: _kShadow2.withOpacity(0.5)),
          ),
        ),
      ),
    );
  }

  Future<void> _openLink(BuildContext context) async {
    try {
      final uri = Uri.parse(update.link);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('링크를 열 수 없습니다')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    }
  }

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
}

