import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart' show AppRadius;
import '../providers/me_providers.dart';

/// 헤더에 표시되는 "보기 기준 (지점 필터)" 셀렉터
///
/// 노출 정책 (옵션 A):
///  - 지점 0개: "지점 등록 필요" 안내 (탭 시 /me/clinic 으로)
///  - 지점 1개: **렌더링하지 않음** (빈 위젯) — 활성 지점 개념이 무의미하기 때문
///  - 지점 2개+: "보기 기준:" 라벨 + 드롭다운
///        · 첫 항목: "전체 지점 합산" (= meActiveBranchProvider 값을 null 로)
///        · 그 외 : 각 지점
///
/// 이 값은 `/me/overview` 와 `/me/applicants` 두 화면의 데이터 필터링에
/// 사용된다 (다른 화면에는 영향 없음).
class MeBranchSwitcher extends ConsumerWidget {
  const MeBranchSwitcher({super.key});

  /// 드롭다운에서 "전체 합산" 선택을 표현하기 위한 sentinel.
  /// (DropdownButton 의 value 가 null 이면 placeholder 가 떠 의도와 다르므로
  ///  명시적인 sentinel 문자열을 사용한다.)
  static const String _kAllBranches = '__ALL__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfiles = ref.watch(clinicProfilesProvider);

    return asyncProfiles.when(
      loading: () => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      ),
      error: (_, __) => _Pill(
        icon: Icons.error_outline,
        label: '불러오기 실패',
        color: AppColors.error,
      ),
      data: (profiles) {
        if (profiles.isEmpty) {
          return _Pill(
            icon: Icons.add_business_outlined,
            label: '지점 등록 필요',
            color: AppColors.warning,
          );
        }
        // 1지점 운영자에게는 의미 없는 셀렉터 — 헤더에서 완전히 숨긴다.
        if (profiles.length == 1) {
          return const SizedBox.shrink();
        }

        final activeId = ref.watch(meActiveBranchProvider);
        // 사용자가 명시적으로 고른 지점이 더 이상 존재하지 않으면 "전체"로 폴백.
        // (이전 구현은 첫 지점으로 자동 보정했지만, 옵션 A 정책상 다지점의 기본은
        //  '전체 합산' 이다.)
        final selectedDropdownValue =
            activeId != null && profiles.any((p) => p.id == activeId)
                ? activeId
                : _kAllBranches;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '보기 기준:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.divider),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedDropdownValue,
                  isDense: true,
                  icon: const Icon(Icons.expand_more,
                      size: 18, color: AppColors.textSecondary),
                  items: [
                    DropdownMenuItem(
                      value: _kAllBranches,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.all_inclusive,
                              size: 14, color: AppColors.accent),
                          SizedBox(width: 6),
                          Text(
                            '전체 지점 합산',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final p in profiles)
                      DropdownMenuItem(
                        value: p.id,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_hospital_outlined,
                                size: 14, color: AppColors.accent),
                            const SizedBox(width: 6),
                            Text(
                              p.effectiveName.isEmpty
                                  ? '(이름 없음)'
                                  : p.effectiveName,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    final newId = value == _kAllBranches ? null : value;
                    ref.read(meActiveBranchProvider.notifier).set(newId);
                  },
                ),
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message:
                  '선택한 지점 기준으로 "한눈에 보기"의 KPI/할 일과 "인재풀"의 지원자 목록이 필터링됩니다.\n'
                  '"전체 지점 합산"을 고르면 모든 지점의 데이터를 합쳐서 보여줍니다.',
              waitDuration: const Duration(milliseconds: 300),
              child: const Icon(
                Icons.help_outline,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
