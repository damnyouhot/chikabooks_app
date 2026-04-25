import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart' show AppRadius, AppSpacing;
import '../../../models/clinic_profile.dart';
import '../../jobs/web/web_typography.dart';
import '../providers/me_providers.dart';
import '../widgets/me_page_shell.dart';

/// /me/verify — 사업자 인증 현황 페이지
///
/// 모든 지점의 사업자 인증 상태를 한 번에 확인하고,
/// 미인증/거절 지점은 기존 `/clinic-verify` 플로우로 진입할 수 있다.
///
/// 차별 포인트(타사 대비):
///  - 5단계 검증 (사업자번호 → OCR → 국세청 → 심평원 → 운영팀 검토) 가시화
///  - 거절 사유와 다음 액션을 명확히 제시
///  - 다지점 동시 인증 진행 상황을 한 화면에서 추적
class MeVerificationPage extends ConsumerWidget {
  const MeVerificationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfiles = ref.watch(clinicProfilesProvider);

    return MePageShell(
      title: '사업자 인증',
      activeMenuId: 'verify',
      hideBranchSwitcher: true,
      child: asyncProfiles.when(
        loading:
            () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            ),
        error:
            (error, _) => Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                '인증 현황을 불러오지 못했습니다: $error',
                style: WebTypo.caption(color: AppColors.error, size: 12),
              ),
            ),
        data:
            (profiles) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _PageNotice(),
                const SizedBox(height: AppSpacing.lg),
                _SummaryPanel(profiles: profiles),
                const SizedBox(height: AppSpacing.xxl),
                const _StepperLegend(),
                const SizedBox(height: AppSpacing.xxl),
                if (profiles.isEmpty)
                  _EmptyHint(onAddBranch: () => context.go('/me/clinic'))
                else
                  _VerificationCardGrid(profiles: profiles),
              ],
            ),
      ),
    );
  }
}

// ── 상단 요약 ──────────────────────────────────────────
class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.profiles});

  final List<ClinicProfile> profiles;

  @override
  Widget build(BuildContext context) {
    final total = profiles.length;
    final verified = profiles.where((p) => p.isBusinessVerified).length;
    final provisional =
        profiles
            .where((p) => p.businessVerification.status.isProvisional)
            .length;
    final pending =
        profiles
            .where((p) => p.businessVerification.status.isPendingVerification)
            .length;
    final rejected =
        profiles
            .where(
              (p) =>
                  p.businessVerification.status ==
                  BizVerificationStatus.rejected,
            )
            .length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          _MiniStat(label: '전체 지점', value: '$total', color: AppColors.accent),
          _Divider(),
          _MiniStat(
            label: '인증 완료',
            value: '$verified',
            color: AppColors.success,
          ),
          _Divider(),
          _MiniStat(
            label: '조건부 승인',
            value: '$provisional',
            color: AppColors.accent,
          ),
          _Divider(),
          _MiniStat(label: '진행 중', value: '$pending', color: AppColors.warning),
          _Divider(),
          _MiniStat(
            label: '거절',
            value: '$rejected',
            color: rejected > 0 ? AppColors.error : AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: WebTypo.caption(color: AppColors.textSecondary, size: 11.5),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: AppColors.divider);
  }
}

// ── 5단계 안내 ─────────────────────────────────────────
class _StepperLegend extends StatelessWidget {
  const _StepperLegend();

