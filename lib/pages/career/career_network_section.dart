import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../services/career_profile_service.dart';
import '../../models/resume.dart';
import '../../services/resume_career_sync_service.dart';
import '../../services/resume_service.dart';
import 'career_shared.dart';
import 'resume_pick_for_network_sheet.dart';

// ── 나의 치과 히스토리 카드 (구 career 네트워크) ─────────────────
class CareerNetworkCard extends StatefulWidget {
  const CareerNetworkCard({super.key});

  @override
  State<CareerNetworkCard> createState() => _CareerNetworkCardState();
}

class _CareerNetworkCardState extends State<CareerNetworkCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DentalNetworkEntry>>(
      stream: CareerProfileService.watchNetworkEntries(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return CareerCard(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 14, AppSpacing.lg, 14,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '나의 치과 히스토리',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.onCardPrimary,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '불러오는 중...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onCardPrimary, // 이전 kCText.withOpacity(0.45)
                  ),
                ),
              ],
            ),
          );
        }
        if (snap.hasError) {
          return const CareerErrorCard(message: '치과 히스토리를 불러오지 못했어요.');
        }

        final entries = snap.data ?? [];
        final totalClinics = entries.length;
        final totalMonths = entries.fold(0, (sum, e) => sum + e.months);

        return CareerCard(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 14, AppSpacing.lg, 14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '나의 치과 히스토리',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppColors.onCardPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => DentalNetworkEditSheet.show(context),
                        icon: const Icon(Icons.add, size: 18),
                        color: AppColors.onCardPrimary, // 이전 kCText.withOpacity(0.65)
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: '추가',
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _expanded ? '접기' : '펼치기',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onCardPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: AppColors.onCardPrimary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    totalClinics == 0
                        ? kDentalHistoryEmptyHint
                        : '총 $totalClinics곳 · 총 ${formatCareerMonths(totalMonths)}',
                    style: TextStyle(
                      fontSize: 12,
                      // 이전 totalClinics==0 → kCAccent.withOpacity(0.8) : kCText.withOpacity(0.65)
                      color: totalClinics == 0
                          ? AppColors.cardEmphasis          // Neon 포인트 (빈 상태 CTA)
                          : AppColors.onCardPrimary,
                    ),
                  ),
                ),
              ),
              // 접힌 상태에서도 가장 최근 근무지(startDate 내림차순 첫 항목)는 항상 표시
              if (entries.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _NetworkTimelineItem(
                    entry: entries.first,
                    onEdit: () => DentalNetworkEditSheet.show(
                      context,
                      editing: entries.first,
                    ),
                    onDelete: () => _confirmDelete(context, entries.first),
                  ),
                ),
              ],
              AnimatedCrossFade(
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
                firstChild: const SizedBox.shrink(),
                secondChild: entries.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _NetworkEmptyHint(
                          onAdd: () => DentalNetworkEditSheet.show(context),
                        ),
                      )
                    : entries.length <= 1
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: entries
                                  .skip(1)
                                  .map(
                                    (e) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: _NetworkTimelineItem(
                                        entry: e,
                                        onEdit: () =>
                                            DentalNetworkEditSheet.show(
                                          context,
                                          editing: e,
                                        ),
                                        onDelete: () =>
                                            _confirmDelete(context, e),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    DentalNetworkEntry entry,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제하시겠어요?'),
        content: Text('"${entry.clinicName}" 이력을 삭제합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '삭제',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await CareerProfileService.deleteNetworkEntry(entry.id);
    }
  }
}

class _NetworkEmptyHint extends StatelessWidget {
  final VoidCallback onAdd;
  const _NetworkEmptyHint({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // 이전 kCShadow — surfaceMuted로 통일
        color: AppColors.onCardPrimary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          // 왼쪽 accent 바 — 이전 kCAccent → cardEmphasis(Neon)
          Container(
            width: 7,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.cardEmphasis,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              kDentalHistoryEmptyHint,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.onCardPrimary.withOpacity(0.92),
              ),
            ),
          ),
          TextButton(
            onPressed: onAdd,
            child: const Text('추가하기'),
          ),
        ],
      ),
    );
  }
}

