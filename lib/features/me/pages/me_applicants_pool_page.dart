import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart' show AppRadius, AppSpacing;
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../models/applicant_pool_entry.dart';
import '../../../services/applicant_pool_service.dart';
import '../../jobs/web/web_typography.dart';
import '../providers/me_providers.dart';
import '../widgets/me_page_shell.dart';
import 'widgets/applicant_resume_dialog.dart';
import 'widgets/edit_pool_meta_dialog.dart';
import 'widgets/notify_past_applicants_dialog.dart';

/// 합산 모드에서 같은 applicantUid 가 여러 지점에 동시에 노출될 수 있으므로,
/// 선택 키는 (uid + branchId) 조합으로 만든다.
String _selectionKey(JoinedApplicant a) => '${a.applicantUid}::${a.branchId}';

/// /me/applicants — 인재풀 페이지
///
/// 정책:
///  1. **지점별 분리** — 우상단 지점 스위처(`MeBranchSwitcher`) 따라 자동 갱신
///  2. **수동 등록** — 운영자가 ⭐ 누른 사람만 풀에 들어옴
///                    (그 전엔 지원이력만 있음 → "풀 추가" 버튼 노출)
///  3. **이메일 재알림** — 풀 안에서 다중 선택 → "신규 공고로 재알림"
///                       → Cloud Function 이 이메일 큐에 적재
class MeApplicantsPoolPage extends ConsumerStatefulWidget {
  const MeApplicantsPoolPage({super.key});

  @override
  ConsumerState<MeApplicantsPoolPage> createState() =>
      _MeApplicantsPoolPageState();
}

class _MeApplicantsPoolPageState extends ConsumerState<MeApplicantsPoolPage> {
  String _search = '';
  String _filter = 'all'; // all | favorite | pool | history
  String? _statusFilter; // null = all

  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final branchId = ref.watch(meActiveBranchProvider);
    final asyncApplicants = ref.watch(applicantPoolProvider(branchId));
    final asyncProfiles = ref.watch(clinicProfilesProvider);

    // branchId 가 null 이면 "전체 지점 합산" 모드.
    // 단, 프로필이 1개뿐이면 합산해봐야 그 지점뿐이므로 합산 안내는 숨긴다.
    final profileCount = asyncProfiles.maybeWhen(
      data: (l) => l.length,
      orElse: () => 0,
    );
    final isAggregated = branchId == null && profileCount > 1;

    // 카드에 표시할 지점명 lookup (합산 모드에서만 의미 있음)
    final branchNameById = <String, String>{};
    asyncProfiles.whenData((profiles) {
      for (final p in profiles) {
        branchNameById[p.id] =
            p.effectiveName.isEmpty ? '(이름 없음)' : p.effectiveName;
      }
    });

