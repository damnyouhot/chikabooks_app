import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart' show AppRadius, AppSpacing;
import '../../../models/clinic_profile.dart';
import '../../jobs/web/web_typography.dart';
import '../../publisher/services/clinic_profile_service.dart';
import '../providers/me_providers.dart';
import '../widgets/me_page_shell.dart';

/// /me/clinic — 병원(지점) 정보 관리 페이지
///
/// 다지점을 지원하는 핵심 화면. 카드 그리드로 모든 지점을 보여주고
/// 추가·수정·인증 진입점을 제공한다.
///
/// 차별 포인트(타사 대비):
///  - 1 계정 N 지점을 단일 화면에서 운영 (대부분 경쟁사는 1계정 1치과)
///  - 노출명(displayName)과 공식 상호(clinicName) 분리로
///    구직자 친화적 표기 + 회계/세금계산서 정확도 동시 확보
///  - 각 지점별로 사업자 인증 상태 별도 표시(체인은 지점마다 사업자번호 다름)
class MeClinicPage extends ConsumerStatefulWidget {
  const MeClinicPage({super.key});

  @override
  ConsumerState<MeClinicPage> createState() => _MeClinicPageState();
}

class _MeClinicPageState extends ConsumerState<MeClinicPage> {
  bool _creating = false;

  Future<void> _addBranch() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final id = await ClinicProfileService.createProfile();
      if (!mounted) return;
      if (id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('지점 추가에 실패했습니다. 잠시 후 다시 시도해주세요.')),
        );
        return;
      }
      ref.read(meActiveBranchProvider.notifier).set(id);
      _openEditor(id, isNew: true);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _openEditor(String profileId, {bool isNew = false}) async {
    final profile = await ClinicProfileService.getProfile(profileId);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _EditBranchDialog(initial: profile, isNew: isNew),
    );
  }

  Future<bool?> _showImpactConfirmDialog({
    required String title,
    required String message,
    required String detail,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.35),
                    ),
                  ),
                  child: Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.white,
                ),
                child: Text(confirmLabel),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteBranch(ClinicProfile profile) async {
    final ok = await _showImpactConfirmDialog(
      title: '병원 정보를 삭제할까요?',
      message:
          '"${profile.effectiveName.isEmpty ? '이름 없음' : profile.effectiveName}" 병원 정보를 삭제합니다.',
      detail:
          '이 병원으로 작성 중인 공고와 이미 올린 공고의 인증 연결이 영향을 받을 수 있어요. '
          '삭제 후에는 게시·수정 전에 병원 정보를 다시 선택하고 사업자 인증을 다시 받아야 합니다.',
      confirmLabel: '삭제하기',
    );
    if (ok != true || !mounted) return;

    final deleted = await ClinicProfileService.deleteProfile(profile.id);
    if (!mounted) return;
    if (!deleted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('병원 정보 삭제에 실패했습니다.')));
      return;
    }
    if (ref.read(meActiveBranchProvider) == profile.id) {
      ref.read(meActiveBranchProvider.notifier).set(null);
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('병원 정보를 삭제했습니다.')));
  }

  Future<void> _clearBusinessVerification(ClinicProfile profile) async {
    final ok = await _showImpactConfirmDialog(
      title: '사업자 인증 정보를 삭제할까요?',
      message:
          '"${profile.effectiveName.isEmpty ? '이름 없음' : profile.effectiveName}"의 사업자 인증 정보를 삭제합니다.',
      detail:
          '작성 중인 공고와 이미 올린 공고가 이 인증 상태를 참조합니다. '
          '삭제하면 게시 가능 상태가 해제되고, 게시·수정 전에 사업자등록증을 다시 올려 재인증해야 합니다.',
      confirmLabel: '인증 삭제',
    );
    if (ok != true || !mounted) return;

    final cleared = await ClinicProfileService.clearBusinessVerification(
      profile.id,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(cleared ? '사업자 인증 정보를 삭제했습니다.' : '인증 정보 삭제에 실패했습니다.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncProfiles = ref.watch(clinicProfilesProvider);

    return MePageShell(
      title: '병원 정보',
      activeMenuId: 'clinic',
      child: asyncProfiles.when(
        loading:
            () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            ),
        error: (error, _) => _LoadErrorState(error: error),
        data:
            (profiles) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _IntroPanel(branchCount: profiles.length),
                const SizedBox(height: AppSpacing.lg),
                _AddBranchButton(
                  onPressed: _creating ? null : _addBranch,
                  loading: _creating,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (profiles.isEmpty)
                  _EmptyState(onAdd: _creating ? null : _addBranch)
                else
                  _BranchGrid(
                    profiles: profiles,
                    onEdit: (id) => _openEditor(id),
                    onDelete: _deleteBranch,
                    onClearBusinessVerification: _clearBusinessVerification,
                  ),
              ],
            ),
      ),
    );
  }
}

