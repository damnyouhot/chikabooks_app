import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../models/job.dart';
import '../../../../services/job_service.dart';
import '../services/job_lookup_cache.dart';
import '../widgets/applicant_web_shell.dart';
import '../widgets/job_image.dart';

/// `/me/bookmarks` — 찜한 공고 목록.
///
/// 백엔드는 기존 `users/{uid}.bookmarkedJobs` 배열 사용.
/// 공고 상세의 [_BookmarkToggleButton] 으로 추가/해제하며,
/// 본 페이지에서도 각 카드의 ✕ 버튼으로 즉시 해제할 수 있다.
class ApplicantBookmarksPage extends StatefulWidget {
  const ApplicantBookmarksPage({super.key});

  @override
  State<ApplicantBookmarksPage> createState() => _ApplicantBookmarksPageState();
}

class _ApplicantBookmarksPageState extends State<ApplicantBookmarksPage> {
  final JobLookupCache _cache = JobLookupCache();
  final JobService _svc = JobService();

  @override
  void dispose() {
    _cache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ApplicantWebShell(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PageHeader(),
          const SizedBox(height: 20),
          StreamBuilder<List<String>>(
            stream: _svc.watchBookmarkedJobIds(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final ids = snap.data ?? const <String>[];
              if (ids.isEmpty) {
                return const _EmptyState();
              }
              _cache.preload(ids);
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius:
                      BorderRadius.circular(AppApplicant.cardRadius),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < ids.length; i++) ...[
                      _BookmarkRow(
                        jobId: ids[i],
                        cache: _cache,
                        svc: _svc,
                      ),
                      if (i < ids.length - 1)
                        const Divider(height: 1, color: AppColors.divider),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '찜한 공고',
            style: GoogleFonts.notoSansKr(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '관심 가는 공고를 모아두고, 마감 전에 다시 확인하세요.',
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppApplicant.cardRadius),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(
            Icons.bookmark_outline_rounded,
            size: 44,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: 12),
          Text(
            '아직 찜한 공고가 없어요.',
            style: GoogleFonts.notoSansKr(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '공고 상세 페이지의 "찜하기" 버튼을 눌러 저장해 보세요.',
            style: GoogleFonts.notoSansKr(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.search_rounded, size: 18),
            label: Text(
              '공고 둘러보기',
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: BorderSide(
                color: AppColors.accent.withValues(alpha: 0.4),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookmarkRow extends StatelessWidget {
  const _BookmarkRow({
    required this.jobId,
    required this.cache,
    required this.svc,
  });
  final String jobId;
  final JobLookupCache cache;
  final JobService svc;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Job?>(
      future: cache.get(jobId),
      builder: (context, snap) {
        final job = snap.data;
        // JobLookupCache 는 Firestore 에서 못 찾으면 빈 Job 을 fallback 으로
        // 돌려준다. 즉 title 이 비어 있으면 공고가 삭제(또는 권한 차단)된 상태.
        // 로딩 중과 구분하기 위해 connectionState 도 확인한다.
        final isLoading = snap.connectionState == ConnectionState.waiting;
        final isMissing =
            !isLoading && (job == null || job.title.trim().isEmpty);

        return InkWell(
          // 삭제된 공고는 상세로 가도 빈 화면이라 탭 자체를 막는다.
          onTap: isMissing ? null : () => context.push('/jobs/$jobId'),
          child: Opacity(
            opacity: isMissing ? 0.55 : 1.0,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: _thumbnail(job, isMissing: isMissing),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildText(
                      job: job,
                      isLoading: isLoading,
                      isMissing: isMissing,
                    ),
                  ),
                  IconButton(
                    tooltip: isMissing ? '목록에서 제거' : '찜 해제',
                    onPressed: () => _onRemove(context),
                    icon: Icon(
                      isMissing
                          ? Icons.close_rounded
                          : Icons.bookmark_remove_outlined,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildText({
    required Job? job,
    required bool isLoading,
    required bool isMissing,
  }) {
    if (isLoading) {
      return Text(
        '공고 정보 불러오는 중…',
        style: GoogleFonts.notoSansKr(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      );
    }
    if (isMissing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '삭제된 공고예요',
            style: GoogleFonts.notoSansKr(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '공고가 마감되었거나 더 이상 볼 수 없어요. 우측 ✕ 로 정리할 수 있어요.',
            style: GoogleFonts.notoSansKr(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          job!.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.notoSansKr(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          [
            if (job.clinicName.trim().isNotEmpty) job.displayClinicName,
            _districtOrAddress(job),
          ].where((s) => s.isNotEmpty).join('  ·  '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.notoSansKr(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        if (job.salaryDisplayLine.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            job.salaryDisplayLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.notoSansKr(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _onRemove(BuildContext context) async {
    try {
      await svc.unbookmarkJob(jobId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('목록에서 제거했어요.'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('처리 중 오류: $e')),
      );
    }
  }

  Widget _thumbnail(Job? job, {required bool isMissing}) {
    if (isMissing) {
      // 삭제된 공고는 회색 placeholder + 작은 ✕ 아이콘으로 명확히 구분.
      return Container(
        color: AppColors.surfaceMuted,
        child: const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.textDisabled,
            size: 24,
          ),
        ),
      );
    }
    final src = job?.images.isNotEmpty == true ? job!.images.first : null;
    if (src == null || src.isEmpty) {
      return JobThumbImage.placeholder(iconSize: 28);
    }
    return JobThumbImage(src: src, iconSize: 28);
  }

  String _districtOrAddress(Job job) {
    if (job.district.trim().isNotEmpty) return job.district.trim();
    if (job.address.trim().isNotEmpty) return job.address.trim();
    return '';
  }
}
