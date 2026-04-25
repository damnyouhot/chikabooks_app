import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart' show AppRadius, AppSpacing;
import '../../../models/wallet.dart';
import '../../../services/wallet_service.dart';
import '../../jobs/web/web_typography.dart';
import '../providers/me_providers.dart';
import '../services/me_session.dart';
import '../widgets/me_page_shell.dart';

/// /me/billing — 공고권 / 충전 잔액 관리 페이지
///
/// 정책 모드([meBillingModeProvider])에 따라 노출 카드/패키지가 달라진다.
///  - voucher: 공고권만
///  - credit:  충전 잔액만
///  - both:    둘 다
///
/// 모든 변동(차감/충전)은 서버에서만 수행. 클라이언트는 조회 + 충전 요청만.
class MeBillingPage extends ConsumerWidget {
  const MeBillingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(meBillingPolicyProvider);
    final mode = ref.watch(meBillingModeProvider);
    final asyncWallet = ref.watch(walletProvider);

    return MePageShell(
      title: '공고권 / 충전',
      activeMenuId: 'billing',
      child: asyncWallet.when(
        loading: () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PolicyBanner(mode: mode),
            const SizedBox(height: AppSpacing.lg),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
        error: (error, _) => _BillingErrorState(error: error),
        data: (wallet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PolicyBanner(mode: mode),
            const SizedBox(height: AppSpacing.lg),
            _BalanceSection(mode: mode, wallet: wallet, policy: policy),
            const SizedBox(height: AppSpacing.xxl),
            _RechargeSection(mode: mode, policy: policy),
            const SizedBox(height: AppSpacing.xxl),
            _SectionTitle('변동 내역'),
            const SizedBox(height: AppSpacing.md),
            const _LedgerList(),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: WebTypo.sectionTitle(color: AppColors.textPrimary));
  }
}

// ── 지갑 로드 에러 상태 (권한 거부 / 네트워크) ─────────────
class _BillingErrorState extends StatelessWidget {
  const _BillingErrorState({required this.error});

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
          Icon(Icons.error_outline,
              size: 36, color: AppColors.textSecondary.withOpacity(0.7)),
          const SizedBox(height: 10),
          Text(
            permission
                ? '지갑 정보를 불러올 권한이 없습니다'
                : '지갑 정보를 불러오지 못했습니다',
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

// ── 정책 배너 ──────────────────────────────────────────
class _PolicyBanner extends StatelessWidget {
  const _PolicyBanner({required this.mode});
  final BillingMode mode;

  @override
  Widget build(BuildContext context) {
    final desc = switch (mode) {
      BillingMode.voucher =>
        '공고 1건당 공고권 1장이 차감됩니다. 패키지로 미리 구매해두면 게시 즉시 차감되어 결제 단계가 없어요.',
      BillingMode.credit =>
        '미리 충전한 잔액에서 공고 게시 비용이 차감됩니다. 패키지가 클수록 보너스 잔액이 더 많이 적립됩니다.',
      BillingMode.both =>
        '공고권과 충전 잔액을 함께 운영합니다. 공고 게시 시 공고권이 우선 차감되고, 부족하면 충전 잔액에서 차감됩니다.',
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardPrimary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          const Icon(Icons.tips_and_updates_outlined,
              color: AppColors.onCardPrimary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '결제 정책: ${mode.label}',
                  style:
                      WebTypo.sectionTitle(color: AppColors.onCardPrimary),
                ),
                const SizedBox(height: 4),
                Text(desc,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: AppColors.onCardPrimary.withOpacity(0.85),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 잔액 카드들 ────────────────────────────────────────
class _BalanceSection extends StatelessWidget {
  const _BalanceSection({
    required this.mode,
    required this.wallet,
    required this.policy,
  });

  final BillingMode mode;
  final Wallet wallet;
  final BillingPolicyConfig policy;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      if (mode != BillingMode.credit)
        _VoucherBalanceCard(wallet: wallet, policy: policy),
      if (mode != BillingMode.voucher)
        _CreditBalanceCard(wallet: wallet, policy: policy),
    ];
    if (cards.length == 1) return cards.first;
    return LayoutBuilder(builder: (context, constraints) {
      final twoCol = constraints.maxWidth >= 560;
      if (!twoCol) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cards[0],
            const SizedBox(height: AppSpacing.md),
            cards[1],
          ],
        );
      }
      // IntrinsicHeight: SingleChildScrollView 안에서 Row+Expanded+stretch
      // 가 unbounded vertical 을 받으면 layout assertion 으로 silent fail.
      // IntrinsicHeight 가 자식 max height 를 미리 계산해 Row 에 bounded
      // vertical 을 전달.
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: cards[1]),
          ],
        ),
      );
    });
  }
}