    return MePageShell(
      title: '인재풀',
      activeMenuId: 'applicants',
      child: asyncApplicants.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (error, _) => _ErrorBox(message: '$error'),
        data: (all) {
          final filtered = _applyFilter(all);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                total: all.length,
                favorites: all.where((a) => a.isFavorite).length,
                inPool: all.where((a) => a.isInPool).length,
                historyOnly: all.where((a) => !a.isInPool).length,
                isAggregated: isAggregated,
              ),
              const SizedBox(height: AppSpacing.xxl),
              _Toolbar(
                search: _search,
                onSearchChanged: (v) => setState(() => _search = v),
                filter: _filter,
                onFilterChanged: (v) => setState(() => _filter = v),
                statusFilter: _statusFilter,
                onStatusChanged: (v) =>
                    setState(() => _statusFilter = v),
                selectedCount: _selected.length,
                onClearSelection: () => setState(_selected.clear),
                onNotifySelected: _selected.isEmpty
                    ? null
                    : () => _openNotifyDialog(filtered),
                onExportCsv: filtered.isEmpty
                    ? null
                    : () => _exportCsv(filtered),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (filtered.isEmpty)
                _EmptyBox(filter: _filter)
              else
                ...filtered.map((a) {
                  final key = _selectionKey(a);
                  return Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _ApplicantCard(
                      data: a,
                      branchLabel:
                          isAggregated ? branchNameById[a.branchId] : null,
                      selected: _selected.contains(key),
                      onToggleSelect: () => setState(() {
                        if (_selected.contains(key)) {
                          _selected.remove(key);
                        } else {
                          _selected.add(key);
                        }
                      }),
                      onToggleFavorite: () => _toggleFavorite(a),
                      onEditMeta: () => _openEditMeta(a),
                      onViewResume: () => _openResume(a),
                      onRemoveFromPool: a.isInPool
                          ? () => _confirmRemove(a)
                          : null,
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  // ───────────────────────────────────────── filter
  List<JoinedApplicant> _applyFilter(List<JoinedApplicant> input) {
    Iterable<JoinedApplicant> out = input;

    switch (_filter) {
      case 'favorite':
        out = out.where((a) => a.isFavorite);
        break;
      case 'pool':
        out = out.where((a) => a.isInPool);
        break;
      case 'history':
        out = out.where((a) => !a.isInPool);
        break;
    }
    if (_statusFilter != null) {
      out = out.where((a) => a.status == _statusFilter);
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      out = out.where((a) {
        final name = a.displayName.toLowerCase();
        final tags = a.tags.join(',').toLowerCase();
        final memo = a.memo.toLowerCase();
        final uid = a.applicantUid.toLowerCase();
        final jobs = a.applications
            .map((j) => j.jobTitle ?? '')
            .join(',')
            .toLowerCase();
        return name.contains(q) ||
            tags.contains(q) ||
            memo.contains(q) ||
            uid.contains(q) ||
            jobs.contains(q);
      });
    }
    return out.toList();
  }

  // ───────────────────────────────────────── actions
  Future<void> _toggleFavorite(JoinedApplicant a) async {
    try {
      await ApplicantPoolService.setFavorite(
        applicantUid: a.applicantUid,
        value: !a.isFavorite,
        branchId: a.branchId,
        displayName: a.displayName,
        lastAppliedAt: a.lastAppliedAt,
        applicationIds: a.applications.map((e) => e.applicationId).toList(),
      );
    } catch (e) {
      if (mounted) _snack('처리 실패: $e');
    }
  }

  Future<void> _openEditMeta(JoinedApplicant a) async {
    final res = await showDialog<EditPoolMetaResult>(
      context: context,
      builder: (_) => EditPoolMetaDialog(initial: a),
    );
    if (res == null) return;
    try {
      await ApplicantPoolService.updateMeta(
        applicantUid: a.applicantUid,
        branchId: a.branchId,
        memo: res.memo,
        tags: res.tags,
        status: res.status,
        displayName: res.displayName,
      );
    } catch (e) {
      if (mounted) _snack('저장 실패: $e');
    }
  }

  Future<void> _openResume(JoinedApplicant a) async {
    final resumeId = a.applications.isNotEmpty
        ? a.applications.first.resumeId
        : '';
    await showDialog(
      context: context,
      builder: (_) => ApplicantResumeDialog(
        applicant: a,
        resumeId: resumeId,
      ),
    );
  }

  Future<void> _confirmRemove(JoinedApplicant a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AppConfirmModal(
            title: '풀에서 제거',
            message:
                '${a.displayName.isEmpty ? a.applicantUid : a.displayName} 님을 인재풀에서 제거할까요?\n\n'
                '지원 이력 자체는 그대로 남아있습니다.',
            confirmLabel: '제거',
            destructive: true,
          ),
    );
    if (ok != true) return;
    await ApplicantPoolService.removeFromPool(
      applicantUid: a.applicantUid,
      branchId: a.branchId,
    );
  }

  Future<void> _openNotifyDialog(List<JoinedApplicant> visible) async {
    final picked = visible
        .where((a) => _selected.contains(_selectionKey(a)))
        .toList();
    if (picked.isEmpty) return;

    // 합산 모드에서 여러 지점이 섞여 선택된 경우, 한 번의 callable 호출은
    // 단일 branchId 만 받으므로 잘못된 분기로 발송될 수 있다. 안전하게 차단.
    final branches = picked.map((e) => e.branchId).toSet();
    if (branches.length > 1) {
      _snack('여러 지점이 섞여 있어요. 같은 지점의 지원자들만 선택해 주세요.');
      return;
    }

    final result = await showDialog<NotifyPastResult>(
      context: context,
      builder: (_) => NotifyPastApplicantsDialog(applicants: picked),
    );
    if (result == null) return;
    try {
      final n = await ApplicantPoolService.notifyPastApplicants(
        applicantUids: picked.map((e) => e.applicantUid).toList(),
        jobId: result.jobId,
        message: result.message,
        branchId: picked.first.branchId,
      );
      if (mounted) {
        _snack('$n명에게 이메일 발송을 예약했어요.');
        setState(_selected.clear);
      }
    } catch (e) {
      if (mounted) _snack('발송 실패: $e');
    }
  }

  void _exportCsv(List<JoinedApplicant> rows) {
    final buf = StringBuffer();
    buf.writeln(
        'uid,이름,즐겨찾기,상태,태그,첫지원,마지막지원,지원수,지원공고,메모');
    for (final a in rows) {
      final fields = <String>[
        a.applicantUid,
        a.displayName,
        a.isFavorite ? 'Y' : 'N',
        kApplicantStatusLabels[a.status] ?? a.status,
        a.tags.join(' | '),
        _fmtCsvDate(a.firstSeenAt),
        _fmtCsvDate(a.lastAppliedAt),
        a.applications.length.toString(),
        a.applications
            .map((j) => j.jobTitle ?? j.jobId)
            .join(' | '),
        a.memo.replaceAll('\n', ' '),
      ];
      buf.writeln(fields.map(_csvEscape).join(','));
    }
    final csv = buf.toString();
    Clipboard.setData(ClipboardData(text: csv));
    _snack(
        'CSV 를 클립보드에 복사했어요. 엑셀/시트에 붙여 넣으세요. (${rows.length}행)');
  }

  String _fmtCsvDate(DateTime? d) {
    if (d == null) return '';
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$dd';
  }

  String _csvEscape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      final esc = s.replaceAll('"', '""');
      return '"$esc"';
    }
    return s;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 헤더 (KPI 박스)
// ──────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({
    required this.total,
    required this.favorites,
    required this.inPool,
    required this.historyOnly,
    required this.isAggregated,
  });

  final int total;
  final int favorites;
  final int inPool;
  final int historyOnly;

  /// "전체 지점 합산" 모드일 때 안내 배너를 띄운다.
  /// 같은 사람이 여러 지점에 지원했다면 지점별로 별도 row 로 잡히므로,
  /// total 이 "고유 사람 수"가 아니라 "지점별 row 수"임을 명시할 필요가 있다.
  final bool isAggregated;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAggregated) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.all_inclusive,
                      size: 14, color: AppColors.accent),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '전체 지점 합산 모드 — 지점이 다르면 같은 사람도 별개 카드로 표시됩니다.',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Kpi(
                  label: '전체',
                  value: '$total',
                  color: AppColors.textPrimary),
              _Kpi(
                  label: '⭐ 즐겨찾기',
                  value: '$favorites',
                  color: AppColors.warning),
              _Kpi(
                  label: '풀 등록',
                  value: '$inPool',
                  color: AppColors.accent),
              _Kpi(
                  label: '지원 이력만',
                  value: '$historyOnly',
                  color: AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border:
            Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color)),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 툴바 (검색, 필터칩, 일괄 액션)
