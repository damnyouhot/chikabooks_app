import 'package:flutter/material.dart';
import '../../services/career_profile_service.dart';
import 'career_shared.dart';

// ── 커리어 아이덴티티 카드 (빈 상태) ────────────────────────────
class CareerIdentityEmptyCard extends StatelessWidget {
  const CareerIdentityEmptyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => CareerIdentitySheet.show(context),
      borderRadius: BorderRadius.circular(16),
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
                    color: kCText,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: kCAccent.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '채우기',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: kCText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '아직 비어 있어요',
              style: TextStyle(fontSize: 12, color: kCText.withOpacity(0.65)),
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
                  backgroundColor: kCAccent,
                  foregroundColor: kCText,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
              color: kCText.withOpacity(0.75),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F3),
              borderRadius: BorderRadius.circular(8),
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
                  color: kCText.withOpacity(0.85),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => CareerIdentitySheet.show(context),
                icon: Icon(
                  Icons.edit_outlined,
                  color: kCText.withOpacity(0.6),
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
              color: kCText,
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
                  color: kCText.withOpacity(0.6),
                ),
              ),
              Text(
                totalCareerMonths == 0
                    ? '미입력'
                    : formatCareerMonths(totalCareerMonths),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: kCText,
                ),
              ),
              if (useOverride) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: kCShadow.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '직접입력',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: kCText.withOpacity(0.6),
                    ),
                  ),
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
              color: kCText.withOpacity(0.75),
            ),
          ),
          const SizedBox(height: 8),
          if (tags.isEmpty)
            Text(
              '아직 없어요',
              style: TextStyle(fontSize: 12, color: kCText.withOpacity(0.65)),
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
                      color: kCAccent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: kCShadow, width: 0.5),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kCText.withOpacity(0.85),
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
      backgroundColor: Colors.white,
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
            if (ts != null)
              _currentStartDate = (ts as dynamic).toDate() as DateTime;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            const Text(
              '커리어 카드 수정',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: kCText,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '현재 상태',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kCText,
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
                color: kCText,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _clinicCtrl,
              decoration: InputDecoration(
                hintText: _status == 'unemployed' ? '미입력 가능' : '예: 서울 ○○치과',
                filled: true,
                fillColor: const Color(0xFFF7F9F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: kCShadow, width: 0.8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: kCShadow, width: 0.8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kCAccent, width: 1.4),
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
                  color: kCText,
                ),
              ),
              const SizedBox(height: 8),
              CareerDatePickerTile(
                label:
                    _currentStartDate == null
                        ? '날짜 선택 (선택사항)'
                        : '${_currentStartDate!.year}년 ${_currentStartDate!.month}월',
                onTap: _pickStartDate,
              ),
            ],
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
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
                                color: kCText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '치과 네트워크 자동 합산 대신 직접 입력',
                              style: TextStyle(
                                fontSize: 11,
                                color: kCText.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _useOverride,
                        onChanged: (v) => setState(() => _useOverride = v),
                        activeColor: kCText,
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
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: kCShadow,
                                  width: 0.8,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: kCShadow,
                                  width: 0.8,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: kCAccent,
                                  width: 1.4,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
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
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: kCText.withOpacity(0.65),
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
                color: kCText,
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
                    selectedColor: kCAccent.withOpacity(0.25),
                    checkmarkColor: kCText,
                    side: BorderSide(color: kCShadow, width: 0.8),
                    labelStyle: TextStyle(
                      color: kCText.withOpacity(0.85),
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
                backgroundColor: kCAccent,
                foregroundColor: kCText,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              selected ? kCAccent.withOpacity(0.35) : const Color(0xFFF1F3F3),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: kCShadow, width: 0.8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? kCText : kCText.withOpacity(0.75),
          ),
        ),
      ),
    );
  }
}