class _NetworkTimelineItem extends StatelessWidget {
  final DentalNetworkEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NetworkTimelineItem({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  static const double _barHeight = 40;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // border 제거 — 배경색으로 현재 재직 여부 표현
        color: entry.isCurrent
            ? AppColors.onCardPrimary.withOpacity(0.12) // 이전 kCAccent.withOpacity(0.1) + border
            : AppColors.onCardPrimary.withOpacity(0.07), // 이전 kCCardBg
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 타임라인 바 — 이전 isCurrent ? kCAccent : kCAccent.withOpacity(0.45)
          Container(
            width: 6,
            height: _barHeight,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: entry.isCurrent
                  ? AppColors.cardEmphasis                  // Neon (현재 재직)
                  : AppColors.onCardPrimary.withOpacity(0.3), // 이전 근무지
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.periodLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.onCardPrimary, // 이전 kCText.withOpacity(0.5)
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.clinicName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onCardPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatCareerMonths(entry.months),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.onCardPrimary, // 이전 kCText.withOpacity(0.6)
                  ),
                ),
                if (entry.tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: entry.tags
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              // 이전 kCAccent.withOpacity(0.25)
                              color: AppColors.onCardPrimary.withOpacity(0.20),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              t,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onCardPrimary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (entry.acquiredSkills.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: entry.acquiredSkills
                        .map(
                          (s) => Text(
                            '$s +1',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.onCardPrimary,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: AppColors.onCardPrimary, // 이전 kCText.withOpacity(0.55)
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(4),
                  minimumSize: const Size(32, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppColors.error, // 이전 Colors.redAccent.withOpacity(0.7)
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(4),
                  minimumSize: const Size(32, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 치과 히스토리 편집 시트 ────────────────────────────────────
class DentalNetworkEditSheet extends StatelessWidget {
  final DentalNetworkEntry? editing;
  const DentalNetworkEditSheet._({this.editing});

  static Future<void> show(
    BuildContext context, {
    DentalNetworkEntry? editing,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DentalNetworkEditSheet._(editing: editing),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (editing != null) return _DentalEntryFormSheet(editing: editing);
    return const _DentalNetworkListSheet();
  }
}

class _DentalNetworkListSheet extends StatefulWidget {
  const _DentalNetworkListSheet();

  @override
  State<_DentalNetworkListSheet> createState() =>
      _DentalNetworkListSheetState();
}

class _DentalNetworkListSheetState extends State<_DentalNetworkListSheet> {
  bool _extracting = false;
  bool _deletingSynced = false;

  Future<void> _onExtractFromResume() async {
    if (_extracting) return;
    setState(() => _extracting = true);

    final messenger = ScaffoldMessenger.of(context);

    try {
      final resumes = await ResumeService.fetchMyResumes();
      if (!mounted) return;

      final preferredId = await ResumeService.getLastImportedResumeId();
      if (!mounted) return;

      var withCareer =
          resumes
              .where(
                (r) => r.experiences.any((e) => e.clinicName.trim().isNotEmpty),
              )
              .toList();

      withCareer.sort((a, b) {
        final aPref =
            preferredId != null && a.id == preferredId;
        final bPref =
            preferredId != null && b.id == preferredId;
        if (aPref != bPref) return aPref ? -1 : 1;
        final at = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });

      if (withCareer.isEmpty) {
        if (resumes.isEmpty) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                '작성된 이력서가 없어요. 이력서를 먼저 만든 뒤 다시 시도해 주세요.',
              ),
            ),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                '이력서에 등록된 경력이 없어요. 경력을 입력한 뒤 다시 시도해 주세요.',
              ),
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      final Resume? picked = await showResumePickerForNetworkExport(
        context,
        withCareer,
        preferredResumeId: preferredId,
      );

      if (!mounted) return;
      if (picked == null) return;

      await ResumeCareerSyncService.syncFromResume(
        picked,
        syncSkills: false,
      );

      if (!mounted) return;
      final title = picked.title.trim();
      final label =
          title.isEmpty
              ? Resume.kDefaultResumeTitle
              : (title.length > 32 ? '${title.substring(0, 29)}…' : title);
      messenger.showSnackBar(
        SnackBar(
          content: Text('「$label」경력을 치과 히스토리에 반영했어요.'),
        ),
      );
    } catch (e, st) {
      debugPrint('⚠️ 치과 히스토리 이력서 추출: $e\n$st');
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('불러오지 못했어요. 잠시 후 다시 시도해 주세요.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _extracting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // drag handle
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.disabledBg, // 이전 kCShadow
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '나의 치과 히스토리',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _extracting
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const _DentalEntryFormSheet(),
                          );
                        },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('추가'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent, // 이전 kCText(Black)
                    foregroundColor: AppColors.onAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Semantics(
              button: true,
              label: '이력서에서 치과 경력 추출',
              child: SizedBox(
                width: double.infinity,
                height: AppPublisher.ctaHeight,
                child: ElevatedButton(
                  onPressed: _extracting ? null : _onExtractFromResume,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    disabledBackgroundColor: AppColors.accent.withValues(
                      alpha: 0.45,
                    ),
                    disabledForegroundColor: AppColors.onAccent.withValues(
                      alpha: 0.85,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppPublisher.buttonRadius,
                      ),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child:
                      _extracting
                          ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onAccent,
                            ),
                          )
                          : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.description_outlined, size: 20),
                              SizedBox(width: 8),
                              Text('이력서에서 추출하기'),
                            ],
                          ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<DentalNetworkEntry>>(
              stream: CareerProfileService.watchNetworkEntries(),
              builder: (context, snap) {
                final entries = snap.data ?? [];
                if (entries.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.business_outlined,
                            size: 48,
                            color: AppColors.textDisabled, // 이전 kCText.withOpacity(0.2)
                          ),
                          SizedBox(height: 12),
                          Text(
                            '아직 등록된 치과가 없어요.\n'
                            '위에서 이력서 경력을 가져오거나, 오른쪽 위 추가로 직접 입력할 수 있어요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: AppColors.textSecondary, // 이전 kCText.withOpacity(0.45)
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final hasSynced =
                    entries.any((e) => e.syncedFromResume);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.sm,
                        ),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final e = entries[i];
                          return Container(
                            decoration: BoxDecoration(
                              color: e.isCurrent
                                  ? AppColors.accent.withOpacity(0.10)
                                  : AppColors.surfaceMuted,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.lg),
                            ),
                            padding: const EdgeInsets.fromLTRB(
                              14,
                              10,
                              8,
                              10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.clinicName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${e.periodLabel}  ·  ${formatCareerMonths(e.months)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    showModalBottomSheet<void>(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder:
                                          (_) => _DentalEntryFormSheet(
                                            editing: e,
                                          ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  color: AppColors.textSecondary,
                                ),
                                IconButton(
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder:
                                          (ctx) => AlertDialog(
                                            title: const Text(
                                              '삭제하시겠어요?',
                                            ),
                                            content: Text(
                                              '"${e.clinicName}" 이력을 삭제합니다.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(
                                                      ctx,
                                                    ).pop(false),
                                                child: const Text('취소'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(
                                                      ctx,
                                                    ).pop(true),
                                                child: const Text(
                                                  '삭제',
                                                  style: TextStyle(
                                                    color: AppColors.error,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                    );
                                    if (ok == true) {
                                      await CareerProfileService
                                          .deleteNetworkEntry(e.id);
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  color: AppColors.error,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    if (hasSynced)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.md,
                        ),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed:
                                _deletingSynced
                                    ? null
                                    : () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder:
                                            (ctx) => AlertDialog(
                                              title: const Text(
                                                '이력서에서 가져온 경력만 삭제',
                                              ),
                                              content: const Text(
                                                '이력서 동기화로 추가된 항목만 모두 삭제합니다. '
                                                '직접 추가한 치과는 그대로 둡니다.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(
                                                        ctx,
                                                      ).pop(false),
                                                  child: const Text('취소'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(
                                                        ctx,
                                                      ).pop(true),
                                                  child: const Text(
                                                    '전체 삭제',
                                                    style: TextStyle(
                                                      color:
                                                          AppColors.error,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                      );
                                      if (ok != true || !context.mounted) {
                                        return;
                                      }
                                      setState(() => _deletingSynced = true);
                                      try {
                                        final n =
                                            await CareerProfileService
                                                .deleteAllSyncedFromResumeNetworkEntries();
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              n > 0
                                                  ? '이력서에서 가져온 경력 $n건을 삭제했어요.'
                                                  : '삭제할 항목이 없어요.',
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '삭제하지 못했어요: $e',
                                            ),
                                          ),
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(
                                            () => _deletingSynced = false,
                                          );
                                        }
                                      }
                                    },
                            child:
                                _deletingSynced
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Text(
                                      '전체 삭제',
                                      style: TextStyle(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── 치과 이력 추가/수정 폼 ─────────────────────────────────────
class _DentalEntryFormSheet extends StatefulWidget {
  final DentalNetworkEntry? editing;
  const _DentalEntryFormSheet({this.editing});

  @override
  State<_DentalEntryFormSheet> createState() => _DentalEntryFormSheetState();
}

class _DentalEntryFormSheetState extends State<_DentalEntryFormSheet> {
  final _clinicCtrl = TextEditingController();
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _endDate;
  bool _isCurrent = true;
  List<String> _tags = [];
  List<String> _acquiredSkills = [];
  bool _saving = false;

  static const _kTagOptions = [
    '스케일링',
    '보철',
    '교정',
    '상담',
    '보험청구',
    '임플란트',
    '소아',
    '데스크',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _clinicCtrl.text = e.clinicName;
      _startDate = e.startDate;
      _endDate = e.endDate;
      _isCurrent = e.isCurrent;
      _tags = List.from(e.tags);
      _acquiredSkills = List.from(e.acquiredSkills);
    }
  }

  @override
  void dispose() {
    _clinicCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: isStart ? '입사 연월 선택' : '퇴사 연월 선택',
      fieldLabelText: '날짜',
    );
    if (picked == null) return;
    setState(() {
      final d = DateTime(picked.year, picked.month);
      if (isStart) {
        _startDate = d;
      } else {
        _endDate = d;
      }
    });
  }

  Future<void> _save() async {
    final name = _clinicCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('치과 이름을 입력해 주세요.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final entry = DentalNetworkEntry(
        id: widget.editing?.id ?? '',
        clinicName: name,
        startDate: _startDate,
        endDate: _isCurrent ? null : _endDate,
        tags: _tags,
        acquiredSkills: _acquiredSkills,
        // 시트에서 저장 = 사용자 확정 → 이력서 자동동기화 대상에서 제외
        syncedFromResume: false,
      );
      if (widget.editing == null) {
        await CareerProfileService.addNetworkEntry(entry);
      } else {
        await CareerProfileService.updateNetworkEntry(entry);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.editing != null;

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // drag handle
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.disabledBg, // 이전 kCShadow
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isEdit ? '이력 수정' : '치과 이력 추가',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl, 0, AppSpacing.xl, bottomPad + AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '치과 이름',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _clinicCtrl,
                    decoration: InputDecoration(
                      hintText: '예) 서울 ○○치과',
                      filled: true,
                      fillColor: AppColors.surfaceMuted, // 이전 kCCardBg
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Text(
                    '입사 연월',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  CareerDatePickerTile(
                    label: '${_startDate.year}년 ${_startDate.month}월',
                    onTap: () => _pickDate(isStart: true),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Checkbox(
                        value: _isCurrent,
                        onChanged: (v) =>
                            setState(() => _isCurrent = v ?? true),
                        activeColor: AppColors.accent, // 이전 kCText(Black)
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const Text(
                        '현재 재직 중',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (!_isCurrent) ...[
                    const SizedBox(height: 10),
                    const Text(
                      '퇴사 연월',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CareerDatePickerTile(
                      label: _endDate == null
                          ? '날짜 선택'
                          : '${_endDate!.year}년 ${_endDate!.month}월',
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  const Text(
                    '주요 업무 태그',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _kTagOptions
                        .map(
                          (t) => FilterChip(
                            label: Text(t),
                            selected: _tags.contains(t),
                            onSelected: (v) => setState(() {
                              if (v) {
                                _tags.add(t);
                              } else {
                                _tags.remove(t);
                              }
                            }),
                            // 이전 kCAccent.withOpacity(0.35) → accent 계열
                            selectedColor: AppColors.accent.withOpacity(0.18),
                            checkmarkColor: AppColors.accent,
                            backgroundColor: AppColors.surfaceMuted, // 이전 kCShadow
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _tags.contains(t)
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            side: BorderSide.none,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Text(
                    '이 기간에 성장한 스킬',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _kTagOptions
                        .map(
                          (t) => FilterChip(
                            label: Text(t),
                            selected: _acquiredSkills.contains(t),
                            onSelected: (v) => setState(() {
                              if (v) {
                                _acquiredSkills.add(t);
                              } else {
                                _acquiredSkills.remove(t);
                              }
                            }),
                            // 이전 kCShadow.withOpacity(0.6) → surfaceMuted
                            selectedColor: AppColors.surfaceMuted,
                            checkmarkColor: AppColors.textPrimary,
                            backgroundColor: AppColors.surfaceMuted,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _acquiredSkills.contains(t)
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            side: BorderSide.none,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,   // 이전 kCText(Black)
                        foregroundColor: AppColors.onAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        elevation: 0,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onAccent,
                              ),
                            )
                          : Text(
                              isEdit ? '수정 완료' : '저장',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
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
}
