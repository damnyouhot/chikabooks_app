import 'package:flutter/material.dart';
import '../../services/career_profile_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_badge.dart';
import 'career_shared.dart';

// ── 스킬 정보 모델 ─────────────────────────────────────────────
class CareerSkillInfo {
  final String id;
  final String title;
  final IconData icon;
  final int level;
  // null = 퀴즈 미측정 (숨김), 정수 = 퀴즈 결과 추천 레벨
  final int? recommended;

  const CareerSkillInfo({
    required this.id,
    required this.title,
    required this.icon,
    required this.level,
    this.recommended,
  });
}

// ── 스킬 빈 상태 ───────────────────────────────────────────────
class CareerSkillEmptyState extends StatelessWidget {
  final VoidCallback onTap;
  const CareerSkillEmptyState({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CareerCard(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxl,
        horizontal: AppSpacing.lg,
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 32,
            color: AppColors.onCardPrimary.withOpacity(0.4),
          ),
          const SizedBox(height: 10),
          Text(
            '아직 스킬 카드가 없어요',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.onCardPrimary.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '"관리"를 눌러 내 스킬을 추가해 보세요',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.onCardPrimary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cardEmphasis,   // Neon 버튼
              foregroundColor: AppColors.onCardEmphasis, // Black 텍스트
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl,
                vertical: AppSpacing.sm + 2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              elevation: 0,
            ),
            child: const Text(
              '스킬 추가하기',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 스킬 카드 ──────────────────────────────────────────────────
/// Gray(AppMutedCard) 배경 위에서 렌더되는 위젯.
/// 텍스트/아이콘 색상이 textPrimary 계열로 변경됨.
class CareerSkillCard extends StatefulWidget {
  final CareerSkillInfo info;
  final Map<String, Map<String, dynamic>> skillsMap;
  const CareerSkillCard({
    super.key,
    required this.info,
    required this.skillsMap,
  });

  @override
  State<CareerSkillCard> createState() => _CareerSkillCardState();
}

class _CareerSkillCardState extends State<CareerSkillCard> {
  bool _saving = false;

  Future<void> _adjustLevel(int delta) async {
    final newLevel = (widget.info.level + delta).clamp(1, 6);
    if (newLevel == widget.info.level) return;
    setState(() => _saving = true);
    try {
      await CareerProfileService.updateSkill(
        skillId: widget.info.id,
        enabled: true,
        level: newLevel,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.appBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 스킬 아이콘 컨테이너
              Builder(
                builder: (ctx) {
                  final iconBox =
                      (MediaQuery.of(ctx).size.width * 0.085).clamp(30.0, 40.0);
                  return Container(
                    width: iconBox,
                    height: iconBox,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      widget.info.icon,
                      color: AppColors.accent,
                      size: iconBox * 0.53,
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.info.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (widget.info.recommended != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 10,
                            color: AppColors.accent.withOpacity(0.7),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '추천 Lv.${widget.info.recommended}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.accent.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 2),
                      const Text(
                        '체크 질문으로 측정해보세요',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                'Lv.${widget.info.level}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => SkillQuizSheet.show(
                    context,
                    skillId: widget.info.id,
                    skillTitle: widget.info.title,
                    currentLevel: widget.info.level,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent.withOpacity(0.10),
                    foregroundColor: AppColors.accent,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: const Text(
                    '체크 질문으로 측정',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _saving
                  ? const SizedBox(
                      width: 80,
                      height: 36,
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : _LevelAdjust(
                      level: widget.info.level,
                      onMinus: () => _adjustLevel(-1),
                      onPlus: () => _adjustLevel(1),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelAdjust extends StatelessWidget {
  final int level;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _LevelAdjust({
    required this.level,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.textDisabled.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onMinus,
            icon: const Icon(Icons.remove, size: 18),
            color: AppColors.textSecondary,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          Text(
            '$level',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            onPressed: onPlus,
            icon: const Icon(Icons.add, size: 18),
            color: AppColors.textSecondary,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

// ── 스킬 관리 시트 ─────────────────────────────────────────────
class CareerSkillEditSheet extends StatefulWidget {
  const CareerSkillEditSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CareerSkillEditSheet._(),
    );
  }

  @override
  State<CareerSkillEditSheet> createState() => _CareerSkillEditSheetState();
}

class _CareerSkillEditSheetState extends State<CareerSkillEditSheet> {
  final Map<String, Map<String, dynamic>> _local = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await CareerProfileService.getMySkills();
    if (!mounted) return;
    setState(() {
      for (final m in CareerProfileService.skillMaster) {
        final id = m['id'] as String;
        final s = saved[id];
        _local[id] = {
          'enabled': s?['enabled'] ?? false,
          'level': (s?['level'] as int?) ?? 1,
        };
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // 단일 Firestore 쓰기로 전체 스킬 일괄 저장 (순차 루프 → 1회 write)
      await CareerProfileService.updateAllSkills(_local);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
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
              children: const [
                Text(
                  '스킬 관리',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '표시할 스킬을 선택하고 레벨을 조정하세요',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary, // 이전 kCText.withOpacity(0.5)
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, bottomPad + AppSpacing.lg,
                ),
                itemCount: CareerProfileService.skillMaster.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final m = CareerProfileService.skillMaster[i];
                  final id = m['id'] as String;
                  final entry = _local[id]!;
                  final enabled = entry['enabled'] as bool;
                  final level = entry['level'] as int;
                  return Container(
                    decoration: BoxDecoration(
                      color: enabled
                          ? AppColors.accent.withOpacity(0.10) // 이전 kCAccent.withOpacity(0.12)
                          : AppColors.surfaceMuted,             // 이전 kCCardBg
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              setState(() => entry['enabled'] = !enabled),
                          child: Builder(
                            builder: (ctx) {
                              final badgeSize =
                                  (MediaQuery.of(ctx).size.width * 0.065)
                                      .clamp(22.0, 32.0);
                              return Container(
                                width: badgeSize,
                                height: badgeSize,
                                decoration: BoxDecoration(
                                  // 이전 enabled ? kCText : kCMuted
                                  color: enabled
                                      ? AppColors.accent
                                      : AppColors.textDisabled,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Icon(
                                  enabled ? Icons.check : Icons.add,
                                  size: badgeSize * 0.6,
                                  color: AppColors.white,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          iconFromSkillName(m['icon'] as String),
                          size: 18,
                          // 이전 kCText.withOpacity(enabled ? 0.85 : 0.35)
                          color: enabled
                              ? AppColors.textPrimary
                              : AppColors.textDisabled,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            m['title'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              // 이전 kCText.withOpacity(enabled ? 1.0 : 0.4)
                              color: enabled
                                  ? AppColors.textPrimary
                                  : AppColors.textDisabled,
                            ),
                          ),
                        ),
                        if (enabled) ...[
                          IconButton(
                            onPressed: level > 1
                                ? () => setState(
                                    () => entry['level'] = level - 1)
                                : null,
                            icon: const Icon(Icons.remove, size: 16),
                            color: AppColors.textSecondary, // 이전 kCText.withOpacity(0.7)
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          Text(
                            'Lv.$level',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          IconButton(
                            onPressed: level < 6
                                ? () => setState(
                                    () => entry['level'] = level + 1)
                                : null,
                            icon: const Icon(Icons.add, size: 16),
                            color: AppColors.textSecondary,
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ] else
                          Text(
                            '비활성',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textDisabled, // 이전 kCText.withOpacity(0.3)
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,   // 이전 kCText(Black)
                    foregroundColor: AppColors.onAccent, // 이전 Colors.white
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
                      : const Text(
                          '저장',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 체크 질문 데이터 ───────────────────────────────────────────
const _kSkillQuiz = <String, List<String>>{
  'scaling': [
    '스케일링 기본 절차(수동/초음파)를 혼자 완수할 수 있다',
    '환자별 치석 부위를 독립적으로 판단하여 기구를 선택할 수 있다',
    '스케일링 후 연조직 상태를 평가하고 환자에게 설명할 수 있다',
    '특수 상황(임플란트, 브라켓)에서도 기구를 조절해 시술할 수 있다',
    '후배나 실습생에게 스케일링 과정을 지도·피드백할 수 있다',
    '스케일링 관련 최신 지식을 습득하고 현장에 적용한 경험이 있다',
  ],
  'prostho': [
    '인상 채득 보조 절차를 혼자 준비하고 진행할 수 있다',
    '임시치아(템포) 제작 보조를 독립적으로 수행할 수 있다',
    '최종 보철물 장착 보조 절차(시적·확인 포함)를 완수할 수 있다',
    '보철 과정별 트레이·재료를 예측해 미리 준비할 수 있다',
    '보철 케이스 진행 중 발생하는 문제 상황을 파악하고 원장에게 보고할 수 있다',
    '보철 케이스를 처음 하는 동료에게 절차를 설명·지도할 수 있다',
  ],
  'ortho': [
    '브라켓 부착 보조 절차를 혼자 준비하고 진행할 수 있다',
    '와이어 교체 보조를 독립적으로 수행할 수 있다',
    '교정 장치 관련 환자 구강 위생 지도를 단독으로 진행할 수 있다',
    '교정 진행 단계(초기·중기·마무리)를 구분하고 맞는 재료를 준비할 수 있다',
    '교정 중 발생하는 환자 불편 사항(와이어 돌출 등)을 초기 대응할 수 있다',
    '교정 케이스를 처음 하는 동료에게 절차를 설명·지도할 수 있다',
  ],
  'consult': [
    '처음 방문한 환자에게 진료 흐름을 이해하기 쉽게 안내할 수 있다',
    '치료 계획(비용·기간·절차)을 환자 눈높이에 맞게 설명할 수 있다',
    '불안해하거나 거부하는 환자를 적절히 공감하며 응대할 수 있다',
    '보험·비급여 항목 차이를 환자에게 정확히 설명할 수 있다',
    '컴플레인 상황에서 환자와 원장 사이를 중재하거나 해결한 경험이 있다',
    '신규 환자 유입·재내원율 향상을 위한 아이디어를 제안한 경험이 있다',
  ],
};

int _yesCountToLevel(int yesCount) {
  if (yesCount == 0) return 1;
  if (yesCount <= 2) return 2;
  if (yesCount == 3) return 3;
  if (yesCount == 4) return 4;
  if (yesCount == 5) return 5;
  return 6;
}

// ── 체크 질문 시트 ─────────────────────────────────────────────
class SkillQuizSheet extends StatefulWidget {
  final String skillId;
  final String skillTitle;
  final int currentLevel;

  const SkillQuizSheet._({
    required this.skillId,
    required this.skillTitle,
    required this.currentLevel,
  });

  static Future<void> show(
    BuildContext context, {
    required String skillId,
    required String skillTitle,
    required int currentLevel,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SkillQuizSheet._(
        skillId: skillId,
        skillTitle: skillTitle,
        currentLevel: currentLevel,
      ),
    );
  }

  @override
  State<SkillQuizSheet> createState() => _SkillQuizSheetState();
}

class _SkillQuizSheetState extends State<SkillQuizSheet> {
  late final List<bool?> _answers;
  bool _saving = false;
  bool _showResult = false;

  List<String>? get _questions => _kSkillQuiz[widget.skillId];
  int get _yesCount => _answers.where((a) => a == true).length;
  int get _recommendedLevel => _yesCountToLevel(_yesCount);
  bool get _allAnswered =>
      _questions != null && _answers.every((a) => a != null);

  @override
  void initState() {
    super.initState();
    _answers = List.filled(_kSkillQuiz[widget.skillId]?.length ?? 0, null);
  }

  Future<void> _applyRecommended() async {
    setState(() => _saving = true);
    try {
      await CareerProfileService.updateSkill(
        skillId: widget.skillId,
        enabled: true,
        level: _recommendedLevel,
        recommendedLevel: _recommendedLevel,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _applyCustom(int level) async {
    setState(() => _saving = true);
    try {
      await CareerProfileService.updateSkill(
        skillId: widget.skillId,
        enabled: true,
        level: level,
        recommendedLevel: _recommendedLevel,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final questions = _questions;

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
              color: AppColors.disabledBg,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.skillTitle} 체크 질문',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  questions == null
                      ? '이 스킬은 아직 질문이 준비 중이에요'
                      : '해당하는 항목에 체크해 주세요 (${_answers.where((a) => a != null).length}/${questions.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary, // 이전 kCText.withOpacity(0.5)
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (questions == null)
            _buildNoQuiz(bottomPad)
          else if (_showResult)
            _buildResult(bottomPad)
          else
            _buildQuiz(questions, bottomPad),
        ],
      ),
    );
  }

  Widget _buildNoQuiz(double bottomPad) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, bottomPad + AppSpacing.xl,
        ),
        child: Column(
          children: [
            const Icon(
              Icons.construction_outlined,
              size: 48,
              color: AppColors.textDisabled, // 이전 kCText.withOpacity(0.25)
            ),
            const SizedBox(height: 12),
            const Text(
              '이 스킬의 체크 질문은\n곧 추가될 예정이에요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary, // 이전 kCText.withOpacity(0.5)
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,   // 이전 kCText(Black)
                  foregroundColor: AppColors.onAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  '닫기',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuiz(List<String> questions, double bottomPad) {
    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.md,
              ),
              itemCount: questions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final ans = _answers[i];
                return Container(
                  decoration: BoxDecoration(
                    // border 제거 — 색상으로만 선택 상태 표현
                    color: ans == true
                        ? AppColors.accent.withOpacity(0.12)  // 이전 kCAccent.withOpacity(0.18) + border
                        : ans == false
                        ? AppColors.surfaceMuted               // 이전 kCCardBg
                        : AppColors.surfaceMuted.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          '${i + 1}.',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDisabled, // 이전 kCText.withOpacity(0.45)
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          questions[i],
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                            // 이전 kCText.withOpacity(ans == false ? 0.4 : 0.9)
                            color: ans == false
                                ? AppColors.textDisabled
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _QuizBtn(
                            label: 'Yes',
                            active: ans == true,
                            activeColor: AppColors.accent,
                            onTap: () => setState(() => _answers[i] = true),
                          ),
                          const SizedBox(height: 4),
                          _QuizBtn(
                            label: 'No',
                            active: ans == false,
                            activeColor: AppColors.textSecondary, // 이전 kCMuted
                            onTap: () => setState(() => _answers[i] = false),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, bottomPad + AppSpacing.md,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _allAnswered
                      ? () => setState(() => _showResult = true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,         // 이전 kCText(Black)
                    foregroundColor: AppColors.onAccent,
                    disabledBackgroundColor: AppColors.disabledBg, // 이전 kCShadow
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _allAnswered
                        ? '결과 보기'
                        : '${questions.length - _answers.where((a) => a != null).length}개 남았어요',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(double bottomPad) {
    final rec = _recommendedLevel;
    final cur = widget.currentLevel;
    final diff = rec - cur;
    final diffText = diff == 0
        ? '현재 레벨과 같아요'
        : diff > 0
        ? '+$diff 상향 추천'
        : '$diff 하향 추천';

    // 이전 diff>0 → kCAccent(Blue), diff<0 → Color(0xFFFF9100)(경고 오렌지)
    // 시스템 편입: diff>0 → accent, diff<0 → warning, diff==0 → textSecondary
    final diffColor = diff == 0
        ? AppColors.textSecondary
        : diff > 0
        ? AppColors.accent
        : AppColors.warning;

    return Expanded(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, bottomPad + AppSpacing.lg,
        ),
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 결과 원형 배지: 화면 너비의 20%, 최소64·최대96 clamp
                  Builder(
                    builder: (ctx) {
                      final circleSize =
                          (MediaQuery.of(ctx).size.width * 0.20).clamp(64.0, 96.0);
                      return Container(
                        width: circleSize,
                        height: circleSize,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15), // 이전 kCAccent.withOpacity(0.2)
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            'Lv.$rec',
                            style: TextStyle(
                              fontSize: (circleSize * 0.27).clamp(18.0, 26.0),
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '추천 레벨',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_yesCount / ${_questions!.length}개 해당',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary, // 이전 kCText.withOpacity(0.5)
                    ),
                  ),
                  const SizedBox(height: 10),
                  AppBadge(
                    label: diffText,
                    bgColor: diffColor.withOpacity(0.12),
                    textColor: diffColor,
                  ),
                  const SizedBox(height: 28),
                  const Divider(color: AppColors.divider),
                  const SizedBox(height: 16),
                  const Text(
                    '최종 결정권은 나에게 있어요.\n추천 레벨로 저장할까요?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textSecondary, // 이전 kCText.withOpacity(0.7)
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => _applyCustom(widget.currentLevel),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.divider), // 이전 kCShadow
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                    child: Text(
                      '현재(Lv.$cur) 유지',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _applyRecommended,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,   // 이전 kCText(Black)
                      foregroundColor: AppColors.onAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onAccent,
                            ),
                          )
                        : Text(
                            'Lv.$rec 으로 저장',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _QuizBtn({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 48,
        height: 30,
        decoration: BoxDecoration(
          // border 제거 — 배경색으로 선택 상태 표현
          color: active ? activeColor : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              // 이전 active ? kCText : kCText.withOpacity(0.4)
              color: active ? AppColors.white : AppColors.textDisabled,
            ),
          ),
        ),
      ),
    );
  }
}
