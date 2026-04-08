import 'dart:io' show File;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/resume.dart';
import '../../../models/resume_draft.dart';
import '../../../models/resume_file.dart';
import '../../../services/resume_service.dart';
import '../../../services/resume_draft_service.dart';
import '../../../services/resume_file_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import 'resume_edit_screen.dart';
import 'ocr_review_screen.dart';
/// 이력서 홈 화면 (탭: 새로 만들기·수정하기 / 기존 파일 그대로 쓰기)
class ResumeHomeScreen extends StatefulWidget {
  const ResumeHomeScreen({super.key});

  @override
  State<ResumeHomeScreen> createState() => _ResumeHomeScreenState();
}

class _ResumeHomeScreenState extends State<ResumeHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          '내 이력서',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (kIsWeb)
            TextButton.icon(
              icon: Icon(Icons.logout, size: 16, color: AppColors.textSecondary),
              label: Text(
                '로그아웃',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) context.go('/login');
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.accent,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          tabs: const [
            Tab(text: '새로 만들기·수정하기'),
            Tab(text: '기존 파일 그대로 쓰기'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _WrittenResumeTab(),
          _UploadedFileTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 탭 1: 새로 만들기·수정하기
// ═══════════════════════════════════════════════════════════
class _WrittenResumeTab extends StatefulWidget {
  @override
  State<_WrittenResumeTab> createState() => _WrittenResumeTabState();
}

class _WrittenResumeTabState extends State<_WrittenResumeTab> {
  bool _cleaned = false;

  @override
  void initState() {
    super.initState();
    _cleanupOnce();
  }

  Future<void> _cleanupOnce() async {
    if (_cleaned) return;
    _cleaned = true;
    final count = await ResumeService.cleanupEmptyResumes();
    if (count > 0 && mounted) {
      debugPrint('🧹 빈 이력서 $count건 자동 정리됨');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Resume>>(
      stream: ResumeService.watchMyResumes(),
      builder: (context, resumeSnap) {
        if (resumeSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final resumes = resumeSnap.data ?? [];

        return StreamBuilder<List<ResumeDraft>>(
          stream: ResumeDraftService.watchMyDrafts(),
          builder: (context, draftSnap) {
            final drafts = draftSnap.data ?? [];
            return _buildWrittenBody(context, resumes, drafts);
          },
        );
      },
    );
  }

  Widget _buildWrittenBody(
    BuildContext context,
    List<Resume> resumes,
    List<ResumeDraft> drafts,
  ) {
    // 임시저장 중인 이력서는 '내 이력서' 목록에서 제외
    final draftResumeIds = drafts
        .where((d) => d.resumeId != null && d.resumeId!.isNotEmpty)
        .map((d) => d.resumeId!)
        .toSet();
    final savedResumes =
        resumes.where((r) => !draftResumeIds.contains(r.id)).toList();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 20, AppSpacing.lg, 40),
          children: [
            Center(
              child: Text(
                '이력서 작성/ 관리 기능, 공고 작성/ 관리 기능은\n'
                '추후 웹에서도 가능하게 제작됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // OCR 버튼 2열 정사각형
            Row(
              children: [
                Expanded(
                  child: _OcrTile(
                    icon: Icons.camera_alt_outlined,
                    label: '기존 이력서\n사진 올려 생성하기',
                    subtitle: '촬영 또는 보관함',
                    color: AppColors.accent,
                    onTap: () => _openOcr(context, source: OcrInputSource.photo),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _OcrTile(
                    icon: Icons.upload_file_outlined,
                    label: '기존 이력서\n파일 올려 생성하기',
                    subtitle: 'pdf · jpg · png',
                    color: AppColors.resumeEmphasis,
                    onTap: () => _openOcr(context, source: OcrInputSource.file),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ActionButton(
              icon: Icons.edit_note_rounded,
              label: '처음부터 직접 작성하기',
              color: AppColors.accent,
              onTap: () => _createNew(context),
            ),

            if (drafts.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                '임시저장 (${drafts.length})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.resumeEmphasis,
                ),
              ),
              const SizedBox(height: 8),
              ...drafts.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DraftCard(
                      draft: d,
                      onTap: () => _openDraft(context, d),
                      onDelete: () => _deleteDraft(context, d),
                    ),
                  )),
            ],

            const SizedBox(height: 24),

            if (savedResumes.isEmpty)
              _EmptyState(message: '아직 작성한 이력서가 없어요')
            else ...[
              Text(
                '내 이력서 (${savedResumes.length})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              ...savedResumes.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ResumeCard(
                      resume: r,
                      onTap: () => _openEdit(context, r.id),
                      onDuplicate: () => _duplicate(context, r.id),
                      onDelete: () => _confirmDelete(context, r),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _createNew(BuildContext context) async {
    final id = await ResumeService.createResume();
    if (id != null && context.mounted) _navigateToEdit(context, id);
  }

  void _openEdit(BuildContext context, String resumeId) =>
      _navigateToEdit(context, resumeId);

  void _openDraft(BuildContext context, ResumeDraft draft) {
    if (draft.resumeId != null && draft.resumeId!.isNotEmpty) {
      _navigateToEdit(context, draft.resumeId!);
    } else {
      _createNew(context);
    }
  }

  Future<void> _deleteDraft(BuildContext context, ResumeDraft draft) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('임시저장 삭제'),
        content: Text('"${draft.title}" 임시저장을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true) await ResumeDraftService.deleteDraft(draft.id);
  }

  Future<void> _duplicate(BuildContext context, String resumeId) async {
    await ResumeService.duplicateResume(resumeId);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('이력서가 복제되었어요.')));
    }
  }

  Future<void> _confirmDelete(BuildContext context, Resume resume) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이력서 삭제'),
        content: Text('"${resume.title}" 이력서를 삭제할까요?\n삭제하면 복구할 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true) await ResumeService.deleteResume(resume.id);
  }

  void _openOcr(BuildContext context, {OcrInputSource source = OcrInputSource.photo}) {
    if (kIsWeb) {
      context.push('/applicant/resumes/import');
    } else {
      Navigator.push(context,
          MaterialPageRoute(
            builder: (_) => OcrReviewScreen(source: source),
          ));
    }
  }

  void _navigateToEdit(BuildContext context, String resumeId) {
    if (kIsWeb) {
      context.push('/applicant/resumes/edit/$resumeId');
    } else {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => ResumeEditScreen(resumeId: resumeId)));
    }
  }
}

// ═══════════════════════════════════════════════════════════
// 탭 2: 업로드 파일
// ═══════════════════════════════════════════════════════════
class _UploadedFileTab extends StatefulWidget {
  @override
  State<_UploadedFileTab> createState() => _UploadedFileTabState();
}

class _UploadedFileTabState extends State<_UploadedFileTab> {
  bool _uploading = false;
  double _uploadProgress = 0;

  Future<void> _upload() async {
    debugPrint('🟢 [_upload] 버튼 클릭');

    try {
      final file = await ResumeFileService.pickAndUploadFile(
        onPickComplete: () {
          debugPrint('🟢 [_upload] 파일 선택 완료 → 업로드 진행바 표시');
          if (mounted) {
            setState(() {
              _uploading = true;
              _uploadProgress = 0;
            });
          }
        },
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
        onError: (msg) {
          debugPrint('🟢 [_upload] onError: $msg');
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(msg)));
          }
        },
      );

      debugPrint('🟢 [_upload] 완료 — file=${file != null ? file.id : "null"}');

      if (mounted) {
        setState(() => _uploading = false);
        if (file != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('파일이 업로드되었어요.')),
          );
        }
      }
    } catch (e, st) {
      debugPrint('🔴 [_upload] 예외: $e\n$st');
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('업로드 오류: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          children: [
            // 업로드 버튼 영역
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 20, AppSpacing.lg, 0),
              child: _uploading
                  ? _UploadProgressBar(progress: _uploadProgress)
                  : _ActionButton(
                      icon: Icons.upload_file_rounded,
                      label: '이력서 파일 업로드 (PDF · JPG · PNG)',
                      color: AppColors.accent,
                      onTap: _upload,
                    ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                '20MB 이하 PDF, JPG, PNG 파일만 지원합니다.',
                style: TextStyle(fontSize: 11, color: AppColors.textDisabled),
              ),
            ),
            const SizedBox(height: 16),

            // 파일 목록
            Expanded(
              child: StreamBuilder<List<ResumeFile>>(
                stream: ResumeFileService.watchMyFiles(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final files = snap.data ?? [];
                  if (files.isEmpty) {
                    return _EmptyState(message: '업로드한 이력서 파일이 없어요');
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, 0, AppSpacing.lg, 40),
                    itemCount: files.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) => _ResumeFileCard(
                      file: files[i],
                      onOpen: () => _openFile(context, files[i]),
                      onRename: () => _renameFile(context, files[i]),
                      onSetPrimary: () =>
                          ResumeFileService.setPrimary(files[i].id),
                      onDelete: () => _deleteFile(context, files[i]),
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

  void _openFile(BuildContext context, ResumeFile file) {
    if (kIsWeb) {
      _launchUrl(context, file.downloadUrl);
      return;
    }
    switch (file.fileType) {
      case ResumeFileType.jpg:
      case ResumeFileType.jpeg:
      case ResumeFileType.png:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _FullScreenImageViewer(
              url: file.downloadUrl,
              title: file.displayName,
            ),
          ),
        );
        break;
      case ResumeFileType.pdf:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _ResumePdfViewer(
              url: file.downloadUrl,
              title: file.displayName,
            ),
          ),
        );
        break;
      default:
        _launchUrl(context, file.downloadUrl);
    }
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파일을 열 수 없어요.')),
      );
    }
  }

  Future<void> _renameFile(BuildContext context, ResumeFile file) async {
    final ctrl = TextEditingController(text: file.displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이름 변경'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '표시 이름 입력',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('확인')),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await ResumeFileService.rename(file.id, newName);
    }
  }

  Future<void> _deleteFile(BuildContext context, ResumeFile file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('파일 삭제'),
        content: Text('"${file.displayName}" 파일을 삭제할까요?\n삭제하면 복구할 수 없어요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true) await ResumeFileService.deleteFile(file);
  }
}