class _VoucherBalanceCard extends StatelessWidget {
  const _VoucherBalanceCard({required this.wallet, required this.policy});
  final Wallet wallet;
  final BillingPolicyConfig policy;

  @override
  Widget build(BuildContext context) {
    final next = wallet.voucherEntries.isEmpty
        ? null
        : wallet.voucherEntries.first;
    final lowBalance =
        wallet.vouchers <= policy.autoRechargeThresholdVouchers;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: lowBalance
                ? AppColors.warning.withOpacity(0.5)
                : AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.confirmation_number_outlined,
                  color: AppColors.accent, size: 20),
              const SizedBox(width: 6),
              Text('잔여 공고권',
                  style:
                      WebTypo.sectionTitle(color: AppColors.textPrimary)),
              if (lowBalance) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('충전 권장',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.warning,
                      )),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${wallet.vouchers}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    height: 1.0,
                  )),
              const SizedBox(width: 4),
              Text('장',
                  style: WebTypo.body(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          if (next != null && next.expiresAt != null)
            Text(
              '곧 만료: ${DateFormat('yyyy.MM.dd').format(next.expiresAt!)} · ${next.qty}장',
              style: WebTypo.caption(
                  color: AppColors.textSecondary, size: 12),
            )
          else
            Text(
              '발급일로부터 ${policy.voucherExpiryMonths}개월 내 사용',
              style: WebTypo.caption(
                  color: AppColors.textSecondary, size: 12),
            ),
        ],
      ),
    );
  }
}

class _CreditBalanceCard extends StatelessWidget {
  const _CreditBalanceCard({required this.wallet, required this.policy});
  final Wallet wallet;
  final BillingPolicyConfig policy;

  @override
  Widget build(BuildContext context) {
    final low =
        wallet.creditBalance <= policy.autoRechargeThresholdCredit;
    final expiry =
        wallet.creditExpiryAt(policy.creditExpiryMonthsFromLastUse);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: low
                ? AppColors.warning.withOpacity(0.5)
                : AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  color: AppColors.accent, size: 20),
              const SizedBox(width: 6),
              Text('충전 잔액',
                  style:
                      WebTypo.sectionTitle(color: AppColors.textPrimary)),
              if (low) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('충전 권장',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.warning,
                      )),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_won(wallet.creditBalance)}원',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            expiry != null
                ? '만료 예정: ${DateFormat('yyyy.MM.dd').format(expiry)}'
                : '마지막 사용일로부터 ${policy.creditExpiryMonthsFromLastUse}개월 보관',
            style: WebTypo.caption(
                color: AppColors.textSecondary, size: 12),
          ),
        ],
      ),
    );
  }
}

// ── 패키지 충전 섹션 ────────────────────────────────────
class _RechargeSection extends StatelessWidget {
  const _RechargeSection({required this.mode, required this.policy});
  final BillingMode mode;
  final BillingPolicyConfig policy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mode != BillingMode.credit) ...[
          _SectionTitle('공고권 패키지'),
          const SizedBox(height: AppSpacing.md),
          _PackageGrid(
            children: [
              for (final pkg in policy.voucherPackages)
                _VoucherPackageCard(pkg: pkg),
            ],
          ),
        ],
        if (mode == BillingMode.both) const SizedBox(height: AppSpacing.xxl),
        if (mode != BillingMode.voucher) ...[
          _SectionTitle('충전 잔액 패키지'),
          const SizedBox(height: AppSpacing.md),
          _PackageGrid(
            children: [
              for (final pkg in policy.creditPackages)
                _CreditPackageCard(pkg: pkg),
            ],
          ),
        ],
      ],
    );
  }
}

class _PackageGrid extends StatelessWidget {
  const _PackageGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth >= 720
          ? 3
          : constraints.maxWidth >= 460
              ? 2
              : 1;
      const gap = AppSpacing.md;
      final rows = <Widget>[];
      for (var i = 0; i < children.length; i += cols) {
        final slice = children.sublist(
            i, (i + cols).clamp(0, children.length).toInt());
        if (i > 0) rows.add(const SizedBox(height: gap));
        // IntrinsicHeight: SingleChildScrollView 안에서 Row+Expanded+stretch
        // 가 unbounded vertical 받으면 silent layout fail.
        rows.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = 0; j < cols; j++) ...[
                  if (j > 0) const SizedBox(width: gap),
                  Expanded(
                    child:
                        j < slice.length ? slice[j] : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      );
    });
  }
}

class _VoucherPackageCard extends StatelessWidget {
  const _VoucherPackageCard({required this.pkg});
  final VoucherPackage pkg;

  @override
  Widget build(BuildContext context) {
    final unit = pkg.qty == 0 ? 0 : (pkg.price / pkg.qty).round();
    return _BasePackageCard(
      headline: '${pkg.qty}장',
      price: pkg.price,
      sub: '1장당 ${_won(unit)}원',
      onTap: () => _onPurchase(context, voucher: true, packageId: pkg.id),
    );
  }
}

