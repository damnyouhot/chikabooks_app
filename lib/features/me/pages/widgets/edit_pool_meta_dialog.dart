import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart' show AppRadius, AppSpacing;
import '../../../../core/widgets/app_modal_scaffold.dart';
import '../../../../models/applicant_pool_entry.dart';

class EditPoolMetaResult {
  final String displayName;
  final String memo;
  final List<String> tags;
  final String status;

  const EditPoolMetaResult({
    required this.displayName,
    required this.memo,
    required this.tags,
    required this.status,
  });
}

/// 메모/태그/상태/표시이름 편집 다이얼로그
class EditPoolMetaDialog extends StatefulWidget {
  const EditPoolMetaDialog({super.key, required this.initial});
  final JoinedApplicant initial;

  @override
  State<EditPoolMetaDialog> createState() => _EditPoolMetaDialogState();
}

class _EditPoolMetaDialogState extends State<EditPoolMetaDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _memoCtrl;
  late final TextEditingController _tagInputCtrl;
  late List<String> _tags;
  late String _status;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial.displayName);
    _memoCtrl = TextEditingController(text: widget.initial.memo);
    _tagInputCtrl = TextEditingController();
    _tags = List<String>.from(widget.initial.tags);
    _status = widget.initial.status;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _memoCtrl.dispose();
    _tagInputCtrl.dispose();
    super.dispose();
  }

  void _addTag() {
    final v = _tagInputCtrl.text.trim();
    if (v.isEmpty) return;
    if (_tags.contains(v)) return;
    setState(() {
      _tags.add(v);
      _tagInputCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppModalDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '지원자 정보 편집',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '표시 이름 (운영자 메모용)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: '상태',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: kApplicantStatusOrder
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(kApplicantStatusLabels[s] ?? s),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _status = v ?? 'new'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tagInputCtrl,
                          decoration: const InputDecoration(
                            labelText: '태그 추가 (Enter)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _addTag(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                          onPressed: _addTag, child: const Text('추가')),
                    ],
                  ),
                  if (_tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _tags
                          .map((t) => InputChip(
                                label: Text('#$t'),
                                onDeleted: () =>
                                    setState(() => _tags.remove(t)),
                                backgroundColor: AppColors.accent
                                    .withValues(alpha: 0.08),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.full),
                                  side: BorderSide(
                                      color: AppColors.accent
                                          .withValues(alpha: 0.3)),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _memoCtrl,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: '메모 (이 지원자에 대한 운영자 노트)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  backgroundColor: AppColors.surfaceMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('취소'),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  EditPoolMetaResult(
                    displayName: _nameCtrl.text.trim(),
                    memo: _memoCtrl.text.trim(),
                    tags: _tags,
                    status: _status,
                  ),
                ),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent),
                child: const Text('저장'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