  @override
  Widget build(BuildContext context) {
    final steps = const [
      ('1', '사업자번호 입력'),
      ('2', '등록증 OCR'),
      ('3', '국세청 실재 확인'),
      ('4', '심평원 병원정보 대조'),
      ('5', '운영팀 최종 검토'),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.appBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_outlined,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              Text(
                '5단계 이중 검증',
                style: WebTypo.sectionTitle(color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '국세청 + 심평원(건강보험심사평가원) 두 기관 데이터를 모두 대조해\n'
            '실제 영업 중인 치과만 공고를 게시할 수 있도록 보호합니다.',
            style: WebTypo.caption(color: AppColors.textSecondary, size: 12),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 540;
              return Wrap(
                spacing: isWide ? 8 : 6,
                runSpacing: 8,
                children: [
                  for (final (no, label) in steps)
                    _StepChip(no: no, label: label),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({required this.no, required this.label});
  final String no;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              no,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── 빈 상태 ────────────────────────────────────────────
class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.onAddBranch});
  final VoidCallback onAddBranch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 28),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 36,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            '인증할 지점이 없어요',
            style: WebTypo.sectionTitle(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            '먼저 「병원 정보」에서 지점을 등록한 뒤 인증을 진행할 수 있습니다.',
            style: WebTypo.caption(color: AppColors.textSecondary, size: 12.5),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onAddBranch,
            icon: const Icon(Icons.local_hospital_outlined, size: 16),
            label: const Text('병원 정보로 이동'),
          ),
        ],
      ),
    );
  }
}

// ── 지점별 인증 카드 ────────────────────────────────────
class _BranchVerificationCard extends StatelessWidget {
  const _BranchVerificationCard({required this.profile});

  final ClinicProfile profile;

