import 'package:flutter/material.dart';
import '../../services/career_profile_service.dart';
import '../../services/admin_activity_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_badge.dart';
import 'career_shared.dart';

// ── 커리어 아이덴티티 카드 (빈 상태) ────────────────────────────
class CareerIdentityEmptyCard extends StatelessWidget {
  const CareerIdentityEmptyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => CareerIdentitySheet.show(context),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: CareerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '내 커리어 카드',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onCardPrimary,
                  ),
                ),
                const Spacer(),
                AppBadge(
                  label: '채우기',
                  bgColor: AppColors.onCardPrimary.withOpacity(0.2),
                  textColor: AppColors.onCardPrimary,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '아직 비어 있어요',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.onCardPrimary.withOpacity(0.65),
              ),
            ),
            const SizedBox(height: 14),
            const _PlaceholderRow(label: '현재 치과'),
            const SizedBox(height: 10),
            const _PlaceholderRow(label: '총 경력'),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => CareerIdentitySheet.show(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cardEmphasis,   // Neon 버튼
                  foregroundColor: AppColors.onCardEmphasis, // Black 텍스트
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: const Text(
                  '지금 채우기',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderRow extends StatelessWidget {
  final String label;
  const _PlaceholderRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.onCardPrimary.withOpacity(0.75),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.onCardPrimary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 커리어 아이덴티티 카드 (채워진 상태) ───────────────────────
class CareerIdentityFilledCard extends StatelessWidget {
  final Map<String, dynamic> identity;
  final int totalCareerMonths;
  final int autoMonths;

  const CareerIdentityFilledCard({
    super.key,
    required this.identity,
    required this.totalCareerMonths,
    required this.autoMonths,
  });

  @override
  Widget build(BuildContext context) {
    final clinicName = (identity['clinicName'] as String?)?.trim() ?? '';
    final status = (identity['status'] as String?) ?? 'employed';
    final tags =
        (identity['specialtyTags'] as List?)?.cast<String>() ?? const [];
    final useOverride = identity['useTotalCareerMonthsOverride'] == true;

    final startTs = identity['currentStartDate'];
    String? currentDuration;
    if (status == 'employed' && startTs != null) {
      try {
        final start = (startTs as dynamic).toDate() as DateTime;
        final now = DateTime.now();
        final m = (now.year - start.year) * 12 + (now.month - start.month);
        currentDuration = formatCareerMonths(m < 1 ? 1 : m);
      } catch (_) {}
    }

    final titleLine = switch (status) {
      'leave' =>
        clinicName.isEmpty ? '현재: 잠시 쉬는 중' : '현재: $clinicName · 잠시 쉬는 중',
      'unemployed' => '현재: 다음 치과를 기다리는 중',
      _ =>
        clinicName.isEmpty
            ? '현재: (미입력)'
            : currentDuration != null
            ? '현재: $clinicName · $currentDuration째'
            : '현재: $clinicName',
    };

    return CareerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '치과위생사',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onCardPrimary.withOpacity(0.85),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  // 커리어 카드 수정 이벤트 기록
                  AdminActivityService.log(
                    ActivityEventType.tapCareerEdit,
                    page: 'career',
                    targetId: 'identity',
                  );
                  CareerIdentitySheet.show(context);
                },
                icon: Icon(
                  Icons.edit_outlined,
                  color: AppColors.onCardPrimary.withOpacity(0.6),
                  size: 18,
                ),
                tooltip: '수정',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            titleLine,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.onCardPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '총 경력: ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onCardPrimary.withOpacity(0.6),
                ),
              ),
              Text(
                totalCareerMonths == 0
                    ? '미입력'
                    : formatCareerMonths(totalCareerMonths),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onCardPrimary,
                ),
              ),
              if (useOverride) ...[
                const SizedBox(width: 4),
                AppBadge(
                  label: '직접입력',
                  bgColor: AppColors.onCardPrimary.withOpacity(0.2),
                  textColor: AppColors.onCardPrimary.withOpacity(0.8),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '전문 분야',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.onCardPrimary.withOpacity(0.75),
            ),
          ),
          const SizedBox(height: 8),
          if (tags.isEmpty)
            Text(
              '아직 없어요',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.onCardPrimary.withOpacity(0.65),
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.onCardPrimary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      t,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onCardPrimary,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── 커리어 아이덴티티 편집 시트 ──────────────────────────────────
class CareerIdentitySheet extends StatefulWidget {
  const CareerIdentitySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const CareerIdentitySheet(),
    );
  }

  @override
  State<CareerIdentitySheet> createState() => _CareerIdentitySheetState();
}

class _CareerIdentitySheetState extends State<CareerIdentitySheet> {
  String _status = 'employed';
  final _clinicCtrl = TextEditingController();
  final Set<String> _tags = {};
  DateTime? _currentStartDate;
  bool _useOverride = false;
  final _overrideCtrl = TextEditingController();
  bool _saving = false;
  bool _loading = true;

