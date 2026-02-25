import 'package:flutter/material.dart';
import '../../services/career_profile_service.dart';
import 'career_shared.dart';

// ── 치과 네트워크 카드 ─────────────────────────────────────────
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '나의 치과 네트워크',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: kCText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '불러오는 중...',
                  style: TextStyle(
                    fontSize: 12,
                    color: kCText.withOpacity(0.45),
                  ),
                ),
              ],
            ),
          );
        }
        if (snap.hasError) {
          return CareerErrorCard(message: '치과 네트워크를 불러오지 못했어요.');
        }

        final entries = snap.data ?? [];
        final totalClinics = entries.length;
        final totalMonths = entries.fold(0, (sum, e) => sum + e.months);
        final maxMonths =
            entries.isEmpty
                ? 1
                : entries.map((e) => e.months).reduce((a, b) => a > b ? a : b);

        return CareerCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '나의 치과 네트워크',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: kCText,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => DentalNetworkEditSheet.show(context),
                        icon: const Icon(Icons.add, size: 18),
                        color: kCText.withOpacity(0.65),
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
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kCText.withOpacity(0.65),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: kCText.withOpacity(0.6),
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
                        ? '아직 이력이 없어요  ·  탭해서 추가하기'
                        : '총 $totalClinics곳 · 총 ${formatCareerMonths(totalMonths)}',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          totalClinics == 0
                              ? kCAccent.withOpacity(0.8)
                              : kCText.withOpacity(0.65),
                    ),
                  ),
                ),
              ),
              AnimatedCrossFade(
                crossFadeState:
                    _expanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
                firstChild: const SizedBox(height: 0),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child:
                      entries.isEmpty
                          ? _NetworkEmptyHint(
                            onAdd: () => DentalNetworkEditSheet.show(context),
                          )
                          : Column(
                            children:
                                entries
                                    .map(
                                      (e) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: _NetworkTimelineItem(
                                          entry: e,
                                          maxMonths: maxMonths,
                                          onEdit:
                                              () => DentalNetworkEditSheet.show(
                                                context,
                                                editing: e,
                                              ),
                                          onDelete:
                                              () => _confirmDelete(context, e),
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
      builder:
          (ctx) => AlertDialog(
            title: const Text('삭제하시겠어요?'),
            content: Text('"${entry.clinicName}" 이력을 삭제합니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('삭제', style: TextStyle(color: Colors.red)),
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
        color: const Color(0xFFF1F3F3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 46,
            decoration: BoxDecoration(
              color: kCAccent,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '아직 이력이 없어요.\n첫 근무지를 추가하면 타임라인이 만들어져요.',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: kCText.withOpacity(0.75),
              ),
            ),
          ),
          TextButton(onPressed: onAdd, child: const Text('추가하기')),
        ],
      ),
    );
  }
}