class _CreditPackageCard extends StatelessWidget {
  const _CreditPackageCard({required this.pkg});
  final CreditPackage pkg;

  @override
  Widget build(BuildContext context) {
    final bonusPct = pkg.amount == 0
        ? 0
        : ((pkg.bonus / pkg.amount) * 100).round();
    return _BasePackageCard(
      headline: '${_won(pkg.amount)}원',
      price: pkg.amount,
      sub: pkg.bonus > 0
          ? '보너스 +${_won(pkg.bonus)}원 ($bonusPct%)'
          : '보너스 없음',
      highlight: pkg.bonus > 0,
      onTap: () => _onPurchase(context, voucher: false, packageId: pkg.id),
    );
  }
}

class _BasePackageCard extends StatelessWidget {
  const _BasePackageCard({
    required this.headline,
    required this.price,
    required this.sub,
    required this.onTap,
    this.highlight = false,
  });

  final String headline;
  final int price;
  final String sub;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: highlight
                ? AppColors.accent.withOpacity(0.5)
                : AppColors.divider,
            width: highlight ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(headline,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              )),
          const SizedBox(height: 4),
          Text('${_won(price)}원',
              style: WebTypo.body(color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(sub,
              style: WebTypo.caption(
                  color: highlight
                      ? AppColors.accent
                      : AppColors.textSecondary,
                  size: 12)),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor:
                  highlight ? AppColors.accent : AppColors.textPrimary,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('충전하기'),
          ),
        ],
      ),
    );
  }
}

Future<void> _onPurchase(
  BuildContext context, {
  required bool voucher,
  required String packageId,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(voucher ? '공고권 충전' : '잔액 충전'),
      content: const Text(
        '결제 모듈은 운영팀에서 준비 중입니다. 곧 토스페이먼츠를 통해 결제할 수 있어요.\n\n'
        '지금은 충전 요청만 접수됩니다 — 운영팀이 영업일 1일 내 처리 후 잔액에 반영해 드립니다.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.white,
          ),
          child: const Text('요청 보내기'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  if (!context.mounted) return;

  try {
    if (voucher) {
      await WalletService.chargeVoucher(packageId: packageId);
    } else {
      await WalletService.chargeCredit(packageId: packageId);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(voucher ? '공고권 충전 요청을 접수했습니다.' : '잔액 충전 요청을 접수했습니다.'),
        backgroundColor: AppColors.success,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('요청 실패: 결제 모듈 준비 중 ($e)'),
        backgroundColor: AppColors.error,
      ),
    );
  }
}

// ── 변동 내역 리스트 ────────────────────────────────────
class _LedgerList extends ConsumerWidget {
  const _LedgerList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEntries = ref.watch(walletLedgerProvider(30));
    return asyncEntries.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(
          '변동 내역을 불러오지 못했습니다: $error',
          style: WebTypo.caption(color: AppColors.error, size: 12),
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return Container(
            padding:
                const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.divider),
            ),
            child: Center(
              child: Text(
                '아직 변동 내역이 없어요. 첫 충전 또는 공고 게시 시 여기에 기록됩니다.',
                style: WebTypo.caption(
                    color: AppColors.textSecondary, size: 12.5),
              ),
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, color: AppColors.divider),
                _LedgerRow(entry: entries[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry});
  final WalletLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = entry.isCharge ? AppColors.success : AppColors.error;
    final unit = entry.isVoucher ? '장' : '원';
    final sign = entry.isCharge ? '+' : '';
    final delta = entry.isVoucher ? entry.delta : entry.delta;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              entry.isVoucher
                  ? Icons.confirmation_number_outlined
                  : Icons.account_balance_wallet_outlined,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label.isNotEmpty ? entry.label : _humanizeType(entry.type),
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                if (entry.createdAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      DateFormat('yyyy.MM.dd HH:mm').format(entry.createdAt!),
                      style: WebTypo.caption(
                          color: AppColors.textSecondary, size: 11),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$sign${_won(delta)}$unit',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
                  )),
              const SizedBox(height: 2),
              Text(
                entry.isVoucher
                    ? '잔여 ${entry.balanceAfter}장'
                    : '잔여 ${_won(entry.balanceAfter)}원',
                style: WebTypo.caption(
                    color: AppColors.textSecondary, size: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _humanizeType(String type) {
    switch (type) {
      case 'voucher_use':
        return '공고권 사용';
      case 'voucher_charge':
        return '공고권 충전';
      case 'credit_use':
        return '잔액 차감';
      case 'credit_charge':
        return '잔액 충전';
      case 'credit_refund':
        return '잔액 환불';
      default:
        return type;
    }
  }
}

String _won(int v) {
  final n = v.abs();
  return NumberFormat('#,###').format(n);
}
