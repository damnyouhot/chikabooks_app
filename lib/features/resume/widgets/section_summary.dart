import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../models/resume.dart';
import '../data/intro_template_catalog.dart';
import '../models/intro_template.dart';
import '../services/intro_template_recommendation_service.dart';
import 'resume_inline_underline_field.dart';
import 'resume_ocr_prompt.dart';

/// 자기소개 (프로필 summary) — 추천 템플릿·천자·이어쓰기/덮어쓰기
class SectionSummary extends StatefulWidget {
  const SectionSummary({
    super.key,
    required this.resume,
    required this.onSummaryChanged,
  });

  final Resume resume;
  final ValueChanged<String> onSummaryChanged;

  @override
  State<SectionSummary> createState() => _SectionSummaryState();
}

class _SectionSummaryState extends State<SectionSummary> {
  static const int _maxLen = 1000;

  late final TextEditingController _ctrl;
  late final VoidCallback _lengthListener;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.resume.profile?.summary ?? '');
    _lengthListener = () => setState(() {});
    _ctrl.addListener(_lengthListener);
  }

  @override
  void didUpdateWidget(SectionSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.resume.profile?.summary ?? '';
    if (oldWidget.resume.profile?.summary != next && next != _ctrl.text) {
      _ctrl.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_lengthListener);
    _ctrl.dispose();
    super.dispose();
  }

  void _applyBody(String body, {required bool append}) {
    final sep = _ctrl.text.trim().isEmpty ? '' : '\n\n';
    final combined = append ? '${_ctrl.text}$sep$body' : body;
    final trimmed =
        combined.length > _maxLen ? combined.substring(0, _maxLen) : combined;
    if (combined.length > _maxLen && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$_maxLen자까지 적용했어요. 나머지는 잘렸습니다.')));
    }
    _ctrl.value = TextEditingValue(
      text: trimmed,
      selection: TextSelection.collapsed(offset: trimmed.length),
    );
    widget.onSummaryChanged(trimmed);
  }

  Future<void> _openApplySheet(IntroTemplate t) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _applyBody(t.fullBody, append: false);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('전체 바꾸기'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _applyBody(t.fullBody, append: true);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.accent),
                  ),
                  child: const Text(
                    '기존 글 뒤에 이어 붙이기',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('취소'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAllTemplatesDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    '전체 템플릿',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: introTemplateCatalog.length,
                    itemBuilder: (_, i) {
                      final t = introTemplateCatalog[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _TemplateCard(
                          title: t.title,
                          subtitle: t.category,
                          reasonLine: null,
                          preview: t.previewSnippet(maxChars: 100),
                          onTap: () {
                            Navigator.pop(ctx);
                            _openApplySheet(t);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ranked = IntroTemplateRecommendationService.recommend(widget.resume);
    final top = ranked.length > 4 ? ranked.sublist(0, 4) : ranked;
    final more =
        ranked.length > 4 ? ranked.sublist(4) : <RankedIntroTemplate>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '지원 동기·강점·근무 태도를 3~5문장으로 적어주세요. (최대 $_maxLen자)',
            style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
          ),
          const SizedBox(height: 8),
          const ResumeOcrPrompt(),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '추천 템플릿',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: _showAllTemplatesDialog,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '전체 보기',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '스킬·경력 단계·희망 방향을 반영해 골랐어요. 카드를 탭하면 적용 방식을 고를 수 있어요.',
            style: TextStyle(fontSize: 11, color: AppColors.textDisabled),
          ),
          const SizedBox(height: 6),
          for (final r in top)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TemplateCard(
                title: r.template.title,
                subtitle: r.template.category,
                reasonLine: r.reasonLine,
                preview: r.template.previewSnippet(maxChars: 88),
                onTap: () => _openApplySheet(r.template),
              ),
            ),

          if (more.isNotEmpty) ...[
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                expandedAlignment: Alignment.centerLeft,
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                title: Text(
                  '비슷한 스타일 더 보기',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                subtitle: Text(
                  '${more.length}개 · 탭하여 펼치기',
                  style: TextStyle(fontSize: 11, color: AppColors.textDisabled),
                ),
                children: [
                  const SizedBox(height: 4),
                  for (final r in more)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TemplateCard(
                        title: r.template.title,
                        subtitle: r.template.category,
                        reasonLine: r.reasonLine,
                        preview: r.template.previewSnippet(maxChars: 88),
                        onTap: () => _openApplySheet(r.template),
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${_ctrl.text.length}/$_maxLen',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textDisabled,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton(
                onPressed: () {
                  _ctrl.clear();
                  widget.onSummaryChanged('');
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '전체 삭제',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          ResumeInlineUnderlineField(
            label: '본문',
            hint: '추천 카드를 탭해 전체 바꾸기 또는 이어 붙이기 할 수 있어요. 본인 경험에 맞게 수정해 주세요.',
            controller: _ctrl,
            maxLines: 1,
            expandHeightWithContent: true,
            minLines: 8,
            maxLength: _maxLen,
            hideCounter: true,
            labelWidth: 64,
            onChanged: widget.onSummaryChanged,
            bottomPadding: 0,
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.title,
    required this.subtitle,
    required this.preview,
    required this.onTap,
    this.reasonLine,
  });

  final String title;
  final String subtitle;
  final String? reasonLine;
  final String preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: AppColors.textDisabled),
              ),
              if (reasonLine != null && reasonLine!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '추천: $reasonLine',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
