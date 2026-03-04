import 'package:flutter/material.dart';
import '../../../models/resume.dart';

// ── 디자인 상수 ──────────────────────────────────────────
const _kBg = Color(0xFFF8F6F9);
const _kText = Color(0xFF3D4A5C);
const _kBlue = Color(0xFF4A90D9);
const _kGreen = Color(0xFF4CAF50);

/// 이력서 미리보기 화면
///
/// 탭 2개: [지원용 미리보기] / [공개용(익명) 미리보기]
class ResumePreviewScreen extends StatefulWidget {
  final Resume resume;
  final int initialTab;
  const ResumePreviewScreen({super.key, required this.resume, this.initialTab = 0});

  @override
  State<ResumePreviewScreen> createState() => _ResumePreviewScreenState();
}

class _ResumePreviewScreenState extends State<ResumePreviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.resume.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _kText,
          ),
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: _kText),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: _kBlue,
          unselectedLabelColor: _kText.withOpacity(0.4),
          indicatorColor: _kBlue,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: '지원용 미리보기'),
            Tab(text: '익명 미리보기'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildFullPreview(widget.resume, anonymous: false),
          _buildFullPreview(widget.resume, anonymous: true),
        ],
      ),
    );
  }

  Widget _buildFullPreview(Resume r, {required bool anonymous}) {
    final profile = r.profile;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── 익명 모드 안내 배너 ──
        if (anonymous)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kGreen.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.visibility_off, size: 18, color: _kGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '병원이 지원 직후 처음 보게 될 화면이에요.\n개인 식별정보(이름, 연락처)는 마스킹됩니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _kGreen.withOpacity(0.8),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // ── A. 기본정보 ──
        _PreviewSection(
          title: '기본정보',
          icon: Icons.person_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow(
                '이름',
                anonymous ? _mask(profile?.name ?? '') : (profile?.name ?? '-'),
              ),
              _infoRow(
                '연락처',
                anonymous ? '***-****-****' : (profile?.phone ?? '-'),
              ),
              _infoRow(
                '이메일',
                anonymous ? '****@****.com' : (profile?.email ?? '-'),
              ),
              _infoRow('지역', profile?.region ?? '-'),
              if (profile?.workTypes.isNotEmpty == true)
                _infoRow('희망 근무형태', profile!.workTypes.join(', ')),
              if (profile?.headline.isNotEmpty == true)
                _infoRow('한줄소개', profile!.headline),
            ],
          ),
        ),

        // ── B. 요약 ──
        if (profile?.summary.isNotEmpty == true)
          _PreviewSection(
            title: '요약',
            icon: Icons.edit_note,
            child: Text(
              profile!.summary,
              style: TextStyle(
                fontSize: 13,
                color: _kText.withOpacity(0.7),
                height: 1.6,
              ),
            ),
          ),

        // ── C. 면허/자격 ──
        if (r.licenses.isNotEmpty)
          _PreviewSection(
            title: '면허 / 자격',
            icon: Icons.verified_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: r.licenses
                  .map((l) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              l.has ? Icons.check_circle : Icons.circle_outlined,
                              size: 16,
                              color: l.has ? _kGreen : _kText.withOpacity(0.2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l.type,
                              style: TextStyle(
                                fontSize: 13,
                                color: _kText.withOpacity(l.has ? 0.8 : 0.4),
                                fontWeight:
                                    l.has ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),

        // ── D. 경력 ──
        if (r.experiences.isNotEmpty)
          _PreviewSection(
            title: '경력',
            icon: Icons.work_outline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: r.experiences.map((e) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kText.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anonymous
                            ? '${_mask(e.clinicName)} (${e.region})'
                            : '${e.clinicName} (${e.region})',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kText,
                        ),
                      ),
                      Text(
                        '${e.start} ~ ${e.end}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _kText.withOpacity(0.45),
                        ),
                      ),
                      if (e.tasks.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: e.tasks
                              .map((t) => Chip(
                                    label: Text(t,
                                        style: const TextStyle(fontSize: 10)),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    labelPadding: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                  ))
                              .toList(),
                        ),
                      ],
                      if (e.achievementsText?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          '성과: ${e.achievementsText}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _kText.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

        // ── E. 스킬 ──
        if (r.skills.isNotEmpty)
          _PreviewSection(
            title: '스킬',
            icon: Icons.auto_awesome_outlined,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: r.skills.map((s) {
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: _kBlue.withOpacity(0.15),
                    radius: 10,
                    child: Text(
                      '${s.level}',
                      style: const TextStyle(fontSize: 9, color: _kBlue),
                    ),
                  ),
                  label: Text(s.name, style: const TextStyle(fontSize: 12)),
                );
              }).toList(),
            ),
          ),

        // ── F. 학력 ──
        if (r.education.isNotEmpty)
          _PreviewSection(
            title: '학력',
            icon: Icons.school_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: r.education
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${e.school} — ${e.major}'
                          '${e.gradYear != null ? ' (${e.gradYear}년 졸업)' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: _kText.withOpacity(0.7),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),

        // ── G. 보수교육 ──
        if (r.trainings.isNotEmpty)
          _PreviewSection(
            title: '보수교육 / 세미나',
            icon: Icons.menu_book_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: r.trainings
                  .map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${t.title} · ${t.org}'
                          '${t.hours != null ? ' (${t.hours}시간)' : ''}'
                          '${t.year != null ? ' · ${t.year}' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _kText.withOpacity(0.6),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),

        // ── H. 첨부파일 ──
        if (r.attachments.isNotEmpty)
          _PreviewSection(
            title: '첨부파일',
            icon: Icons.attach_file,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: r.attachments
                  .map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.insert_drive_file_outlined,
                                size: 16, color: _kBlue.withOpacity(0.5)),
                            const SizedBox(width: 6),
                            Text(
                              '${a.title} (${a.type})',
                              style: TextStyle(
                                fontSize: 12,
                                color: _kText.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: _kText.withOpacity(0.45),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: _kText.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 마스킹 유틸 (이름: 첫 글자만 보여줌)
  String _mask(String text) {
    if (text.isEmpty) return '-';
    if (text.length <= 1) return '*';
    return '${text[0]}${'*' * (text.length - 1)}';
  }
}

// ═══════════════════════════════════════════════════════════
// 섹션 카드 래퍼
// ═══════════════════════════════════════════════════════════
class _PreviewSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _PreviewSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kText.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _kBlue.withOpacity(0.6)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

