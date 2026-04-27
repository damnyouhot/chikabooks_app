import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_muted_button.dart';
import '../core/widgets/app_badge.dart';
import '../models/hira_update.dart';
import '../services/hira_update_service.dart';
import 'hira_comment_sheet.dart';
import 'hira_web_view_sheet.dart';

/// HIRA 업데이트 상세 BottomSheet
///
/// 원칙:
///   - boxShadow 없음 / Border 없음
///   - 배경: AppColors.appBg
///   - 버튼: AppMutedButton
///   - 임팩트 뱃지: AppStatusBadge
class HiraUpdateDetailSheet extends StatelessWidget {
  final HiraUpdate update;

  const HiraUpdateDetailSheet({super.key, required this.update});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.appBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 임팩트 뱃지 + 제목
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppStatusBadge(
                        badgeLevel: _impactToLevel(update.impactLevel),
                        badgeText: _impactToText(update.impactLevel),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          update.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // 날짜 + 시행일 배지
                  Row(
                    children: [
                      Text(
                        DateFormat(
                          'yyyy년 MM월 dd일 발표',
                        ).format(update.publishedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary.withValues(alpha: 0.45),
                        ),
                      ),
                      if (update.effectiveDate != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        AppStatusBadge(
                          badgeLevel: update.getBadgeLevel(),
                          badgeText: update.getBadgeText(),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // 본문
                  if (update.body.isNotEmpty) ...[
                    Text(
                      '본문 요약',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(
                        update.body,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  // 업무 영향 체크
                  if (update.actionHints.isNotEmpty) ...[
                    Text(
                      '업무 영향 체크',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...update.actionHints.map(
                      (hint) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 16,
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.45,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                hint,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary.withValues(
                                    alpha: 0.65,
                                  ),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  // 버튼 행: 원문 보기 + 저장
                  Row(
                    children: [
                      Expanded(
                        child: AppMutedButton(
                          icon: Icons.open_in_new,
                          label: '원문 보기',
                          fontWeight: FontWeight.w700,
                          onTap:
                              () => HiraWebViewSheet.show(
                                context,
                                url: update.link,
                                title: update.title,
                              ),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: _SaveButton(update: update)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 댓글 버튼 (전체 너비)
                  SizedBox(
                    width: double.infinity,
                    child: AppMutedButton(
                      icon: Icons.mode_comment_outlined,
                      label:
                          update.commentCount > 0
                              ? '댓글 ${update.commentCount}개'
                              : '댓글 쓰기',
                      fontWeight: FontWeight.w700,
                      onTap: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => HiraCommentSheet(update: update),
                        );
                      },
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            children: [
              const Text(
                '상세 정보',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(
                  Icons.close,
                  size: 22,
                  color: AppColors.textPrimary.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
      ],
    );
  }

  /// impactLevel → AppStatusBadge badgeLevel 매핑
  String _impactToLevel(String impactLevel) {
    switch (impactLevel) {
      case 'HIGH':
        return 'ACTIVE';
      case 'MID':
        return 'SOON';
      default:
        return 'NOTICE';
    }
  }

  /// impactLevel → 표시 텍스트
  String _impactToText(String impactLevel) {
    switch (impactLevel) {
      case 'HIGH':
        return '중요';
      case 'MID':
        return '보통';
      default:
        return '참고만';
    }
  }
}

// ── 저장 버튼 (StreamBuilder 분리) ──────────────────────────

class _SaveButton extends StatelessWidget {
  final HiraUpdate update;
  const _SaveButton({required this.update});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: HiraUpdateService.watchSaved(update.id),
      builder: (context, snapshot) {
        final isSaved = snapshot.data ?? false;
        return AppMutedButton(
          icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
          label: isSaved ? '저장됨' : '저장',
          isActive: isSaved,
          activeColor: AppColors.accent.withValues(alpha: 0.12),
          fontWeight: FontWeight.w700,
          onTap: () => _toggleSave(context, isSaved),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        );
      },
    );
  }

  Future<void> _toggleSave(BuildContext context, bool currentlySaved) async {
    final success =
        currentlySaved
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
