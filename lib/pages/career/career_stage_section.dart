import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_modal_scaffold.dart';
import 'career_shared.dart';

// ── 커리어 단계 규칙 모델 ──────────────────────────────────────
class _StageRule {
  final String name;
  final int minMonths;
  final int minClinics;

  const _StageRule({
    required this.name,
    required this.minMonths,
    required this.minClinics,
  });
}

const _kStageRules = <_StageRule>[
  _StageRule(name: '시작 단계', minMonths: 0,   minClinics: 0),
  _StageRule(name: '적응 단계', minMonths: 6,   minClinics: 1),
  _StageRule(name: '자리잡음',  minMonths: 18,  minClinics: 1),
  _StageRule(name: '안정기',   minMonths: 30,  minClinics: 1),
  _StageRule(name: '확장기',   minMonths: 42,  minClinics: 2),
  _StageRule(name: '깊어짐',   minMonths: 54,  minClinics: 2),
  _StageRule(name: '단단함',   minMonths: 72,  minClinics: 3),
  _StageRule(name: '중심 역할', minMonths: 84,  minClinics: 3),
  _StageRule(name: '영향력',   minMonths: 96,  minClinics: 4),
  _StageRule(name: '멘토 단계', minMonths: 120, minClinics: 4),
];

// 모든 단계 규칙을 외부에서 참조할 수 있도록 노출
List<Map<String, dynamic>> get careerStageRules =>
    _kStageRules
        .map(
          (r) => {
            'name': r.name,
            'minMonths': r.minMonths,
            'minClinics': r.minClinics,
          },
        )
        .toList();

int _computeStageIndex({
  required int totalMonths,
  required int totalClinics,
}) {
  int idx = 0;
  for (int i = 0; i < _kStageRules.length; i++) {
    final r = _kStageRules[i];
    if (totalMonths >= r.minMonths && totalClinics >= r.minClinics) {
      idx = i;
    }
  }
  return idx;
}

/// 외부 컴팩트 위젯에서 사용할 수 있는 현재 단계 요약 정보.
/// `_kStageRules` / `_computeStageIndex` 가 private 이므로 헬퍼로 노출한다.
class CareerStageSummary {
  final int index;
  final int totalStages;
  final String currentName;
  final String? nextName;
  final bool isMax;
  final double progress;
  final bool monthsDone;
  final bool clinicsDone;
  final bool monthsRequired;
  final bool clinicsRequired;
  final int? nextMinMonths;
  final int? nextMinClinics;
  final int totalCareerMonths;
  final int totalClinics;

  const CareerStageSummary({
    required this.index,
    required this.totalStages,
    required this.currentName,
    required this.nextName,
    required this.isMax,
    required this.progress,
    required this.monthsDone,
    required this.clinicsDone,
    required this.monthsRequired,
    required this.clinicsRequired,
    required this.nextMinMonths,
    required this.nextMinClinics,
    required this.totalCareerMonths,
    required this.totalClinics,
  });
}

CareerStageSummary computeCareerStageSummary({
  required int totalCareerMonths,
  required int totalClinics,
}) {
  final idx = _computeStageIndex(
    totalMonths: totalCareerMonths,
    totalClinics: totalClinics,
  );
  final cur = _kStageRules[idx];
  final isMax = idx == _kStageRules.length - 1;
  final next = isMax ? null : _kStageRules[idx + 1];

  bool monthsRequired = false;
  bool clinicsRequired = false;
  double progress = 1.0;

  if (!isMax) {
    monthsRequired = next!.minMonths > cur.minMonths;
    clinicsRequired = next.minClinics > cur.minClinics;
    int done = 0;
    if (totalCareerMonths >= next.minMonths) done++;
    if (totalClinics >= next.minClinics) done++;
    final total = [monthsRequired, clinicsRequired].where((v) => v).length;
    progress = total == 0 ? 1.0 : done / total;
  }

  return CareerStageSummary(
    index: idx,
    totalStages: _kStageRules.length,
    currentName: cur.name,
    nextName: next?.name,
    isMax: isMax,
    progress: progress,
    monthsDone: next == null ? true : totalCareerMonths >= next.minMonths,
    clinicsDone: next == null ? true : totalClinics >= next.minClinics,
    monthsRequired: monthsRequired,
    clinicsRequired: clinicsRequired,
    nextMinMonths: next?.minMonths,
    nextMinClinics: next?.minClinics,
    totalCareerMonths: totalCareerMonths,
    totalClinics: totalClinics,
  );
}

