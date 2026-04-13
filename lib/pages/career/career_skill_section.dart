import 'package:flutter/material.dart';
import '../../services/career_profile_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'career_shared.dart';

// ── 스킬 정보 모델 ─────────────────────────────────────────────
class CareerSkillInfo {
  final String id;
  final String title;
  final IconData icon;

  const CareerSkillInfo({
    required this.id,
    required this.title,
    required this.icon,
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
              backgroundColor: AppColors.cardEmphasis,
              foregroundColor: AppColors.onCardEmphasis,
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

// ── 스킬 카드 (1줄) ─────────────────────────────────────────────
/// 아이콘 + 스킬명 + 체크 아이콘 한 줄 표시
class CareerSkillCard extends StatelessWidget {
  final CareerSkillInfo info;

  const CareerSkillCard({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.appBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider, width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(info.icon, color: AppColors.accent, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              info.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.15,
                letterSpacing: -0.2,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Icon(Icons.check_circle, size: 18, color: AppColors.accent.withOpacity(0.7)),
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
  final Map<String, bool> _local = {};
  final List<Map<String, dynamic>> _customSkills = [];
  bool _loading = true;
  bool _saving = false;
  bool _showCustomInput = false;
  final _customCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final saved = await CareerProfileService.getMySkills();
    if (!mounted) return;
    setState(() {
      final masterIds = CareerProfileService.skillMaster
          .map((m) => m['id'] as String)
          .toSet();

      for (final m in CareerProfileService.skillMaster) {
        final id = m['id'] as String;
        _local[id] = saved[id]?['enabled'] == true;
      }

      // skillMaster에 없는 저장된 스킬 → 커스텀으로 로드
      for (final entry in saved.entries) {
        if (!masterIds.contains(entry.key)) {
          _customSkills.add({
            'id': entry.key,
            'title': entry.value['title'] as String? ?? entry.key,
            'enabled': entry.value['enabled'] ?? true,
          });
        }
      }

      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // skillMaster 스킬 일괄 저장 (enabled 여부만)
      final payload = _local.map(
        (id, enabled) => MapEntry(id, {'enabled': enabled}),
      );
      await CareerProfileService.updateAllSkillsEnabled(payload);

      // 커스텀 스킬 저장
      for (final c in _customSkills) {
        await CareerProfileService.updateSkill(
          skillId: c['id'] as String,
          enabled: c['enabled'] as bool,
        );
        await CareerProfileService.updateSkillTitle(
          skillId: c['id'] as String,
          title: c['title'] as String,
        );
      }

      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addCustomSkill() {
    final text = _customCtrl.text.trim();
    if (text.isEmpty) return;
    final id = 'custom_$text';
    if (_customSkills.any((c) => c['id'] == id) ||
        CareerProfileService.skillMaster.any((m) => m['title'] == text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이미 있는 스킬이에요.'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    setState(() {
      _customSkills.add({'id': id, 'title': text, 'enabled': true});
      _customCtrl.clear();
      _showCustomInput = false;
    });
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
                    '보유한 스킬을 선택하세요',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
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
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      0,
                    ),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 8,
                        childAspectRatio: 3.92,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final m = CareerProfileService.skillMaster[index];
                          final id = m['id'] as String;
                          final enabled = _local[id] ?? false;
                          return _SkillToggleRow(
                            title: m['title'] as String,
                            icon: iconFromSkillName(m['icon'] as String),
                            enabled: enabled,
                            onToggle: () => setState(() => _local[id] = !enabled),
                          );
                        },
                        childCount: CareerProfileService.skillMaster.length,
                      ),
                    ),
                  ),
                  if (_customSkills.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          4,
                          AppSpacing.lg,
                          8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Divider(),
                            SizedBox(height: 8),
                            Text(
                              '직접 추가한 스킬',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        0,
                      ),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 8,
                          childAspectRatio: 3.92,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final c = _customSkills[i];
                            final enabled = c['enabled'] as bool;
                            return _SkillToggleRow(
                              title: c['title'] as String,
                              icon: Icons.star_outline,
                              enabled: enabled,
                              onToggle: () =>
                                  setState(() => c['enabled'] = !enabled),
                              onDelete: () =>
                                  setState(() => _customSkills.removeAt(i)),
                            );
                          },
                          childCount: _customSkills.length,
                        ),
                      ),
                    ),
                  ],
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        4,
                        AppSpacing.lg,
                        bottomPad + AppSpacing.lg,
                      ),
                      child: !_showCustomInput
                          ? OutlinedButton.icon(
                              onPressed: () =>
                                  setState(() => _showCustomInput = true),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text(
                                '직접 추가하기',
                                style: TextStyle(fontSize: 13),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accent,
                                side: BorderSide(
                                  color: AppColors.accent.withOpacity(0.4),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            )
                          : _buildCustomInput(),
                    ),
                  ),
                ],
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
                    backgroundColor: AppColors.accent,
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
                      : const Text(
                          '저장',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '스킬 직접 입력',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customCtrl,
                  autofocus: true,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '예: 틀니 보조, 치과CT 촬영 등',
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.textDisabled),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.accent),
                    ),
                    filled: true,
                    fillColor: AppColors.white,
                  ),
                  onSubmitted: (_) => _addCustomSkill(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addCustomSkill,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: const Text('추가', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => setState(() {
              _showCustomInput = false;
              _customCtrl.clear();
            }),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('취소', style: TextStyle(fontSize: 12, color: AppColors.textDisabled)),
          ),
        ],
      ),
    );
  }
}

// ── 스킬 관리 시트용 토글 행 위젯 ──────────────────────────────
class _SkillToggleRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool enabled;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;

  const _SkillToggleRow({
    required this.title,
    required this.icon,
    required this.enabled,
    required this.onToggle,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? AppColors.accent.withOpacity(0.10) : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: enabled ? AppColors.accent : AppColors.textDisabled,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                enabled ? Icons.check : Icons.add,
                size: 12,
                color: AppColors.white,
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              icon,
              size: 14,
              color: enabled ? AppColors.textPrimary : AppColors.textDisabled,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: enabled ? AppColors.textPrimary : AppColors.textDisabled,
                ),
              ),
            ),
            if (onDelete != null)
              GestureDetector(
                onTap: onDelete,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: Icon(Icons.close, size: 14, color: AppColors.textDisabled),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
