import 'dart:typed_data';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../services/job_draft_service.dart';
import '../../../models/job_draft.dart';
import '../services/job_image_uploader.dart';
import '../utils/job_image_attach_helpers.dart';

/// 공고 자료 입력 페이지 (/post-job/input)
///
/// 3가지 입력 방식:
///   - 이미지 업로드 (공고 포스터/캡처)
///   - 텍스트 붙여넣기
///   - 기존 공고 복사
class JobInputPage extends StatefulWidget {
  const JobInputPage({super.key});

  @override
  State<JobInputPage> createState() => _JobInputPageState();
}

class _JobInputPageState extends State<JobInputPage> {
  int _selectedTab = 0; // 0: 이미지, 1: 텍스트, 2: 복사
  final List<XFile> _images = [];
  final Map<String, Uint8List> _previewCache = {};
  final _textCtrl = TextEditingController();
  bool _isLoading = false;
  bool _imageDropActive = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = 10 - _images.length;
    if (remaining <= 0) return;
    final picked = await ImagePicker().pickMultiImage(limit: remaining);
    if (picked.isEmpty) return;
    await _appendFromXFilesDirect(picked);
  }

  Future<void> _appendFromXFilesDirect(List<XFile> files) async {
    if (files.isEmpty) return;
    final remaining = 10 - _images.length;
    if (remaining <= 0) return;
    final allowed = <XFile>[];
    for (final f in files) {
      if (!isAllowedJobImageFileName(f.name)) continue;
      allowed.add(f);
      if (allowed.length >= remaining) break;
    }
    if (allowed.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '지원 이미지(jpg, png, gif, webp 등)만 추가할 수 있어요.',
              style: GoogleFonts.notoSansKr(fontSize: 14),
            ),
          ),
        );
      }
      return;
    }
    for (final f in allowed) {
      if (!_previewCache.containsKey(f.name)) {
        _previewCache[f.name] = await f.readAsBytes();
      }
    }
    setState(() {
      _images.addAll(allowed);
      if (_images.length > 10) _images.removeRange(10, _images.length);
    });
  }

  Future<void> _onImageDropDone(DropDoneDetails details) async {
    setState(() => _imageDropActive = false);
    await _appendFromXFilesDirect(flattenDropItems(details.files));
  }

  void _removeImage(int index) {
    setState(() {
      final removed = _images.removeAt(index);
      _previewCache.remove(removed.name);
    });
  }

  bool get _canProceed {
    if (_selectedTab == 0) return _images.isNotEmpty;
    if (_selectedTab == 1) return _textCtrl.text.trim().length >= 10;
    return false; // 복사탭은 목록에서 직접 선택
  }

  static String _draftSavedAtLabel(JobDraft d) {
    final t = d.updatedAt ?? d.createdAt;
    if (t == null) return '저장 시각 없음';
    return '마지막 저장 · ${DateFormat('yyyy.MM.dd HH:mm').format(t)}';
  }

  Future<void> _confirmDeleteDraft(JobDraft d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '임시저장 삭제',
          style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '"${d.displayTitle}" 초안을 삭제할까요?\n삭제 후에는 복구할 수 없어요.',
          style: GoogleFonts.notoSansKr(fontSize: 14, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('취소', style: GoogleFonts.notoSansKr(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final deleted = await JobDraftService.deleteDraft(d.id);
    if (!mounted) return;
    if (deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('삭제했어요.', style: GoogleFonts.notoSansKr()),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('삭제에 실패했어요. 다시 시도해 주세요.', style: GoogleFonts.notoSansKr()),
        ),
      );
    }
  }

  Future<void> _proceed() async {
    if (!_canProceed) return;
    setState(() => _isLoading = true);
    try {
      final isImage = _selectedTab == 0;
      List<String> imageUrls = [];

      if (isImage && _images.isNotEmpty) {
        final tempJobId = 'tmp_${const Uuid().v4()}';
        imageUrls = await JobImageUploader.uploadImages(
          jobId: tempJobId,
          images: _images,
        );
      }

      final draftId = await JobDraftService.saveDraft(
        formData: {
          if (!isImage) 'rawInputText': _textCtrl.text.trim(),
          if (isImage) 'rawImageUrls': imageUrls,
          'sourceType': isImage ? 'image' : 'text',
          'currentStep': 'input',
          'aiParseStatus': 'idle',
        },
      );
      if (!mounted || draftId == null) return;
      context.push('/post-job/edit/$draftId', extra: {
        'sourceType': isImage ? 'image' : 'text',
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장 중 오류가 발생했어요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.webPublisherPageBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildResumeDraftsBanner(),
                const SizedBox(height: 28),
                _buildTabs(),
                const SizedBox(height: 20),
                _buildContent(),
                const SizedBox(height: 28),
                _buildCta(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 재로그인 후에도 임시저장 초안으로 돌아갈 수 있게 안내
  Widget _buildResumeDraftsBanner() {
    return StreamBuilder<List<JobDraft>>(
      stream: JobDraftService.watchMyDrafts(),
      builder: (context, snap) {
        final list = snap.data ?? [];
        if (list.isEmpty) return const SizedBox.shrink();
        final recent = list.take(5).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '임시저장된 공고',
              style: GoogleFonts.notoSansKr(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '다시 작성하던 초안이 있으면 아래에서 이어갈 수 있어요.',
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            ...recent.map((d) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: AppColors.white,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => context.push('/post-job/edit/${d.id}'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          d.displayTitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.notoSansKr(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _draftSavedAtLabel(d),
                                          style: GoogleFonts.notoSansKr(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textDisabled,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 20,
                                    color: AppColors.textDisabled,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '삭제',
                          icon: Icon(
                            Icons.delete_outline,
                            size: 22,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () => _confirmDeleteDraft(d),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '공고 자료를 넣어주세요',
          style: GoogleFonts.notoSansKr(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '이미지 또는 텍스트를 넣으면 AI가 공고 초안을 만들어 드려요',
          style: GoogleFonts.notoSansKr(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    final tabs = ['이미지 업로드', '텍스트 붙여넣기', '기존 공고 복사'];
    return Row(
      children: List.generate(tabs.length, (i) {
        final selected = _selectedTab == i;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedTab = i),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selected ? AppColors.accent : AppColors.divider,
                    width: selected ? 2 : 1,
                  ),
                ),
              ),
              child: Text(
                tabs[i],
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.accent : AppColors.textSecondary,
                  letterSpacing: -0.12,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case 0:
        return _buildImageTab();
      case 1:
        return _buildTextTab();
      case 2:
        return _buildCopyTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildImageTab() {
    return DropTarget(
      onDragEntered: (_) => setState(() => _imageDropActive = true),
      onDragExited: (_) => setState(() => _imageDropActive = false),
      onDragDone: _onImageDropDone,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: _imageDropActive ? const EdgeInsets.all(6) : EdgeInsets.zero,
        decoration: BoxDecoration(
          border: Border.all(
            color: _imageDropActive ? AppColors.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '아래를 눌러 폴더에서 사진을 고르거나, 이미지 파일을 이 영역으로 끌어다 놓을 수 있어요.',
                style: GoogleFonts.notoSansKr(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              if (_images.isEmpty) ...[
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.accent.withOpacity(0.3),
                        style: BorderStyle.solid,
                      ),
                      color: AppColors.accent.withOpacity(0.03),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 40, color: AppColors.accent.withOpacity(0.5)),
                          const SizedBox(height: 8),
                          Text(
                            '공고 이미지를 올려주세요',
                            style: GoogleFonts.notoSansKr(
                              fontSize: 14,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '포스터, 캡처본, 사진 등 (최대 10장)',
                            style: GoogleFonts.notoSansKr(
                              fontSize: 12,
                              color: AppColors.textDisabled,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._images.asMap().entries.map((e) {
                      final bytes = _previewCache[e.value.name];
                      return Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: bytes != null
                                ? Image.memory(bytes, fit: BoxFit.cover)
                                : const Icon(Icons.image, color: AppColors.textDisabled),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => _removeImage(e.key),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 12, color: AppColors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                    if (_images.length < 10)
                      GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: const Icon(Icons.add, color: AppColors.textDisabled),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextTab() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '공고 내용을 그대로 붙여넣어주세요',
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textCtrl,
            maxLines: 10,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.notoSansKr(fontSize: 14, height: 1.6),
            decoration: InputDecoration(
              hintText: '기존 채용 사이트, 메신저, 문서 등에 있는\n공고 텍스트를 복사해서 붙여넣어주세요.',
              hintStyle: GoogleFonts.notoSansKr(
                fontSize: 13,
                color: AppColors.textDisabled,
                height: 1.6,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppColors.accent, width: 2),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyTab() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.divider),
      ),
      child: FutureBuilder<List<JobDraft>>(
        future: JobDraftService.fetchMyDrafts(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(strokeWidth: 2),
            ));
          }
          final drafts = (snap.data ?? []).where((d) => d.hasContent).toList();
          if (drafts.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  '복사할 수 있는 기존 공고가 없어요.\n이미지 또는 텍스트로 시작해 주세요.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    color: AppColors.textDisabled,
                    height: 1.6,
                  ),
                ),
              ),
            );
          }
          return Column(
            children: drafts.map((d) {
              return InkWell(
                onTap: () async {
                  final newId = await JobDraftService.saveDraft(
                    formData: {
                      ...d.toMap(),
                      'sourceType': 'copy',
                      'copiedFromDraftId': d.id,
                      'currentStep': 'ai_generated',
                    },
                  );
                  if (newId != null && mounted) {
                    context.push('/post-job/edit/$newId');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.divider)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.displayTitle,
                              style: GoogleFonts.notoSansKr(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (d.address.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                d.address,
                                style: GoogleFonts.notoSansKr(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(Icons.content_copy, size: 18, color: AppColors.accent.withOpacity(0.5)),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildCta() {
    return SizedBox(
      height: AppPublisher.ctaHeight,
      child: ElevatedButton(
        onPressed: (_canProceed && !_isLoading) ? _proceed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
            : Text(
                'AI 초안 생성하기',
                style: GoogleFonts.notoSansKr(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.18,
                ),
              ),
      ),
    );
  }
}
