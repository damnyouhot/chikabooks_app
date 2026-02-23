import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/job.dart';
import '../../notifiers/job_filter_notifier.dart';
import '../../services/job_service.dart';
import '../../widgets/job_card.dart';
import '../../widgets/job/compact_filter_row.dart';
import '../../widgets/job/filter_bottom_sheet.dart';

// ── 디자인 팔레트 ──
const _kText = Color(0xFF5D6B6B);

class JobListScreen extends StatelessWidget {
  final LatLng? userLocation; // ★ 사용자 위치 추가

  const JobListScreen({super.key, this.userLocation});

  @override
  Widget build(BuildContext context) {
    final jobFilter = context.watch<JobFilterNotifier>();
    final jobService = context.read<JobService>();

    // 활성 필터 수 계산
    int activeFilterCount = 0;
    if (jobFilter.positionFilter != '전체') activeFilterCount++;
    if (jobFilter.careerFilter != '전체') activeFilterCount++;
    if (jobFilter.regionFilter != '전체') activeFilterCount++;
    if (jobFilter.salaryRange.start > 0 || jobFilter.salaryRange.end < 10000) {
      activeFilterCount++;
    }
    activeFilterCount += jobFilter.conditions.length;

    return Column(
      children: [
        // ★ CompactFilterRow (1줄)
        CompactFilterRow(
          searchQuery: jobFilter.searchQuery,
          onSearchChanged: jobFilter.setSearchQuery,
          onFilterPressed: () {
            FilterBottomSheet.show(context, jobFilter);
          },
          sortBy: jobFilter.sortBy,
          onSortChanged: jobFilter.setSortBy,
          activeFilterCount: activeFilterCount,
        ),

        // 공고 목록
        Expanded(
          child: FutureBuilder<List<Job>>(
            key: ValueKey(
              "${jobFilter.careerFilter}_${jobFilter.regionFilter}_${jobFilter.salaryRange}_${jobFilter.positionFilter}",
            ),
            future: jobService.fetchJobs(
              careerFilter: jobFilter.careerFilter,
              regionFilter: jobFilter.regionFilter,
              salaryRange: jobFilter.salaryRange,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    '오류 발생: ${snapshot.error}',
                    style: TextStyle(
                      fontSize: 14,
                      color: _kText.withOpacity(0.6),
                    ),
                  ),
                );
              }

              List<Job> jobs = snapshot.data ?? [];

              // 클라이언트 사이드 필터링 (검색어, 직종)
              if (jobFilter.searchQuery.isNotEmpty) {
                jobs =
                    jobs.where((job) {
                      final query = jobFilter.searchQuery.toLowerCase();
                      return job.clinicName.toLowerCase().contains(query) ||
                          job.address.toLowerCase().contains(query);
                    }).toList();
              }

              if (jobFilter.positionFilter != '전체') {
                jobs =
                    jobs
                        .where((job) => job.type == jobFilter.positionFilter)
                        .toList();
              }

              // 정렬
              if (jobFilter.sortBy == '거리순' && userLocation != null) {
                // ★ 거리순 정렬 (사용자 위치 기준)
                jobs.sort((a, b) {
                  final distA = jobService.calculateDistance(
                    userLocation!,
                    LatLng(a.lat, a.lng),
                  );
                  final distB = jobService.calculateDistance(
                    userLocation!,
                    LatLng(b.lat, b.lng),
                  );
                  return distA.compareTo(distB);
                });
              } else if (jobFilter.sortBy == '최신순') {
                jobs.sort((a, b) => b.postedAt.compareTo(a.postedAt));
              } else if (jobFilter.sortBy == '급여순') {
                jobs.sort(
                  (a, b) => b.salaryRange.last.compareTo(a.salaryRange.last),
                );
              }

              if (jobs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: _kText.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '조건에 맞는 공고가 없습니다.',
                        style: TextStyle(
                          fontSize: 14,
                          color: _kText.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '필터를 조정해보세요.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _kText.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80, top: 8),
                itemCount: jobs.length,
                itemBuilder: (_, i) => JobCard(job: jobs[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}
