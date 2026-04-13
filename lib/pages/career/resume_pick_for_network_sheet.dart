import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/resume.dart';

/// 경력이 있는 이력서가 1건 이상이면 항상 시트를 띄워 사용자가 확정하게 함.
///
/// [preferredResumeId]: [ResumeService.markLastImportedResume]로 저장된 이력서 — 목록 상단·배지
Future<Resume?> showResumePickerForNetworkExport(
  BuildContext context,
  List<Resume> resumesWithCareer, {
  String? preferredResumeId,
}) async {
  if (resumesWithCareer.isEmpty) return null;

  return showModalBottomSheet<Resume>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:
        (ctx) => _ResumePickerSheet(
          resumes: resumesWithCareer,
          preferredResumeId: preferredResumeId,
        ),
  );
}

class _ResumePickerSheet extends StatelessWidget {
  final List<Resume> resumes;
  final String? preferredResumeId;

  const _ResumePickerSheet({
    required this.resumes,
    this.preferredResumeId,
  });

  static String _subtitle(Resume r) {
    final n = r.experiences
        .where((e) => e.clinicName.trim().isNotEmpty)
        .length;
    final dateStr =
        r.updatedAt != null
            ? DateFormat('yyyy.MM.dd').format(r.updatedAt!)
            : '날짜 없음';
    return '경력 $n건 · 최종 수정 $dateStr';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      margin: const EdgeInsets.only(top: 80),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.disabledBg,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '이력서 선택',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '치과 히스토리에 반영할 이력서를 고르세요. '
                '최근 AI로 불러온 이력서가 있으면 맨 위에 표시됩니다.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg + bottom,
              ),
              itemCount: resumes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = resumes[i];
                final isPreferred =
                    preferredResumeId != null && r.id == preferredResumeId;
                return Material(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    onTap: () => Navigator.of(context).pop(r),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  r.title.trim().isEmpty
                                      ? Resume.kDefaultResumeTitle
                                      : r.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (isPreferred) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.sm,
                                    ),
                                  ),
                                  child: const Text(
                                    '최근 AI 불러오기',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _subtitle(r),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
