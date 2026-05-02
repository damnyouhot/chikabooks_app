import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import 'job_applicants_page.dart';
import 'web_typography.dart';

/// 공고 관리 탭 – Firestore `jobs` 컬렉션에서 현재 유저의 공고를 조회·관리
class JobManageSection extends StatefulWidget {
  const JobManageSection({super.key});

  @override
  State<JobManageSection> createState() => _JobManageSectionState();
}

class _JobManageSectionState extends State<JobManageSection> {
  String _filter = 'all'; // all | pending | active | closed
  String? _clinicProfileId; // null = 전체

  Stream<QuerySnapshot>? _stream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _stream = null;
      return;
    }
    Query q = FirebaseFirestore.instance
        .collection('jobs')
        .where('createdBy', isEqualTo: uid);

    if (_clinicProfileId != null) {
      q = q.where('clinicProfileId', isEqualTo: _clinicProfileId);
    }

    _stream = q.orderBy('createdAt', descending: true).snapshots();
  }

  void _onClinicProfileChanged(String? profileId) {
    setState(() => _clinicProfileId = profileId);
    _initStream();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return _buildLoginRequired();
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          children: [
            const SizedBox(height: 24),
            // ── 지점 필터 ──
            _buildClinicFilter(),
            const SizedBox(height: 12),
            // ── 상태 필터 ──
            _buildFilterChips(),
            const SizedBox(height: 16),
            // ── 공고 리스트 ──
            Expanded(child: _buildJobList()),
          ],
        ),
      ),
    );
  }

  Widget _buildClinicFilter() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('clinics_accounts')
              .doc(uid)
              .collection('clinic_profiles')
              .orderBy('createdAt', descending: false)
              .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.length <= 1) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(
                Icons.local_hospital_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _clinicChip(null, '전체'),
                      ...docs.map((d) {
                        final data = d.data() as Map<String, dynamic>;
                        final name = data['clinicName'] as String? ?? '(이름 없음)';
                        return _clinicChip(d.id, name);
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _clinicChip(String? profileId, String label) {
    final selected = _clinicProfileId == profileId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _onClinicProfileChanged(profileId),
        selectedColor: AppColors.accent.withValues(alpha: 0.15),
        checkmarkColor: AppColors.accent,
        labelStyle: GoogleFonts.notoSansKr(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.accent : AppColors.textSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color:
                selected
                    ? AppColors.accent.withValues(alpha: 0.4)
                    : AppColors.divider,
          ),
        ),
        backgroundColor: AppColors.white,
      ),
    );
  }

  // ── 비로그인 상태 화면 ─────────────────────────────────
  Widget _buildLoginRequired() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.business_center_rounded,
                size: 36,
                color: AppColors.accent.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '게시자 로그인이 필요합니다',
              style: GoogleFonts.notoSansKr(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '등록한 공고를 관리하려면\n게시자 계정으로 로그인해주세요.',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansKr(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/publisher/login'),
                icon: const Icon(Icons.login, size: 18),
                label: const Text('게시자 로그인'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: GoogleFonts.notoSansKr(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.push('/publisher/signup'),
              child: Text(
                '계정이 없으신가요? 회원가입',
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  color: AppColors.accent.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 필터 칩 ──────────────────────────────────────────
  Widget _buildFilterChips() {
    const filters = [
      {'key': 'all', 'label': '전체'},
      {'key': 'pending', 'label': '검수중'},
      {'key': 'active', 'label': '게시중'},
      {'key': 'closed', 'label': '마감'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children:
            filters.map((f) {
              final key = f['key']!;
              final selected = _filter == key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f['label']!),
                  selected: selected,
                  onSelected: (_) => setState(() => _filter = key),
                  selectedColor: AppColors.accent.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.accent,
                  labelStyle: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        selected ? AppColors.accent : AppColors.textSecondary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color:
                          selected
                              ? AppColors.accent.withValues(alpha: 0.4)
                              : AppColors.divider,
                    ),
                  ),
                  backgroundColor: AppColors.white,
                ),
              );
            }).toList(),
      ),
    );
  }

  // ── 공고 리스트 ──────────────────────────────────────
  Widget _buildJobList() {
    if (_stream == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              '데이터를 불러오지 못했습니다.',
              style: WebTypo.body(color: AppColors.textSecondary),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        // 필터 적용
        final filtered =
            _filter == 'all'
                ? docs
                : docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return data['status'] == _filter;
                }).toList();

        if (filtered.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _buildJobCard(filtered[i]),
        );
      },
    );
  }

  // ── 빈 상태 ─────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.work_outline,
            size: 56,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: 16),
          Text(
            '등록된 공고가 없습니다.',
            style: WebTypo.body(color: AppColors.textSecondary, size: 15),
          ),
          const SizedBox(height: 8),
          Text(
            '\'공고 등록\' 탭에서 새 공고를 등록해보세요.',
            style: WebTypo.caption(color: AppColors.textDisabled, size: 13),
          ),
        ],
      ),
    );
  }

  // ── 공고 카드 ────────────────────────────────────────
  Widget _buildJobCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] as String? ?? 'pending';
    final title = data['title'] as String? ?? '(제목 없음)';
    final clinicName = data['clinicName'] as String? ?? '';
    final role = data['role'] as String? ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final dateStr =
        createdAt != null
            ? DateFormat('yyyy.MM.dd').format(createdAt.toDate())
            : '-';

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/publisher/jobs/${doc.id}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider, width: 0.8),
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              // 좌측: 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 상태 뱃지 + 날짜
                    Row(
                      children: [
                        _statusBadge(status),
                        const SizedBox(width: 10),
                        Text(
                          dateStr,
                          style: GoogleFonts.notoSansKr(
                            fontSize: 12,
                            color: AppColors.textDisabled,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 제목
                    Text(
                      title,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // 치과명 + 직무
                    Text(
                      [clinicName, role].where((s) => s.isNotEmpty).join(' · '),
                      style: GoogleFonts.notoSansKr(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // 우측: 액션 버튼
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _actionButton(
                    icon: Icons.people_outline,
                    label: '지원자',
                    color: AppColors.accent,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => JobApplicantsPage(
                                  jobId: doc.id,
                                  jobTitle: title,
                                ),
                          ),
                        ),
                  ),
                  const SizedBox(height: 4),
                  if (status == 'active')
                    _actionButton(
                      icon: Icons.pause_circle_outline,
                      label: '마감',
                      color: AppColors.error,
                      onTap: () => _updateStatus(doc.id, 'closed'),
                    ),
                  if (status == 'closed')
                    _actionButton(
                      icon: Icons.refresh,
                      label: '재게시',
                      color: AppColors.success,
                      onTap: () => _updateStatus(doc.id, 'pending'),
                    ),
                  if (status == 'pending')
                    _actionButton(
                      icon: Icons.hourglass_top,
                      label: '대기중',
                      color: AppColors.textDisabled,
                      onTap: null,
                    ),
                  const SizedBox(height: 4),
                  _actionButton(
                    icon: Icons.delete_outline,
                    label: '삭제',
                    color: AppColors.error.withValues(alpha: 0.6),
                    onTap: () => _confirmDelete(doc.id, title),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 상태 뱃지 ────────────────────────────────────────
  Widget _statusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'active':
        bg = AppColors.success.withValues(alpha: 0.15);
        fg = AppColors.success;
        label = '게시중';
        break;
      case 'closed':
        bg = AppColors.textDisabled.withValues(alpha: 0.15);
        fg = AppColors.textDisabled;
        label = '마감';
        break;
      case 'pending':
      default:
        bg = AppColors.accent.withValues(alpha: 0.12);
        fg = AppColors.accent;
        label = '검수중';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.notoSansKr(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  // ── 액션 버튼 ────────────────────────────────────────
  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.notoSansKr(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 상태 변경 ────────────────────────────────────────
  Future<void> _updateStatus(String docId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('jobs').doc(docId).update({
        'status': newStatus,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('상태 변경 실패: $e')));
      }
    }
  }

  // ── 삭제 확인 ────────────────────────────────────────
  Future<void> _confirmDelete(String docId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AppConfirmModal(
            title: '공고 삭제',
            message: '"$title" 공고를 삭제하시겠습니까?\n삭제 후 복구할 수 없습니다.',
            confirmLabel: '삭제',
            destructive: true,
          ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('jobs').doc(docId).delete();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
        }
      }
    }
  }
}