// ── 안내 패널 ───────────────────────────────────────────
class _IntroPanel extends StatelessWidget {
  const _IntroPanel({required this.branchCount});

  final int branchCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardPrimary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_hospital_outlined,
            color: AppColors.onCardPrimary,
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '등록된 지점 $branchCount곳',
                  style: WebTypo.sectionTitle(color: AppColors.onCardPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  '여러 지점을 운영하시면 지점별로 사업자등록번호와 공고를 따로 관리할 수 있습니다.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppColors.onCardPrimary.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 지점 추가 버튼 ──────────────────────────────────────
class _AddBranchButton extends StatelessWidget {
  const _AddBranchButton({required this.onPressed, required this.loading});

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon:
            loading
                ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : const Icon(Icons.add, size: 18),
        label: Text(loading ? '지점 추가 중...' : '지점 추가하기'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          foregroundColor: AppColors.accent,
          side: BorderSide(color: AppColors.accent.withOpacity(0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}

// ── 지점 카드 그리드 ────────────────────────────────────
class _BranchGrid extends ConsumerWidget {
  const _BranchGrid({
    required this.profiles,
    required this.onEdit,
    required this.onDelete,
    required this.onClearBusinessVerification,
  });

  final List<ClinicProfile> profiles;
  final void Function(String id) onEdit;
  final ValueChanged<ClinicProfile> onDelete;
  final ValueChanged<ClinicProfile> onClearBusinessVerification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 활성 지점 강조: 다지점 운영자가 헤더 드롭다운에서 특정 지점을 골랐을 때만
    // 의미가 있다 ('전체 합산' = null 이거나 1지점이면 강조 없음).
    final activeBranchId = ref.watch(meActiveBranchProvider);
    final highlightActive = profiles.length > 1 && activeBranchId != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards =
            profiles
                .map(
                  (p) => _BranchCard(
                    profile: p,
                    onEdit: () => onEdit(p.id),
                    onDelete: () => onDelete(p),
                    onClearBusinessVerification:
                        () => onClearBusinessVerification(p),
                    isActive: highlightActive && p.id == activeBranchId,
                  ),
                )
                .toList();
        // [옵션 A] 지점 1개면 풀폭 1-column. 2개 이상 + wide(>=640) 면 2-column.
        // 그 외는 1-column.
        final useTwoColumn = cards.length >= 2 && constraints.maxWidth >= 640;
        if (!useTwoColumn) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.md),
                cards[i],
              ],
            ],
          );
        }
        const gap = AppSpacing.md;
        final rows = <Widget>[];
        for (var i = 0; i < cards.length; i += 2) {
          final left = cards[i];
          final right = i + 1 < cards.length ? cards[i + 1] : null;
          if (i > 0) rows.add(const SizedBox(height: gap));
          // IntrinsicHeight 미사용 (Spacer 가 있는 카드는 dryLayout fail).
          // crossAxisAlignment.start 로 카드 높이 차이 허용.
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: gap),
                Expanded(child: right ?? const SizedBox.shrink()),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({
    required this.profile,
    required this.onEdit,
    required this.onDelete,
    required this.onClearBusinessVerification,
    required this.isActive,
  });

