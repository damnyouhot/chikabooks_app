import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../models/campaign.dart';
import '../../../services/billing_key_service.dart';
import '../../../services/campaign_service.dart';
import '../../auth/web/web_account_menu_button.dart';
import 'campaign/campaign_card.dart';
import 'campaign/campaign_detail_sheet.dart';
import 'campaign/campaign_inbox_button.dart';
import 'job_post_top_bar.dart';

/// 광고 캠페인 대시보드 (M7).
///
/// 라우트: `/post-job/campaigns`
///
/// 구성:
///   - 상단: [JobPostTopBar] (이전: 공고 시작) + 인박스 종 + 계정 메뉴
///   - 본문:
///     - 상태 필터 칩 (전체 / 게시중 / 일시정지 / 종료)
///     - 캠페인 카드 리스트 (최신 종료일 순)
///   - 카드 클릭 → [CampaignDetailSheet] 모달
class CampaignDashboardPage extends StatefulWidget {
  const CampaignDashboardPage({super.key});

  @override
  State<CampaignDashboardPage> createState() => _CampaignDashboardPageState();
}

enum _StatusFilter { all, live, paused, ended }

class _CampaignDashboardPageState extends State<CampaignDashboardPage> {
  _StatusFilter _filter = _StatusFilter.all;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        backgroundColor: AppColors.webPublisherPageBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('로그인이 필요합니다.',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () => context.go('/post-job'),
                  child: const Text('공고 홈으로'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.webPublisherPageBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (kIsWeb)
            JobPostTopBar(
              currentStep: const JobPostStep(title: '광고 대시보드'),
              prevStep: JobPostStep.input,
              onPrev: () => context.go('/post-job/input'),
              trailing: Row(
                children: [
                  const _BillingKeyButton(),
                  const SizedBox(width: 4),
                  const CampaignInboxButton(),
                  const SizedBox(width: 4),
                  const WebAccountMenuButton(),
                ],
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(),
              const SizedBox(height: AppSpacing.md),
              _FilterChips(
                value: _filter,
                onChanged: (v) => setState(() => _filter = v),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(child: _buildList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    return StreamBuilder<List<Campaign>>(
      stream: CampaignService.watchMine(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _ErrorState(message: '캠페인을 불러오지 못했어요.\n${snap.error}');
        }
        final all = snap.data ?? const <Campaign>[];
        final filtered = _applyFilter(all);
        if (filtered.isEmpty) {
          return _EmptyState(filter: _filter);
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (_, i) {
            final c = filtered[i];
            return _CampaignTile(campaign: c);
          },
        );
      },
    );
  }

  List<Campaign> _applyFilter(List<Campaign> all) {
    switch (_filter) {
      case _StatusFilter.all:
        return all;
      case _StatusFilter.live:
        return all
            .where((c) =>
                c.lifecycleStatus == CampaignLifecycleStatus.active)
            .toList();
      case _StatusFilter.paused:
        return all
            .where((c) =>
                c.lifecycleStatus == CampaignLifecycleStatus.paused)
            .toList();
      case _StatusFilter.ended:
        return all
            .where((c) =>
                c.lifecycleStatus == CampaignLifecycleStatus.ended ||
                c.lifecycleStatus == CampaignLifecycleStatus.refunded)
            .toList();
    }
  }
}

// ════════════════════════════════════════════════════════════════
// 캠페인 타일 — 카드 + jobs.title 조회
// ════════════════════════════════════════════════════════════════
class _CampaignTile extends StatelessWidget {
  const _CampaignTile({required this.campaign});
  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: campaign.jobId.isEmpty
          ? null
          : FirebaseFirestore.instance
              .collection('jobs')
              .doc(campaign.jobId)
              .get(),
      builder: (context, snap) {
        final title = (snap.data?.data()?['title'] as String?) ?? '(제목 없음)';
        return CampaignCard(
          campaign: campaign,
          jobTitle: title,
          onTap: () => CampaignDetailSheet.show(
            context,
            campaignId: campaign.id,
            jobTitleFallback: title,
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Header / Filter / Empty / Error
// ════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '광고 대시보드',
          style: GoogleFonts.notoSansKr(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '게시 중인 공고의 노출 기간, 결제, 자동연장을 한 곳에서 관리하세요.',
          style: GoogleFonts.notoSansKr(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.value, required this.onChanged});

  final _StatusFilter value;
  final ValueChanged<_StatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        _chip('전체', _StatusFilter.all),
        _chip('게시중', _StatusFilter.live),
        _chip('일시정지', _StatusFilter.paused),
        _chip('종료/환불', _StatusFilter.ended),
      ],
    );
  }

  Widget _chip(String label, _StatusFilter v) {
    final selected = value == v;
    return Material(
      color: selected ? AppColors.cardPrimary : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        onTap: () => onChanged(v),
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 7,
          ),
          child: Text(
            label,
            style: GoogleFonts.notoSansKr(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected
                  ? AppColors.onCardPrimary
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});
  final _StatusFilter filter;

  @override
  Widget build(BuildContext context) {
    String label;
    switch (filter) {
      case _StatusFilter.all:
        label = '아직 게시한 공고가 없어요.\n새 공고를 작성해 보세요.';
        break;
      case _StatusFilter.live:
        label = '게시 중인 공고가 없어요.';
        break;
      case _StatusFilter.paused:
        label = '일시정지된 공고가 없어요.';
        break;
      case _StatusFilter.ended:
        label = '종료/환불된 공고가 없어요.';
        break;
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined,
                size: 40, color: AppColors.textDisabled),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                height: 1.6,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cardPrimary,
                foregroundColor: AppColors.onCardPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppPublisher.buttonRadius),
                ),
                minimumSize: const Size(140, AppPublisher.ctaHeight),
              ),
              onPressed: () => context.go('/post-job/input'),
              child: Text(
                '공고 작성하기',
                style: GoogleFonts.notoSansKr(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 상단바 우측 — 자동결제 카드 등록/관리 진입 버튼.
///
/// 등록 안 됨: "카드 등록" 라벨 + 노란 점 → 클릭 시 등록 페이지로 이동.
/// 등록 됨: "카드 ****-1234" 라벨 → 클릭 시 동일 페이지(여기서 해지/변경 가능).
class _BillingKeyButton extends StatelessWidget {
  const _BillingKeyButton();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BillingKeyMeta?>(
      stream: BillingKeyService.watchMyBillingMeta(),
      builder: (context, snap) {
        final meta = snap.data;
        final has = meta != null && meta.hasBillingKey;
        return Tooltip(
          message: has
              ? '등록된 카드: ${meta.displayLabel}'
              : '자동연장에 사용할 카드 등록',
          child: TextButton.icon(
            onPressed: () => context.go(
              '/post-job/payment/billing/register'
              '?next=${Uri.encodeComponent("/post-job/campaigns")}',
            ),
            style: TextButton.styleFrom(
              foregroundColor: has
                  ? AppColors.textSecondary
                  : AppColors.cardPrimary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 8,
              ),
            ),
            icon: Icon(
              has
                  ? Icons.credit_card_outlined
                  : Icons.credit_card_off_outlined,
              size: 16,
            ),
            label: Text(
              has ? _shortLabel(meta) : '카드 등록',
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      },
    );
  }

  String _shortLabel(BillingKeyMeta meta) {
    final last4 =
        meta.cardNumberMasked.replaceAll(RegExp(r'[^0-9*]'), '');
    if (last4.length >= 4) {
      return '카드 ${last4.substring(last4.length - 4)}';
    }
    if (meta.cardCompany.isNotEmpty) return meta.cardCompany;
    return '등록됨';
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 36, color: AppColors.destructive),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
