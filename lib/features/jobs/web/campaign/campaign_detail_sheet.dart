import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_confirm_modal.dart';
import '../../../../core/widgets/app_modal_scaffold.dart';
import '../../../../models/campaign.dart';
import '../../../../services/campaign_action_service.dart';
import '../../../../services/campaign_service.dart';
import 'campaign_auto_renew_dialog.dart';
import 'campaign_extend_dialog.dart';
import 'campaign_refund_dialog.dart';
import 'campaign_status_chip.dart';
import 'campaign_upgrade_dialog.dart';

/// 캠페인 상세 + 액션 시트 (모바일=BottomSheet, 데스크톱=중앙 다이얼로그).
///
/// 표시:
///   - 등급/상태 칩, 공고 제목, 결제 금액
///   - 진행 게이지(잔여일 / 총일수)
///   - 일시정지 횟수 / 자동연장 정보 / 환불 윈도우
///   - 액션 버튼 그리드 (상태별 노출 토글)
///
/// 결제 필요한 액션은 별도 다이얼로그로 위임.
class CampaignDetailSheet extends StatefulWidget {
  const CampaignDetailSheet({
    super.key,
    required this.campaignId,
    required this.jobTitleFallback,
  });

  final String campaignId;

  /// 캠페인 캐시 도큐먼트의 조회 실패 시 노출할 fallback 제목 (리스트에서 받은 값).
  final String jobTitleFallback;

  static Future<void> show(
    BuildContext context, {
    required String campaignId,
    required String jobTitleFallback,
  }) {
    return showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.6,
        builder: (_, scroll) => CampaignDetailSheet(
          campaignId: campaignId,
          jobTitleFallback: jobTitleFallback,
        ),
      ),
    );
  }

  @override
  State<CampaignDetailSheet> createState() => _CampaignDetailSheetState();
}