  final ClinicProfile profile;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClearBusinessVerification;

  /// 헤더 "보기 기준" 드롭다운에서 이 지점이 선택돼 있을 때 true.
  /// (다지점 + 특정 지점 선택 상황에서만 true; 1지점/전체합산 모드에선 항상 false)
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isActive ? AppColors.accent : AppColors.divider,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow:
            isActive
                ? [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isActive) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.visibility_outlined,
                    size: 11,
                    color: AppColors.accent,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '지금 보고 있는 지점',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.effectiveName.isNotEmpty
                          ? profile.effectiveName
                          : '이름 없음',
                      style: WebTypo.sectionTitle(color: AppColors.textPrimary),
                    ),
                    if (profile.displayName.isNotEmpty &&
                        profile.clinicName.isNotEmpty &&
                        profile.displayName != profile.clinicName) ...[
                      const SizedBox(height: 4),
                      Text(
                        '공식 상호: ${profile.clinicName}',
                        style: WebTypo.caption(
                          color: AppColors.textSecondary,
                          size: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _VerifyBadge(status: profile.businessVerification.status),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (profile.address.isNotEmpty)
            _MetaRow(icon: Icons.place_outlined, text: profile.address),
          if (profile.phone.isNotEmpty)
            _MetaRow(icon: Icons.phone_outlined, text: profile.phone),
          if (profile.ownerName.isNotEmpty)
            _MetaRow(
              icon: Icons.person_outline,
              text: '대표 ${profile.ownerName}',
            ),
          if (profile.address.isEmpty &&
              profile.phone.isEmpty &&
              profile.ownerName.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '아직 주소·연락처가 비어 있어요. 정보를 채워주세요.',
                style: WebTypo.caption(
                  color: AppColors.textSecondary,
                  size: 12,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('수정'),
              ),
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('삭제'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withOpacity(0.45)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onClearBusinessVerification,
                icon: const Icon(Icons.gpp_maybe_outlined, size: 16),
                label: const Text('인증 삭제'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withOpacity(0.45)),
                ),
              ),
              if (!profile.canPublishJobs)
                FilledButton.icon(
                  onPressed: () => context.go('/me/verify'),
                  icon: const Icon(Icons.verified_outlined, size: 16),
                  label: const Text('인증하기'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
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

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: WebTypo.body(
                color: AppColors.textPrimary,
              ).copyWith(fontSize: 12.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifyBadge extends StatelessWidget {
  const _VerifyBadge({required this.status});

  final BizVerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      BizVerificationStatus.verified => (
        '인증 완료',
        AppColors.success,
        Icons.verified,
      ),
      BizVerificationStatus.provisional => (
        '조건부 승인',
        AppColors.accent,
        Icons.task_alt_outlined,
      ),
      BizVerificationStatus.pendingAuto => (
        '인증 진행중',
        AppColors.warning,
        Icons.hourglass_bottom_outlined,
      ),
      BizVerificationStatus.manualReview => (
        '운영팀 검토중',
        AppColors.warning,
        Icons.support_agent_outlined,
      ),
      BizVerificationStatus.rejected => (
        '인증 거절',
        AppColors.error,
        Icons.error_outline,
      ),
      BizVerificationStatus.none => (
        '미인증',
        AppColors.textSecondary,
        Icons.shield_outlined,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 빈 상태 ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 28),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(
            Icons.local_hospital_outlined,
            size: 40,
            color: AppColors.textSecondary.withOpacity(0.6),
          ),
          const SizedBox(height: 12),
          Text(
            '아직 등록된 지점이 없어요',
            style: WebTypo.sectionTitle(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            '첫 번째 지점을 등록하고 인증을 완료하면 공고를 발행할 수 있습니다.',
            style: WebTypo.caption(color: AppColors.textSecondary, size: 12.5),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('첫 지점 등록'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 로드 에러 상태 (권한 거부 / 네트워크) ───────────────
class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({required this.error});

  final Object error;

  bool get _isPermissionDenied {
    final msg = error.toString().toLowerCase();
    return msg.contains('permission-denied') ||
        msg.contains('insufficient permissions');
  }

  @override
  Widget build(BuildContext context) {
    final permission = _isPermissionDenied;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 36,
            color: AppColors.textSecondary.withOpacity(0.7),
          ),
          const SizedBox(height: 10),
          Text(
            permission ? '병원 정보를 불러올 권한이 없습니다' : '병원 정보를 불러오지 못했습니다',
            style: WebTypo.sectionTitle(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            permission
                ? '잠시 후 다시 시도해 주세요. 같은 증상이 반복되면 운영팀에 문의해 주세요.'
                : '네트워크 상태를 확인한 뒤 페이지를 새로고침해 주세요.',
            textAlign: TextAlign.center,
            style: WebTypo.caption(color: AppColors.textSecondary, size: 12.5),
          ),
          const SizedBox(height: 12),
          SelectableText(
            error.toString(),
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary.withOpacity(0.7),
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── 지점 수정 다이얼로그 ────────────────────────────────
class _EditBranchDialog extends StatefulWidget {
  const _EditBranchDialog({required this.initial, required this.isNew});

  final ClinicProfile? initial;
  final bool isNew;

  @override
  State<_EditBranchDialog> createState() => _EditBranchDialogState();
}

class _EditBranchDialogState extends State<_EditBranchDialog> {
  late final TextEditingController _displayName;
  late final TextEditingController _clinicName;
  late final TextEditingController _address;
  late final TextEditingController _ownerName;
  late final TextEditingController _phone;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _displayName = TextEditingController(text: p?.displayName ?? '');
    _clinicName = TextEditingController(text: p?.clinicName ?? '');
    _address = TextEditingController(text: p?.address ?? '');
    _ownerName = TextEditingController(text: p?.ownerName ?? '');
    _phone = TextEditingController(text: p?.phone ?? '');
  }

  @override
  void dispose() {
    _displayName.dispose();
    _clinicName.dispose();
    _address.dispose();
    _ownerName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = widget.initial?.id;
    if (id == null) return;
    setState(() => _saving = true);
    final ok = await ClinicProfileService.updateProfile(
      id,
      displayName: _displayName.text.trim(),
      clinicName: _clinicName.text.trim(),
      address: _address.text.trim(),
      ownerName: _ownerName.text.trim(),
      phone: _phone.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('지점 정보를 저장했습니다.')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('저장에 실패했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isNew ? '새 지점 정보 입력' : '지점 정보 수정'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Field(
                label: '노출명 (구직자에게 보일 이름)',
                controller: _displayName,
                hint: '예: 미소가득 치과 강남점',
              ),
              const SizedBox(height: 12),
              _Field(
                label: '공식 상호 (사업자등록증 기준)',
                controller: _clinicName,
                hint: '예: 의료법인 미소가득의료재단 미소가득치과의원',
              ),
              const SizedBox(height: 12),
              _Field(label: '주소', controller: _address, hint: '서울특별시 강남구 ...'),
              const SizedBox(height: 12),
              _Field(label: '대표자명', controller: _ownerName),
              const SizedBox(height: 12),
              _Field(
                label: '대표 연락처',
                controller: _phone,
                hint: '02-1234-5678',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              Text(
                '※ 노출명과 공식 상호를 분리해서 관리할 수 있습니다.\n'
                '   노출명만 비워두면 공식 상호로 표시됩니다.',
                style: WebTypo.caption(
                  color: AppColors.textSecondary,
                  size: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.white,
          ),
          child: Text(_saving ? '저장 중...' : '저장'),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }
}
