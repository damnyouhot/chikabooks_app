import 'package:flutter/material.dart';
import '../../../models/resume.dart';

const _kText = Color(0xFF3D4A5C);
const _kBlue = Color(0xFF4A90D9);

/// H. 첨부파일 섹션
class SectionAttachments extends StatefulWidget {
  final List<ResumeAttachment> attachments;
  final ValueChanged<List<ResumeAttachment>> onChanged;

  const SectionAttachments({
    super.key,
    required this.attachments,
    required this.onChanged,
  });

  @override
  State<SectionAttachments> createState() => _SectionAttachmentsState();
}

class _SectionAttachmentsState extends State<SectionAttachments> {
  late List<ResumeAttachment> _items;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.attachments);
  }

  void _add() {
    // TODO: 파일 업로드 구현 (Firebase Storage)
    // 현재는 플레이스홀더로 빈 항목 추가
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('파일 업로드는 추후 구현됩니다. 제목과 타입만 먼저 입력해주세요.'),
      ),
    );
    setState(() => _items.add(const ResumeAttachment()));
    widget.onChanged(_items);
  }

  void _removeAt(int i) {
    setState(() => _items.removeAt(i));
    widget.onChanged(_items);
  }

  void _updateAt(int i, ResumeAttachment updated) {
    setState(() => _items[i] = updated);
    widget.onChanged(_items);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        const Text(
          '첨부파일',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _kText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '자격증, 수료증, 경력증명서 등을 첨부해주세요.',
          style: TextStyle(fontSize: 12, color: _kText.withOpacity(0.4)),
        ),
        const SizedBox(height: 16),

        if (_items.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 48,
                  color: _kText.withOpacity(0.15),
                ),
                const SizedBox(height: 12),
                Text(
                  '아직 첨부파일이 없어요',
                  style: TextStyle(
                    fontSize: 14,
                    color: _kText.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),

        ...List.generate(_items.length, (i) => _AttachmentCard(
              index: i,
              item: _items[i],
              onUpdate: (a) => _updateAt(i, a),
              onRemove: () => _removeAt(i),
            )),

        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.attach_file, size: 18),
          label: const Text('파일 추가'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _kBlue,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _AttachmentCard extends StatefulWidget {
  final int index;
  final ResumeAttachment item;
  final ValueChanged<ResumeAttachment> onUpdate;
  final VoidCallback onRemove;

  const _AttachmentCard({
    required this.index,
    required this.item,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  State<_AttachmentCard> createState() => _AttachmentCardState();
}

class _AttachmentCardState extends State<_AttachmentCard> {
  late TextEditingController _titleCtrl;
  String _type = '';

  static const _typeOptions = [
    '자격증',
    '수료증',
    '경력증명서',
    '포트폴리오',
    '기타',
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.item.title);
    _type = widget.item.type.isEmpty ? _typeOptions[0] : widget.item.type;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onUpdate(ResumeAttachment(
      fileRef: widget.item.fileRef,
      type: _type,
      title: _titleCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              color: _kBlue.withOpacity(0.5),
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleCtrl,
                    onChanged: (_) => _emit(),
                    decoration: InputDecoration(
                      hintText: '파일 제목',
                      hintStyle: TextStyle(color: _kText.withOpacity(0.25)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(fontSize: 13, color: _kText),
                  ),
                  const SizedBox(height: 4),
                  DropdownButton<String>(
                    value: _type,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    style: TextStyle(fontSize: 11, color: _kText.withOpacity(0.5)),
                    items: _typeOptions
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _type = v ?? _typeOptions[0]);
                      _emit();
                    },
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              color: Colors.red.withOpacity(0.5),
              onPressed: widget.onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