class _CampaignDetailSheetState extends State<CampaignDetailSheet> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.appBg,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: StreamBuilder<Campaign?>(
        stream: CampaignService.watchById(widget.campaignId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: CircularProgressIndicator(),
              ),
            );
          }
          final campaign = snapshot.data;
          if (campaign == null) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Text('캠페인 정보를 불러올 수 없습니다.'),
            );
          }
          return _buildBody(context, campaign);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, Campaign campaign) {
    return SingleChildScrollView(
      child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: campaign.jobId.isEmpty
            ? null
            : FirebaseFirestore.instance
                .collection('jobs')
                .doc(campaign.jobId)
                .get(),
        builder: (context, jobSnap) {
          final jobData = jobSnap.data?.data() ?? const <String, dynamic>{};
          final title = (jobData['title'] as String?)?.trim().isNotEmpty == true
              ? jobData['title'] as String
              : widget.jobTitleFallback;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(campaign: campaign, jobTitle: title),
              const SizedBox(height: AppSpacing.lg),
              _ProgressBlock(campaign: campaign),
              const SizedBox(height: AppSpacing.lg),
              _MetricsBlock(campaign: campaign),
              const SizedBox(height: AppSpacing.lg),
              if (_busy) const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: AppSpacing.sm),
              _ActionGrid(
                campaign: campaign,
                jobTitle: title,
                busy: _busy,
                runAction: _runAction,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          );
        },
      ),
    );
  }

  Future<void> _runAction(Future<void> Function() body) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await body();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('실패: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ════════════════════════════════════════════════════════════════
// Header / Progress / Metrics
// ════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  const _Header({required this.campaign, required this.jobTitle});
  final Campaign campaign;
  final String jobTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CampaignTierChip(tierKey: campaign.tierKey),
            const SizedBox(width: 6),
            CampaignStatusChip(status: campaign.lifecycleStatus),
            const Spacer(),
            IconButton(
              tooltip: '닫기',
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          jobTitle,
          style: GoogleFonts.notoSansKr(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.campaign});
  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy.MM.dd');
    final start = campaign.adStartAt;
    final end = campaign.adEndAt;
    final remain = campaign.remainingDays;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          start != null && end != null
              ? '${fmt.format(start.toLocal())}  →  ${fmt.format(end.toLocal())}'
              : '게시 일정 정보 없음',
          style: GoogleFonts.notoSansKr(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            value: campaign.progressRatio.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.surfaceMuted,
            valueColor: AlwaysStoppedAnimation<Color>(
              campaign.lifecycleStatus.isTerminal
                  ? AppColors.disabledText
                  : AppColors.cardPrimary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          campaign.lifecycleStatus.isTerminal
              ? '게시 종료'
              : '잔여 $remain일 / 총 ${campaign.totalDays}일',
          style: GoogleFonts.notoSansKr(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _MetricsBlock extends StatelessWidget {
  const _MetricsBlock({required this.campaign});
  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final p = campaign.policySnapshot;
    final pause = campaign.pause;
    final auto = campaign.autoRenew;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius:
            BorderRadius.circular(AppPublisher.inputPanelRadius),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          _MetricRow(
            label: '결제 금액',
            value: campaign.amountPaid > 0
                ? '${NumberFormat('#,###').format(campaign.amountPaid)}원'
                : '공고권 사용',
          ),
          _MetricRow(
            label: '일시정지',
            value:
                '${pause.count}회 / 누적 ${pause.totalDaysCredited}일 적립 (세이브율 ${(p.pauseSaveRate * 100).round()}%)',
          ),
          _MetricRow(
            label: '자동연장',
            value: auto.enabled
                ? '활성 · ${auto.nextChargeAt != null ? "${DateFormat('M/d').format(auto.nextChargeAt!.toLocal())} 청구 예정" : "다음 청구일 산출 중"}'
                : '비활성',
            valueColor: auto.enabled
                ? AppColors.success
                : AppColors.textSecondary,
          ),
          if (auto.enabled && auto.lastChargeStatus == 'failed')
            _MetricRow(
              label: '직전 결제',
              value: '실패 — ${auto.failedReason ?? "사유 미상"}',
              valueColor: AppColors.destructive,
            ),
          _MetricRow(
            label: '환불 가능',
            value: '결제일로부터 ${p.refundWindowDays}일 이내 (전액)',
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                color: valueColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Action grid
// ════════════════════════════════════════════════════════════════

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.campaign,
    required this.jobTitle,
    required this.busy,
    required this.runAction,
  });

  final Campaign campaign;
  final String jobTitle;
  final bool busy;
  final Future<void> Function(Future<void> Function() body) runAction;

  bool get _isLive => campaign.lifecycleStatus.isLive;
  bool get _isActive =>
      campaign.lifecycleStatus == CampaignLifecycleStatus.active;
  bool get _isPaused =>
      campaign.lifecycleStatus == CampaignLifecycleStatus.paused;

  @override
  Widget build(BuildContext context) {
    final List<_ActionDef> actions = [];

    if (_isActive) {
      actions.add(_ActionDef(
        icon: Icons.pause_circle_outline,
        label: '일시정지',
        onTap: () => _pause(context),
        enabled: campaign.canPause,
      ));
    }
    if (_isPaused) {
      actions.add(_ActionDef(
        icon: Icons.play_circle_outline,
        label: '재개',
        onTap: () => _resume(context),
      ));
    }
    if (_isLive) {
      actions.add(_ActionDef(
        icon: Icons.add_box_outlined,
        label: '연장 결제',
        onTap: () => _openExtend(context),
      ));
      actions.add(_ActionDef(
        icon: Icons.upgrade,
        label: '등급 변경',
        onTap: () => _openUpgrade(context),
      ));
      actions.add(_ActionDef(
        icon: campaign.autoRenew.enabled
            ? Icons.toggle_on_outlined
            : Icons.toggle_off_outlined,
        label: campaign.autoRenew.enabled ? '자동연장 OFF' : '자동연장 ON',
        onTap: () => _toggleAutoRenew(context),
      ));
      actions.add(_ActionDef(
        icon: Icons.cancel_outlined,
        label: '환불 신청',
        onTap: () => _openRefund(context),
        destructive: true,
      ));
      actions.add(_ActionDef(
        icon: Icons.stop_circle_outlined,
        label: '조기 마감',
        onTap: () => _close(context),
      ));
    }

    if (actions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius:
              BorderRadius.circular(AppPublisher.inputPanelRadius),
        ),
        child: Text(
          campaign.lifecycleStatus == CampaignLifecycleStatus.refunded
              ? '환불된 캠페인은 추가 액션이 없습니다.'
              : '게시가 종료된 캠페인입니다. 새 공고를 작성해 주세요.',
          style: GoogleFonts.notoSansKr(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: actions
          .map(
            (a) => SizedBox(
              width: 150,
              child: _ActionButton(
                icon: a.icon,
                label: a.label,
                onTap: busy || !a.enabled ? null : a.onTap,
                destructive: a.destructive,
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _pause(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    return runAction(() async {
      await CampaignActionService.pause(campaignId: campaign.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('일시정지되었습니다.')),
      );
    });
  }

  Future<void> _resume(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    return runAction(() async {
      final r = await CampaignActionService.resume(campaignId: campaign.id);
      final credited = (r['daysCredited'] as num?)?.toInt() ?? 0;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            credited > 0 ? '재개됨 — $credited일이 환원되었습니다.' : '재개되었습니다.',
          ),
        ),
      );
    });
  }

  Future<void> _close(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const AppConfirmModal(
        title: '광고 조기 마감',
        message: '잔여기간이 환불되지 않고 즉시 마감됩니다. 진행하시겠습니까?',
        confirmLabel: '마감',
        destructive: true,
      ),
    );
    if (ok != true) return;
    return runAction(() async {
      await CampaignActionService.close(campaignId: campaign.id);
      messenger.showSnackBar(const SnackBar(content: Text('마감되었습니다.')));
    });
  }

  Future<void> _toggleAutoRenew(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (campaign.autoRenew.enabled) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => const AppConfirmModal(
          title: '자동연장 끄기',
          message: '자동연장을 비활성화합니다. 만료일에 자동 청구되지 않습니다.',
          confirmLabel: '확인',
        ),
      );
      if (ok != true) return;
      await runAction(() async {
        await CampaignActionService.setAutoRenew(
          campaignId: campaign.id,
          enabled: false,
        );
        messenger.showSnackBar(
          const SnackBar(content: Text('자동연장이 비활성화되었습니다.')),
        );
      });
      return;
    }
    final ok = await CampaignAutoRenewDialog.show(
      context,
      campaign: campaign,
    );
    if (ok == true) {
      messenger.showSnackBar(
        const SnackBar(content: Text('자동연장이 설정되었습니다.')),
      );
    }
  }

  Future<void> _openExtend(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await CampaignExtendDialog.show(
      context,
      campaign: campaign,
      jobTitle: jobTitle,
    );
    if (ok == true) {
      messenger.showSnackBar(
        const SnackBar(content: Text('결제 진행 후 적용됩니다.')),
      );
    }
  }

  Future<void> _openUpgrade(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await CampaignUpgradeDialog.show(
      context,
      campaign: campaign,
      jobTitle: jobTitle,
    );
    if (ok == true) {
      messenger.showSnackBar(
        const SnackBar(content: Text('결제 진행 후 등급이 적용됩니다.')),
      );
    }
  }

  Future<void> _openRefund(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await CampaignRefundDialog.show(context, campaign: campaign);
    if (ok == true) {
      messenger.showSnackBar(
        const SnackBar(content: Text('환불이 처리되었습니다.')),
      );
      navigator.pop();
    }
  }
}

class _ActionDef {
  _ActionDef({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.enabled = true,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool enabled;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final fg = disabled
        ? AppColors.disabledText
        : destructive
            ? AppColors.destructive
            : AppColors.textPrimary;
    final bg = disabled ? AppColors.disabledBg : AppColors.white;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: disabled ? AppColors.disabledBg : AppColors.divider,
            ),
            borderRadius:
                BorderRadius.circular(AppPublisher.buttonRadius),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