// ═══════════════════════════════════════════════════════════
// 업로드 파일 카드
// ═══════════════════════════════════════════════════════════
class _ResumeFileCard extends StatelessWidget {
  final ResumeFile file;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onSetPrimary;
  final VoidCallback onDelete;

  const _ResumeFileCard({
    required this.file,
    required this.onOpen,
    required this.onRename,
    required this.onSetPrimary,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: file.isPrimary
                  ? AppColors.accent.withOpacity(0.4)
                  : AppColors.divider,
              width: file.isPrimary ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // 파일 타입 아이콘
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Text(
                    file.fileType.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _typeColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // 파일 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (file.isPrimary) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.xs),
                            ),
                            child: const Text(
                              '대표',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            file.displayName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${file.fileSizeLabel}  ·  ${_formatDate(file.createdAt)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ],
                ),
              ),

              // 메뉴
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    size: 18, color: AppColors.textDisabled),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: (v) {
                  switch (v) {
                    case 'open':      onOpen();       break;
                    case 'rename':    onRename();     break;
                    case 'primary':   onSetPrimary(); break;
                    case 'delete':    onDelete();     break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'open',    child: Text('열기')),
                  const PopupMenuItem(value: 'rename',  child: Text('이름 변경')),
                  if (!file.isPrimary)
                    const PopupMenuItem(value: 'primary', child: Text('대표로 설정')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('삭제', style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color get _typeColor {
    switch (file.fileType) {
      case ResumeFileType.pdf:  return const Color(0xFFE53935);
      case ResumeFileType.jpg:
      case ResumeFileType.jpeg:
      case ResumeFileType.png:  return const Color(0xFF1E88E5);
      default:                  return AppColors.textSecondary;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════════════════
// 업로드 진행바
// ═══════════════════════════════════════════════════════════
class _UploadProgressBar extends StatelessWidget {
  final double progress;
  const _UploadProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text(
                '업로드 중... ${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 공통 액션 버튼
// ═══════════════════════════════════════════════════════════
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textDisabled, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// OCR 정사각형 타일 버튼 (2열 배치용)
// ═══════════════════════════════════════════════════════════
class _OcrTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? subtitle;

  const _OcrTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textDisabled,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 작성형 이력서 카드
// ═══════════════════════════════════════════════════════════
class _ResumeCard extends StatelessWidget {
  final Resume resume;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _ResumeCard({
    required this.resume,
    required this.onTap,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final updatedText = _formatDate(resume.updatedAt);
    final sectionCount = _countFilledSections();

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      resume.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildMenu(context),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 13, color: AppColors.textDisabled),
                  const SizedBox(width: AppSpacing.xs),
                  Text(updatedText,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textDisabled)),
                  const SizedBox(width: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _completionColor(sectionCount).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      '$sectionCount/8 섹션',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _completionColor(sectionCount),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (resume.visibility.defaultAnonymous)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: const Text(
                        '익명 기본',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert,
          size: 18, color: AppColors.textDisabled),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onSelected: (value) {
        if (value == 'edit')      onTap();
        if (value == 'duplicate') onDuplicate();
        if (value == 'delete')    onDelete();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit',      child: Text('편집')),
        const PopupMenuItem(value: 'duplicate', child: Text('복제')),
        const PopupMenuItem(
          value: 'delete',
          child: Text('삭제', style: TextStyle(color: AppColors.error)),
        ),
      ],
    );
  }

  int _countFilledSections() {
    int count = 0;
    if (resume.profile != null && resume.profile!.name.isNotEmpty) count++;
    if (resume.licenses.isNotEmpty)    count++;
    if (resume.experiences.isNotEmpty) count++;
    if (resume.skills.isNotEmpty)      count++;
    if (resume.education.isNotEmpty)   count++;
    if (resume.trainings.isNotEmpty)   count++;
    if (resume.attachments.isNotEmpty) count++;
    if (resume.profile?.summary.isNotEmpty == true) count++;
    return count;
  }

  Color _completionColor(int count) {
    if (count >= 6) return AppColors.success;
    if (count >= 3) return AppColors.resumeEmphasis;
    return AppColors.textSecondary;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '방금 전';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1)   return '${diff.inMinutes}분 전';
    if (diff.inDays < 1)    return '${diff.inHours}시간 전';
    if (diff.inDays < 7)    return '${diff.inDays}일 전';
    return '${date.month}/${date.day}';
  }
}

// ═══════════════════════════════════════════════════════════
// 드래프트 카드
// ═══════════════════════════════════════════════════════════
class _DraftCard extends StatelessWidget {
  final ResumeDraft draft;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DraftCard({
    required this.draft,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border:
                Border.all(color: AppColors.resumeEmphasis.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.resumeEmphasis.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  Icons.edit_note,
                  color: AppColors.resumeEmphasis.withValues(alpha: 0.75),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.title.isNotEmpty ? draft.title : '제목 없음',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '임시저장됨',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.resumeEmphasis.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppColors.textDisabled),
                onPressed: onDelete,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 빈 상태
// ═══════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Icon(Icons.description_outlined,
              size: 56, color: AppColors.textDisabled),
          const SizedBox(height: AppSpacing.lg),
          Text(
            message,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 앱 전용: 전체화면 이미지 뷰어
// ═══════════════════════════════════════════════════════════
class _FullScreenImageViewer extends StatelessWidget {
  final String url;
  final String title;
  const _FullScreenImageViewer({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        child: Center(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (_, __, ___) => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined,
                      size: 48, color: Colors.white38),
                  SizedBox(height: 8),
                  Text('이미지를 불러올 수 없어요.',
                      style: TextStyle(color: Colors.white38)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 앱 전용: PDF 뷰어 (pdfx)
// ═══════════════════════════════════════════════════════════
class _ResumePdfViewer extends StatefulWidget {
  final String url;
  final String title;
  const _ResumePdfViewer({required this.url, required this.title});

  @override
  State<_ResumePdfViewer> createState() => _ResumePdfViewerState();
}

class _ResumePdfViewerState extends State<_ResumePdfViewer> {
  PdfControllerPinch? _controller;
  bool _loading = true;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final hash = widget.url.hashCode.toRadixString(16);
      final file = File('${dir.path}/resume_$hash.pdf');

      if (!await file.exists()) {
        final response = await http.get(Uri.parse(widget.url));
        if (response.statusCode == 200) {
          await file.writeAsBytes(response.bodyBytes);
        } else {
          throw Exception('다운로드 실패 (${response.statusCode})');
        }
      }

      final document = await PdfDocument.openFile(file.path);
      _controller = PdfControllerPinch(
        document: PdfDocument.openFile(file.path),
      );

      if (mounted) {
        setState(() {
          _totalPages = document.pagesCount;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          widget.title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('PDF 불러오는 중...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                'PDF를 열 수 없어요.\n$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('돌아가기'),
              ),
            ],
          ),
        ),
      );
    }

    if (_controller == null) {
      return const Center(child: Text('PDF를 불러올 수 없습니다.'));
    }

    return PdfViewPinch(
      controller: _controller!,
      onPageChanged: (page) {
        if (mounted) setState(() => _currentPage = page);
      },
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) =>
            const Center(child: CircularProgressIndicator()),
        pageLoaderBuilder: (_) =>
            const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, error) => Center(
          child: Text('오류: $error',
              style: const TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }
}
