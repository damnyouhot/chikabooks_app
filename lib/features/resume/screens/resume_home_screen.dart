import 'package:flutter/material.dart';
import '../../../models/resume.dart';
import '../../../services/resume_service.dart';
import 'resume_edit_screen.dart';
import 'ocr_review_screen.dart';

// ── 디자인 상수 ──────────────────────────────────────────
const _kBg = Color(0xFFF8F6F9);
const _kText = Color(0xFF3D4A5C);
const _kBlue = Color(0xFF4A90D9);
const _kGreen = Color(0xFF4CAF50);

/// 이력서 홈 화면
///
/// - 이력서 카드 리스트 (제목 / 최근수정 / 공개상태)
/// - [새 이력서 만들기] 버튼
/// - [사진으로 자동 입력] 버튼 (OCR — 추후 연동)
class ResumeHomeScreen extends StatelessWidget {
  const ResumeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '내 이력서',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _kText,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: _kText),
      ),
      body: StreamBuilder<List<Resume>>(
        stream: ResumeService.watchMyResumes(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final resumes = snap.data ?? [];
          return _buildBody(context, resumes);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<Resume> resumes) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        // ── 상단 액션 버튼들 ──
        _ActionButton(
          icon: Icons.add_rounded,
          label: '새 이력서 만들기',
          color: _kBlue,
          onTap: () => _createNew(context),
        ),
        const SizedBox(height: 10),
              _ActionButton(
                icon: Icons.camera_alt_outlined,
                label: '사진으로 자동 입력 (OCR)',
                color: _kGreen,
                onTap: () => _openOcr(context),
              ),
        const SizedBox(height: 24),

        // ── 이력서 목록 ──
        if (resumes.isEmpty)
          _EmptyState()
        else ...[
          Text(
            '내 이력서 (${resumes.length})',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kText.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 10),
          ...resumes.map((r) => Padding(
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
    );
  }

  // ── 액션 ────────────────────────────────────────────────

  Future<void> _createNew(BuildContext context) async {
    final id = await ResumeService.createResume();
    if (id != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResumeEditScreen(resumeId: id),
        ),
      );
    }
  }

  void _openEdit(BuildContext context, String resumeId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResumeEditScreen(resumeId: resumeId),
      ),
    );
  }

  Future<void> _duplicate(BuildContext context, String resumeId) async {
    final newId = await ResumeService.duplicateResume(resumeId);
    if (newId != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이력서가 복제되었어요.')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, Resume resume) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이력서 삭제'),
        content: Text('"${resume.title}" 이력서를 삭제할까요?\n삭제하면 복구할 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (result == true) {
      await ResumeService.deleteResume(resume.id);
    }
  }

  void _openOcr(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OcrReviewScreen()),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 액션 버튼
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kText,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: _kText.withOpacity(0.3), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 이력서 카드
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kText.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목 + 메뉴
              Row(
                children: [
                  Expanded(
                    child: Text(
                      resume.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kText,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildMenu(context),
                ],
              ),
              const SizedBox(height: 8),

              // 메타 정보
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 13,
                    color: _kText.withOpacity(0.35),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    updatedText,
                    style: TextStyle(
                      fontSize: 12,
                      color: _kText.withOpacity(0.45),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _completionColor(sectionCount).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
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
                        color: _kGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '익명 기본',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _kGreen,
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
      icon: Icon(Icons.more_vert, size: 18, color: _kText.withOpacity(0.3)),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onTap();
            break;
          case 'duplicate':
            onDuplicate();
            break;
          case 'delete':
            onDelete();
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Text('편집')),
        const PopupMenuItem(value: 'duplicate', child: Text('복제')),
        const PopupMenuItem(
          value: 'delete',
          child: Text('삭제', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  int _countFilledSections() {
    int count = 0;
    if (resume.profile != null && resume.profile!.name.isNotEmpty) count++;
    if (resume.licenses.isNotEmpty) count++;
    if (resume.experiences.isNotEmpty) count++;
    if (resume.skills.isNotEmpty) count++;
    if (resume.education.isNotEmpty) count++;
    if (resume.trainings.isNotEmpty) count++;
    if (resume.attachments.isNotEmpty) count++;
    if (resume.profile?.summary.isNotEmpty == true) count++;
    return count;
  }

  Color _completionColor(int count) {
    if (count >= 6) return _kGreen;
    if (count >= 3) return Colors.orange;
    return _kText.withOpacity(0.5);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '방금 전';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${date.month}/${date.day}';
  }
}

// ═══════════════════════════════════════════════════════════
// 빈 상태
// ═══════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(
            Icons.description_outlined,
            size: 56,
            color: _kText.withOpacity(0.15),
          ),
          const SizedBox(height: 16),
          Text(
            '아직 이력서가 없어요',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _kText.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '위 버튼으로 첫 이력서를 만들어보세요!',
            style: TextStyle(
              fontSize: 13,
              color: _kText.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}