  @override
  Widget build(BuildContext context) {
    final v = profile.businessVerification;
    final status = v.status;
    final (badgeLabel, color, icon) = _statusVisual(status);

    return Container(
      padding: const EdgeInsets.all(20),
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
              Expanded(
                child: Text(
                  profile.effectiveName.isNotEmpty
                      ? profile.effectiveName
                      : '이름 없음',
                  style: WebTypo.sectionTitle(color: AppColors.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            v.bizNo.isNotEmpty ? '사업자번호 ${_formatBizNo(v.bizNo)}' : '사업자번호 미입력',
            style: WebTypo.caption(color: AppColors.textSecondary, size: 12),
          ),
          const SizedBox(height: 12),
          _DetailGrid(verification: v),
          if (v.failReason != null && status == BizVerificationStatus.rejected)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.error.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 16,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '거절 사유: ${_humanizeReason(v.failReason!)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (status == BizVerificationStatus.verified) ...[
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  v.verifiedAt != null
                      ? '${DateFormat('yyyy.MM.dd').format(v.verifiedAt!)} 인증 완료'
                      : '인증 완료',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else if (status == BizVerificationStatus.provisional) ...[
                const Icon(
                  Icons.task_alt_outlined,
                  color: AppColors.accent,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    v.policyReason == 'new_clinic_hira_grace'
                        ? '신규 개원 유예 기간 — 심평원 반영 전이라도 공고 게시 가능'
                        : '자동 검증 통과 — 공고 게시 가능 · 운영팀 최종 검토 대기',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ] else if (status == BizVerificationStatus.pendingAuto)
                const Text(
                  '자동 검증 중 — 잠시만 기다려주세요.',
                  style: TextStyle(fontSize: 12),
                )
              else if (status == BizVerificationStatus.manualReview)
                Text(
                  v.failReason == 'hira_mismatch_after_grace' ||
                          v.failReason == 'hira_mismatch_opened_at_unknown'
                      ? '심평원 대조 보류 — 검토 완료 전까지 공고 게시가 어렵습니다.'
                      : '운영팀 수동 검토 중 (영업일 1-2일)',
                  style: const TextStyle(fontSize: 12),
                ),
              const Spacer(),
              if (status != BizVerificationStatus.verified &&
                  status != BizVerificationStatus.provisional)
                FilledButton.icon(
                  onPressed:
                      () => context.go(
                        '/clinic-verify?profileId=${Uri.encodeComponent(profile.id)}',
                      ),
                  icon: const Icon(Icons.upload_file_outlined, size: 16),
                  label: Text(
                    status == BizVerificationStatus.rejected
                        ? '재인증 진행'
                        : '인증 진행',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
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

  static (String, Color, IconData) _statusVisual(BizVerificationStatus s) {
    switch (s) {
      case BizVerificationStatus.verified:
        return ('인증 완료', AppColors.success, Icons.verified);
      case BizVerificationStatus.provisional:
        return ('조건부 승인', AppColors.accent, Icons.task_alt_outlined);
      case BizVerificationStatus.pendingAuto:
        return ('자동 검증 중', AppColors.warning, Icons.hourglass_bottom_outlined);
      case BizVerificationStatus.manualReview:
        return ('운영팀 검토중', AppColors.warning, Icons.support_agent_outlined);
      case BizVerificationStatus.rejected:
        return ('인증 거절', AppColors.error, Icons.error_outline);
      case BizVerificationStatus.none:
        return ('미인증', AppColors.textSecondary, Icons.shield_outlined);
    }
  }

  static String _formatBizNo(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 10) return raw;
    return '${digits.substring(0, 3)}-${digits.substring(3, 5)}-${digits.substring(5)}';
  }

  static String _humanizeReason(String code) {
    switch (code) {
      case 'ocr_failed':
        return '사업자등록증 이미지 인식 실패. 더 선명한 사진으로 다시 올려주세요.';
      case 'nts_api_error':
        return '국세청 조회 일시 오류. 잠시 후 다시 시도해주세요.';
      case 'hira_mismatch':
        return '심평원 등록 정보와 일치하지 않습니다. 운영팀이 추가 검토합니다.';
      case 'hira_mismatch_after_grace':
        return '개원 1개월이 지났지만 심평원 등록 정보와 일치하지 않습니다. 운영팀 검토 완료 전까지 공고 게시가 어렵습니다.';
      case 'hira_mismatch_opened_at_unknown':
        return '심평원 등록 정보와 일치하지 않고 개원일을 확인하지 못했습니다. 운영팀 검토가 필요합니다.';
      default:
        return code;
    }
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.verification});

  final BusinessVerification verification;

  @override
  Widget build(BuildContext context) {
    final v = verification;
    final children = <Widget>[
      _MiniCheck(
        label: '국세청',
        ok: v.checkMethod == 'nts' && v.status.isVerified,
        sub:
            v.checkMethod == 'mock' || v.checkMethod == 'mock_hira'
                ? '시뮬레이션'
                : null,
      ),
      _MiniCheck(
        label: '심평원 대조',
        ok: v.hiraMatched == true,
        sub: v.hiraMatchLevel,
      ),
      _MiniCheck(
        label: 'OCR',
        ok: v.ocrResult != null && v.ocrResult!.isNotEmpty,
        sub: v.method,
      ),
      _MiniCheck(label: '최종 승인', ok: v.status.isVerified),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}

class _MiniCheck extends StatelessWidget {
  const _MiniCheck({required this.label, required this.ok, this.sub});

  final String label;
  final bool ok;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ok ? AppColors.success.withOpacity(0.06) : AppColors.appBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: ok ? AppColors.success.withOpacity(0.3) : AppColors.divider,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (sub != null && sub!.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              '· $sub',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// 카드 그리드 — `/me/clinic` 의 _BranchGrid 와 동일한 패턴.
/// 카드 2개 이상 + 폭 640+ 에서만 2열, 그 외 1열.
class _VerificationCardGrid extends StatelessWidget {
  const _VerificationCardGrid({required this.profiles});

  final List<ClinicProfile> profiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards =
            profiles.map((p) => _BranchVerificationCard(profile: p)).toList();
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

/// 페이지 상단 안내 — "보기 기준" 필터가 적용되지 않는 페이지임을 알림.
class _PageNotice extends StatelessWidget {
  const _PageNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: AppColors.accent.withOpacity(0.85),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '사업자 인증은 지점별로 따로 받아야 해요. 이 화면은 모든 지점의 인증 현황을 항상 함께 보여주며, '
              '상단의 "보기 기준(지점)" 필터와는 무관합니다. 인증을 진행하려면 각 지점 카드의 "인증 진행" 버튼을 눌러주세요.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.textPrimary.withOpacity(0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
