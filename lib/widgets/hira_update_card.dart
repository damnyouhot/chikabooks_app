import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/hira_update.dart';
import '../services/hira_update_service.dart';

// ── 디자인 팔레트 (성장 탭과 통일) ──
const _kText = Color(0xFF5D6B6B);
const _kShadow1 = Color(0xFFDDD3D8);
const _kShadow2 = Color(0xFFD5E5E5);
const _kCardBg = Colors.white;
const _kHighRed = Color(0xFFE57373);
const _kMidOrange = Color(0xFFFFB74D);
const _kLowGray = Color(0xFFBDBDBD);

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
          // 상단: 배지 + 제목
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImpactBadge(),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
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

          // 하단: 원문 보기 + 저장 버튼
          Row(
            children: [
              Expanded(
                child: _buildLinkButton(context),
              ),
              const SizedBox(width: 8),
              _buildSaveButton(context),
            ],
          ),
        ],
      ),
    );
  }

  /// 치과 영향도 배지
  Widget _buildImpactBadge() {
    Color badgeColor;
    String badgeText;

    switch (update.impactLevel) {
      case 'HIGH':
        badgeColor = _kHighRed;
        badgeText = '높음';
        break;
      case 'MID':
        badgeColor = _kMidOrange;
        badgeText = '보통';
        break;
      default:
        badgeColor = _kLowGray;
        badgeText = '낮음';
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              children: [
                Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  size: 16,
                  color: _kText.withOpacity(0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  isSaved ? '저장됨' : '저장',
                  style: TextStyle(
                    fontSize: 13,
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

  /// 원문 링크 열기
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
}