// ── 커리어 단계 카드 ───────────────────────────────────────────
/// Gray(AppMutedCard) 배경 위에서 렌더되는 위젯.
/// 이전에 사용하던 CareerCard(Blue) 래퍼는 제거되었으며,
/// 텍스트/배지 색상이 textPrimary 계열로 변경됨.
class CareerStageCard extends StatelessWidget {
  final int totalCareerMonths;
  final int totalClinics;

  const CareerStageCard({
    super.key,
    required this.totalCareerMonths,
    required this.totalClinics,
  });

  @override
  Widget build(BuildContext context) {
    final stageIdx = _computeStageIndex(
      totalMonths: totalCareerMonths,
      totalClinics: totalClinics,
    );
    final current = _kStageRules[stageIdx];
    final isMax = stageIdx == _kStageRules.length - 1;
    final next = isMax ? null : _kStageRules[stageIdx + 1];

    final double progress =
        isMax
            ? 1.0
            : () {
              final cur = _kStageRules[stageIdx];
              final nx = next!;
              int done = 0;
              if (totalCareerMonths >= nx.minMonths) done++;
              if (totalClinics >= nx.minClinics) done++;
              final total =
                  [
                    nx.minMonths > cur.minMonths,
                    nx.minClinics > cur.minClinics,
                  ].where((v) => v).length;
              return total == 0 ? 1.0 : done / total;
            }();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '현재 단계',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    current.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            AppBadge(
              label: '${stageIdx + 1} / ${_kStageRules.length}단계',
              bgColor: AppColors.emphasisBadgeBg,
              textColor: AppColors.emphasisBadgeText,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: AppColors.textDisabled.withOpacity(0.18),
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.accent,
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (isMax)
          Text(
            '최고 단계에 도달했어요! 지금까지 쌓아온 커리어가 빛나고 있어요.',
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          )
        else if (stageIdx == 0 && totalCareerMonths == 0 && totalClinics == 0)
          // 첫 방문, 아무 데이터도 없는 상태
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.07),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.accent.withOpacity(0.7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '커리어 카드와 치과 네트워크를 채우면\n단계가 자동으로 올라가요.',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          Text(
            '다음 단계(${next!.name})까지',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          _buildChecklist(current, next),
        ],
      ],
    );
  }

  Widget _buildChecklist(_StageRule cur, _StageRule next) {
    final items = <_ChecklistItemData>[];

    if (next.minMonths > cur.minMonths) {
      items.add(
        _ChecklistItemData(
          text: '총 경력 ${formatCareerMonths(next.minMonths)} 달성',
          done: totalCareerMonths >= next.minMonths,
          current: '현재 ${formatCareerMonths(totalCareerMonths)}',
        ),
      );
    }
    if (next.minClinics > cur.minClinics) {
      items.add(
        _ChecklistItemData(
          text: '치과 이력 ${next.minClinics}곳 달성',
          done: totalClinics >= next.minClinics,
          current: '현재 ${totalClinics}곳',
        ),
      );
    }

    return Column(
      children:
          items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ChecklistItem(item),
                ),
              )
              .toList(),
    );
  }
}

class _ChecklistItemData {
  final String text;
  final bool done;
  final String current;
  const _ChecklistItemData({
    required this.text,
    required this.done,
    required this.current,
  });
}

class _ChecklistItem extends StatelessWidget {
  final _ChecklistItemData data;
  const _ChecklistItem(this.data);