// ──────────────────────────────────────────────────────────────
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.search,
    required this.onSearchChanged,
    required this.filter,
    required this.onFilterChanged,
    required this.statusFilter,
    required this.onStatusChanged,
    required this.selectedCount,
    required this.onClearSelection,
    required this.onNotifySelected,
    required this.onExportCsv,
  });

  final String search;
  final ValueChanged<String> onSearchChanged;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final String? statusFilter;
  final ValueChanged<String?> onStatusChanged;
  final int selectedCount;
  final VoidCallback onClearSelection;
  final VoidCallback? onNotifySelected;
  final VoidCallback? onExportCsv;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '이름·태그·메모·공고 검색',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.sm)),
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
              _filterChip('all', '전체'),
              _filterChip('favorite', '⭐'),
              _filterChip('pool', '풀 등록'),
              _filterChip('history', '이력만'),
              const VerticalDivider(width: 16),
              ..._statusChips(),
            ],
          ),
          if (selectedCount > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text('$selectedCount명 선택',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                          fontSize: 12)),
                ),
                TextButton(
                    onPressed: onClearSelection,
                    child: const Text('선택 해제')),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onNotifySelected,
                  icon: const Icon(Icons.email_outlined, size: 16),
                  label: const Text('이메일로 신규 공고 알림'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onExportCsv,
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('CSV'),
                ),
              ],
            ),
          ],
          if (selectedCount == 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onExportCsv,
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('CSV 내보내기'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterChip(String id, String label) {
    final selected = filter == id;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onFilterChanged(id),
      labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.textPrimary),
      selectedColor: AppColors.accent,
    );
  }

  List<Widget> _statusChips() {
    final out = <Widget>[
      ChoiceChip(
        label: const Text('상태 전체'),
        selected: statusFilter == null,
        onSelected: (_) => onStatusChanged(null),
        labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: statusFilter == null
                ? Colors.white
                : AppColors.textPrimary),
        selectedColor: AppColors.textPrimary,
      ),
    ];
    for (final s in kApplicantStatusOrder) {
      final selected = statusFilter == s;
      out.add(ChoiceChip(
        label: Text(kApplicantStatusLabels[s] ?? s),
        selected: selected,
        onSelected: (_) => onStatusChanged(s),
        labelStyle: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : AppColors.textSecondary),
        selectedColor: AppColors.accent,
      ));
    }
    return out;
  }
}