class _NetworkTimelineItem extends StatelessWidget {
  final DentalNetworkEntry entry;
  final int maxMonths;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NetworkTimelineItem({
    required this.entry,
    required this.maxMonths,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const double kMaxBarH = 110;
    const double kMinBarH = 28;
    final barHeight =
        kMinBarH + (kMaxBarH - kMinBarH) * (entry.months / maxMonths);

    return Container(
      decoration: BoxDecoration(
        color:
            entry.isCurrent
                ? kCAccent.withOpacity(0.1)
                : const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              entry.isCurrent ? kCAccent.withOpacity(0.5) : Colors.transparent,
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7,
            height: barHeight,
            margin: const EdgeInsets.only(top: 2, right: 12),
            decoration: BoxDecoration(
              color: entry.isCurrent ? kCAccent : kCAccent.withOpacity(0.45),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.periodLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: kCText.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.clinicName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: kCText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatCareerMonths(entry.months),
                  style: TextStyle(
                    fontSize: 12,
                    color: kCText.withOpacity(0.6),
                  ),
                ),
                if (entry.tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children:
                        entry.tags
                            .map(
                              (t) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: kCAccent.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  t,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: kCText,
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
                    children:
                        entry.acquiredSkills
                            .map(
                              (s) => Text(
                                '$s +1',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: kCText.withOpacity(0.5),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ],
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                color: kCText.withOpacity(0.55),
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                padding: EdgeInsets.zero,
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 16),
                color: Colors.redAccent.withOpacity(0.7),
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 치과 네트워크 편집 시트 ────────────────────────────────────
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
    return _DentalNetworkListSheet();
  }
}

class _DentalNetworkListSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: kCShadow,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '치과 네트워크',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: kCText,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
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
                    backgroundColor: kCText,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
                        children: [
                          Icon(
                            Icons.business_outlined,
                            size: 48,
                            color: kCText.withOpacity(0.2),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '아직 등록된 치과가 없어요.\n오른쪽 위 추가 버튼을 눌러보세요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: kCText.withOpacity(0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    return Container(
                      decoration: BoxDecoration(
                        color:
                            e.isCurrent
                                ? kCAccent.withOpacity(0.1)
                                : const Color(0xFFF6F6F6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              e.isCurrent
                                  ? kCAccent.withOpacity(0.5)
                                  : Colors.transparent,
                          width: 0.8,
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.clinicName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: kCText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${e.periodLabel}  ·  ${formatCareerMonths(e.months)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: kCText.withOpacity(0.55),
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
                                    (_) => _DentalEntryFormSheet(editing: e),
                              );
                            },
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            color: kCText.withOpacity(0.6),
                          ),
                          IconButton(
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder:
                                    (ctx) => AlertDialog(
                                      title: const Text('삭제하시겠어요?'),
                                      content: Text(
                                        '"${e.clinicName}" 이력을 삭제합니다.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.of(ctx).pop(false),
                                          child: const Text('취소'),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () => Navigator.of(ctx).pop(true),
                                          child: const Text(
                                            '삭제',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                              );
                              if (ok == true) {
                                await CareerProfileService.deleteNetworkEntry(
                                  e.id,
                                );
                              }
                            },
                            icon: const Icon(Icons.delete_outline, size: 18),
                            color: Colors.redAccent.withOpacity(0.65),
                          ),
                        ],
                      ),
                    );
                  },
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('치과 이름을 입력해 주세요.')));
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
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: kCShadow,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isEdit ? '이력 수정' : '치과 이력 추가',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: kCText,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '치과 이름',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kCText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _clinicCtrl,
                    decoration: InputDecoration(
                      hintText: '예) 서울 ○○치과',
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '입사 연월',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kCText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  CareerDatePickerTile(
                    label: '${_startDate.year}년 ${_startDate.month}월',
                    onTap: () => _pickDate(isStart: true),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: _isCurrent,
                        onChanged:
                            (v) => setState(() => _isCurrent = v ?? true),
                        activeColor: kCText,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const Text(
                        '현재 재직 중',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kCText,
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
                        color: kCText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CareerDatePickerTile(
                      label:
                          _endDate == null
                              ? '날짜 선택'
                              : '${_endDate!.year}년 ${_endDate!.month}월',
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    '주요 업무 태그',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kCText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children:
                        _kTagOptions
                            .map(
                              (t) => FilterChip(
                                label: Text(t),
                                selected: _tags.contains(t),
                                onSelected:
                                    (v) => setState(() {
                                      if (v) {
                                        _tags.add(t);
                                      } else {
                                        _tags.remove(t);
                                      }
                                    }),
                                selectedColor: kCAccent.withOpacity(0.35),
                                checkmarkColor: kCText,
                                backgroundColor: const Color(0xFFF1F3F3),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      _tags.contains(t)
                                          ? kCText
                                          : kCText.withOpacity(0.6),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                side: BorderSide.none,
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '이 기간에 성장한 스킬',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kCText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children:
                        _kTagOptions
                            .map(
                              (t) => FilterChip(
                                label: Text(t),
                                selected: _acquiredSkills.contains(t),
                                onSelected:
                                    (v) => setState(() {
                                      if (v) {
                                        _acquiredSkills.add(t);
                                      } else {
                                        _acquiredSkills.remove(t);
                                      }
                                    }),
                                selectedColor: kCShadow.withOpacity(0.6),
                                checkmarkColor: kCText,
                                backgroundColor: const Color(0xFFF1F3F3),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      _acquiredSkills.contains(t)
                                          ? kCText
                                          : kCText.withOpacity(0.6),
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
                        backgroundColor: kCText,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child:
                          _saving
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
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