  static const _tagOptions = <String>[
    '스케일링',
    '보철',
    '교정',
    '상담',
    '보험청구',
    '임플란트',
    '소아',
    '멸균/소독',
    '데스크',
    'X-ray',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await CareerProfileService.getMyCareerProfile();
      final identity = profile?['identity'] as Map<String, dynamic>?;
      if (!mounted) return;
      if (identity != null) {
        final overrideM = (identity['totalCareerMonthsOverride'] as int?) ?? 0;
        setState(() {
          _status = (identity['status'] as String?) ?? 'employed';
          _clinicCtrl.text = (identity['clinicName'] as String?) ?? '';
          _tags
            ..clear()
            ..addAll(
              (identity['specialtyTags'] as List?)?.cast<String>() ?? const [],
            );
          try {
            final ts = identity['currentStartDate'];
            if (ts != null) {
              _currentStartDate = (ts as dynamic).toDate() as DateTime;
            }
          } catch (_) {}
          _useOverride = identity['useTotalCareerMonthsOverride'] == true;
          _overrideCtrl.text = overrideM > 0 ? '$overrideM' : '';
        });
      }
    } catch (_) {
      // 로드 실패해도 기본값으로 편집 가능하게 유지
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _clinicCtrl.dispose();
    _overrideCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _currentStartDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: '입사 연월 선택',
    );
    if (picked == null) return;
    setState(() => _currentStartDate = DateTime(picked.year, picked.month));
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final overrideM =
        _useOverride ? (int.tryParse(_overrideCtrl.text) ?? 0) : 0;
    try {
      await CareerProfileService.updateCareerIdentity(
        status: _status,
        clinicName: _clinicCtrl.text,
        specialtyTags: _tags.toList(),
        currentStartDate: _currentStartDate,
        useTotalCareerMonthsOverride: _useOverride,
        totalCareerMonthsOverride: _useOverride ? overrideM : null,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    if (_loading) {
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: const SafeArea(
          top: false,
          child: SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg,
          ),
          children: [
            const Text(
              '커리어 카드 수정',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '현재 상태',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _ChoiceChip(
                  label: '재직 중',
                  selected: _status == 'employed',
                  onTap: () => setState(() => _status = 'employed'),
                ),
                _ChoiceChip(
                  label: '휴직',
                  selected: _status == 'leave',
                  onTap: () => setState(() => _status = 'leave'),
                ),
                _ChoiceChip(
                  label: '미취업',
                  selected: _status == 'unemployed',
                  onTap: () => setState(() => _status = 'unemployed'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              '현재 치과명',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _clinicCtrl,
              decoration: InputDecoration(
                hintText: _status == 'unemployed' ? '미입력 가능' : '예: 서울 ○○치과',
                filled: true,
                fillColor: AppColors.surfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: AppColors.divider, width: 0.8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: AppColors.divider, width: 0.8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide:
                      const BorderSide(color: AppColors.accent, width: 1.4),
                ),
              ),
            ),
            if (_status == 'employed') ...[
              const SizedBox(height: 14),
              const Text(
                '현재 치과 입사 연월',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              CareerDatePickerTile(
                label: _currentStartDate == null
                    ? '날짜 선택 (선택사항)'
                    : '${_currentStartDate!.year}년 ${_currentStartDate!.month}월',
                onTap: _pickStartDate,
              ),
            ],
            const SizedBox(height: 18),
            // ── 총 경력 직접 입력 박스 ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '총 경력 직접 입력',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              '치과 네트워크 자동 합산 대신 직접 입력',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary, // 이전 kCText.withOpacity(0.5)
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _useOverride,
                        onChanged: (v) => setState(() => _useOverride = v),
                        activeColor: AppColors.accent, // 이전 kCText(Black) → accent(Blue)
                      ),
                    ],
                  ),
                  if (_useOverride) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _overrideCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '개월 수 입력 (예: 36)',
                              filled: true,
                              fillColor: AppColors.white,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                borderSide: BorderSide(
                                  color: AppColors.divider,
                                  width: 0.8,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                borderSide: BorderSide(
                                  color: AppColors.divider,
                                  width: 0.8,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                borderSide: const BorderSide(
                                  color: AppColors.accent,
                                  width: 1.4,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm + 2,
                              ),
                              suffixText: '개월',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _overrideCtrl.text.isEmpty
                              ? ''
                              : formatCareerMonths(
                                  int.tryParse(_overrideCtrl.text) ?? 0,
                                ),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary, // 이전 kCText.withOpacity(0.65)
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '전문 분야(선택)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _tagOptions)
                  FilterChip(
                    label: Text(t),
                    selected: _tags.contains(t),
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _tags.add(t);
                        } else {
                          _tags.remove(t);
                        }
                      });
                    },
                    selectedColor: AppColors.accent.withOpacity(0.2),
                    checkmarkColor: AppColors.accent,
                    side: BorderSide(color: AppColors.divider, width: 0.8),
                    labelStyle: TextStyle(
                      color: AppColors.textPrimary.withOpacity(0.85),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,      // 이전 kCAccent
                foregroundColor: AppColors.onAccent,    // 이전 kCText(Black) → onAccent(White)
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
              child: Text(_saving ? '저장 중...' : '저장'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withOpacity(0.18) // 이전 kCAccent.withOpacity(0.35)
              : AppColors.surfaceMuted,             // 이전 Color(0xFFF1F3F3)
          borderRadius: BorderRadius.circular(AppRadius.full),
          // border 제거 (이전 Border.all(color: kCShadow))
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected
                ? AppColors.accent          // 이전 kCText
                : AppColors.textSecondary,  // 이전 kCText.withOpacity(0.75)
          ),
        ),
      ),
    );
  }
}