// ──────────────────────────────────────────────────────────────
// 카드
// ──────────────────────────────────────────────────────────────
class _ApplicantCard extends StatelessWidget {
  const _ApplicantCard({
    required this.data,
    required this.selected,
    required this.onToggleSelect,
    required this.onToggleFavorite,
    required this.onEditMeta,
    required this.onViewResume,
    required this.onRemoveFromPool,
    this.branchLabel,
  });

  final JoinedApplicant data;
  final bool selected;
  final VoidCallback onToggleSelect;
  final VoidCallback onToggleFavorite;
  final VoidCallback onEditMeta;
  final VoidCallback onViewResume;
  final VoidCallback? onRemoveFromPool;

  /// 합산 모드에서만 전달되는 지점 표시 라벨 (단일 지점 모드에서는 null).
  final String? branchLabel;

  @override
  Widget build(BuildContext context) {
    final name = data.displayName.isNotEmpty
        ? data.displayName
        : '지원자 #${data.applicantUid.substring(0, data.applicantUid.length.clamp(0, 6))}';
    final lastApplied = data.lastAppliedAt;
    final lastStr = lastApplied == null
        ? ''
        : '${lastApplied.year}.${lastApplied.month.toString().padLeft(2, '0')}.${lastApplied.day.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: selected
                ? AppColors.accent
                : AppColors.divider.withValues(alpha: 0.6),
            width: selected ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (_) => onToggleSelect(),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: Icon(
                  data.isFavorite ? Icons.star : Icons.star_border,
                  color: data.isFavorite
                      ? AppColors.warning
                      : AppColors.textSecondary,
                ),
                tooltip: data.isFavorite ? '⭐ 해제' : '⭐ 풀 등록',
                onPressed: onToggleFavorite,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(name,
                            style: WebTypo.sectionTitle(
                                color: AppColors.textPrimary)),
                        _statusBadge(data.status),
                        if (data.isInPool)
                          _pillBadge('풀', AppColors.accent),
                        if (branchLabel != null && branchLabel!.isNotEmpty)
                          _pillBadge('🏥 $branchLabel',
                              AppColors.textSecondary),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        '지원 ${data.applications.length}회',
                        if (lastStr.isNotEmpty) '마지막 $lastStr',
                      ].join(' · '),
                      style: WebTypo.caption(
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (v) {
                  if (v == 'edit') onEditMeta();
                  if (v == 'resume') onViewResume();
                  if (v == 'remove') onRemoveFromPool?.call();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('메모/태그/상태')),
                  const PopupMenuItem(value: 'resume', child: Text('이력서 보기')),
                  if (onRemoveFromPool != null)
                    const PopupMenuItem(
                        value: 'remove', child: Text('풀에서 제거')),
                ],
              ),
            ],
          ),
          if (data.tags.isNotEmpty || data.memo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 56, top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data.tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: data.tags
                          .map((t) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.accent
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(
                                      AppRadius.full),
                                ),
                                child: Text('#$t',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.accent)),
                              ))
                          .toList(),
                    ),
                  if (data.memo.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(data.memo,
                        style: WebTypo.caption(
                                color: AppColors.textSecondary)
                            .copyWith(height: 1.5)),
                  ],
                ],
              ),
            ),
          if (data.applications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 56, top: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: data.applications
                    .take(5)
                    .map((j) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.divider
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(
                                AppRadius.sm),
                          ),
                          child: Text(
                              j.jobTitle?.isNotEmpty == true
                                  ? j.jobTitle!
                                  : j.jobId,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusBadge(String s) {
    final label = kApplicantStatusLabels[s] ?? s;
    Color c = AppColors.textSecondary;
    if (s == 'hired') c = AppColors.success;
    if (s == 'interviewed') c = AppColors.accent;
    if (s == 'reviewing') c = AppColors.warning;
    if (s == 'rejected') c = AppColors.error;
    return _pillBadge(label, c);
  }

  Widget _pillBadge(String label, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800, color: c)),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({required this.filter});
  final String filter;

  @override
  Widget build(BuildContext context) {
    final msg = switch (filter) {
      'favorite' => '⭐ 즐겨찾기로 등록된 지원자가 없어요.',
      'pool' => '아직 풀에 등록된 지원자가 없어요. ⭐을 눌러 풀에 추가하세요.',
      'history' => '풀에 등록되지 않은 지원자가 없어요.',
      _ => '지원자가 없어요. 공고가 노출되면 이곳에 자동으로 모입니다.',
    };
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Center(
        child: Text(msg,
            style: WebTypo.body(color: AppColors.textSecondary)),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Text('인재풀을 불러오지 못했어요\n$message',
          style: const TextStyle(color: AppColors.error)),
    );
  }
}