  @override
  Widget build(BuildContext context) {
    final checkSize =
        (MediaQuery.of(context).size.width * 0.05).clamp(18.0, 24.0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: checkSize,
          height: checkSize,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: data.done
                ? AppColors.accent                           // Blue (완료)
                : AppColors.textDisabled.withOpacity(0.15), // Gray (미완료)
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: data.done
              ? Icon(
                  Icons.check,
                  size: checkSize * 0.65,
                  color: AppColors.onCardPrimary, // White 체크
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: data.done
                      ? AppColors.textDisabled
                      : AppColors.textPrimary,
                  decoration: data.done
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
              if (!data.done)
                Text(
                  data.current,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CareerStageMiniStrip — 파란(Primary) 카드 배경에 얹는 컴팩트 단계 스트립
//
// 기존 [CareerStageCard] 전체 정보를 보존하면서 면적을 1/3 수준으로
// 압축한 변형. 상단 커리어 카드 안에 삽입해 "한눈에 보기" 용도로 사용.
// ══════════════════════════════════════════════════════════════
class CareerStageMiniStrip extends StatelessWidget {
  final int totalCareerMonths;
  final int totalClinics;

  /// 행 전체를 탭하면 안내 시트가 열리도록 할지 (헤더 배지로도 동일 기능 제공).
  final bool tapToOpenGuide;

  const CareerStageMiniStrip({
    super.key,
    required this.totalCareerMonths,
    required this.totalClinics,
    this.tapToOpenGuide = true,
  });

  @override
  Widget build(BuildContext context) {
    final s = computeCareerStageSummary(
      totalCareerMonths: totalCareerMonths,
      totalClinics: totalClinics,
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 얇은 진행바
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: LinearProgressIndicator(
            value: s.progress,
            minHeight: 4,
            backgroundColor: AppColors.onCardPrimary.withOpacity(0.18),
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.onCardPrimary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // 다음 목표 라벨 + 미니 칩들
        if (s.isMax)
          Text(
            '최고 단계에 도달했어요',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.onCardPrimary.withOpacity(0.85),
            ),
          )
        else if (s.index == 0 && totalCareerMonths == 0 && totalClinics == 0)
          Text(
            '커리어를 채우면 단계가 자동으로 올라가요',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.onCardPrimary.withOpacity(0.7),
            ),
          )
        else ...[
          Text(
            '다음 단계(${s.nextName})까지',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.onCardPrimary.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (s.monthsRequired)
                _MiniRequirementChip(
                  done: s.monthsDone,
                  doneLabel: '경력 ${formatCareerMonths(s.nextMinMonths!)}',
                  pendingLabel:
                      '경력 ${formatCareerMonths(s.totalCareerMonths)} '
                      '/ ${formatCareerMonths(s.nextMinMonths!)}',
                ),
              if (s.clinicsRequired)
                _MiniRequirementChip(
                  done: s.clinicsDone,
                  doneLabel: '치과 ${s.nextMinClinics}곳',
                  pendingLabel:
                      '치과 ${s.totalClinics} / ${s.nextMinClinics}곳',
                ),
            ],
          ),
        ],
      ],
    );

    if (!tapToOpenGuide) return content;

    return InkWell(
      onTap: () => showCareerStageGuideSheet(context),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: content,
      ),
    );
  }
}

/// 미니 스트립용 요구사항 칩. 파란 카드 배경 위에서 onCardPrimary 톤만 사용.
class _MiniRequirementChip extends StatelessWidget {
  final bool done;
  final String doneLabel;
  final String pendingLabel;
  const _MiniRequirementChip({
    required this.done,
    required this.doneLabel,
    required this.pendingLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.onCardPrimary.withOpacity(done ? 0.22 : 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 12,
            color: AppColors.onCardPrimary.withOpacity(done ? 1 : 0.6),
          ),
          const SizedBox(width: 4),
          Text(
            done ? doneLabel : pendingLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.onCardPrimary.withOpacity(done ? 1 : 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 커리어 단계 안내 시트 (외부에서 호출) ──────────────────────
void showCareerStageGuideSheet(BuildContext context) {
  showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
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
              color: AppColors.disabledBg,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '커리어 단계 안내',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: const Text(
              '총 경력, 치과 이력 수에 따라 단계가 자동으로 결정됩니다.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl,
              ),
              itemCount: _kStageRules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (ctx, i) {
                final r = _kStageRules[i];
                return Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Builder(
                        builder: (ctx) {
                          final badgeSize =
                              (MediaQuery.of(ctx).size.width * 0.065)
                                  .clamp(22.0, 32.0);
                          return Container(
                            width: badgeSize,
                            height: badgeSize,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: (badgeSize * 0.46).clamp(10.0, 14.0),
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          r.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (r.minMonths > 0)
                            Text(
                              '경력 ${formatCareerMonths(r.minMonths)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          if (r.minClinics > 0)
                            Text(
                              '치과 ${r.minClinics}곳',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          if (r.minMonths == 0 && r.minClinics == 0)
                            const Text(
                              '시작',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textDisabled,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
