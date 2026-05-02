import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/widgets/app_modal_scaffold.dart';
import '../../../services/admin_billing_service.dart';
import '../widgets/admin_common_widgets.dart';

/// 운영팀 — 결제·세금계산서·현금영수증 처리
///
/// 3개 수집함을 가로로 배치:
///   1. 충전 요청   : pending_manual → applyPendingPayment
///   2. 세금계산서  : queued        → markTaxIssued
///   3. 현금영수증  : queued        → markCashReceiptIssued
class AdminBillingTab extends StatelessWidget {
  const AdminBillingTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 1100;
          final children = const [
            _PaymentColumn(),
            _TaxColumn(),
            _CashReceiptColumn(),
          ];
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: children[0]),
                const SizedBox(width: 12),
                Expanded(child: children[1]),
                const SizedBox(width: 12),
                Expanded(child: children[2]),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              children[0],
              const SizedBox(height: 12),
              children[1],
              const SizedBox(height: 12),
              children[2],
            ],
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 공통 컬럼 컨테이너
// ══════════════════════════════════════════════════════════════
class _Column extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int? badgeCount;
  final Widget child;
  const _Column({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (badgeCount != null && badgeCount! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$badgeCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 1) 충전 요청 (paymentRequests)
// ══════════════════════════════════════════════════════════════
class _PaymentColumn extends StatelessWidget {
  const _PaymentColumn();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PaymentRequestRow>>(
      stream: AdminBillingService.watchPaymentRequests(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Column(
            title: '충전 요청 (입금 대기)',
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.accent,
            child: AdminLoadingState(),
          );
        }
        if (snap.hasError) {
          return _Column(
            title: '충전 요청',
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.accent,
            child: AdminErrorState(message: '${snap.error}'),
          );
        }
        final rows = snap.data ?? const [];
        return _Column(
          title: '충전 요청 (입금 대기)',
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.accent,
          badgeCount: rows.length,
          child: rows.isEmpty
              ? const AdminEmptyState(message: '대기 중인 충전 요청이 없습니다')
              : Column(
                  children: rows
                      .map((r) => _PaymentTile(row: r))
                      .toList(),
                ),
        );
      },
    );
  }
}

class _PaymentTile extends StatefulWidget {
  final PaymentRequestRow row;
  const _PaymentTile({required this.row});

  @override
  State<_PaymentTile> createState() => _PaymentTileState();
}

class _PaymentTileState extends State<_PaymentTile> {
  bool _busy = false;

  Future<void> _apply() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AppConfirmModal(
            title: '입금 확인 후 잔액에 반영',
            message:
                '${widget.row.kind} / ${widget.row.packageId} '
                '/ ${widget.row.amount.toString()}원\n'
                '진짜 입금이 확인되었나요? 적용 후 즉시 사용자 잔액에 반영됩니다.',
            confirmLabel: '반영',
            destructive: true,
          ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await AdminBillingService.applyPendingPayment(widget.row.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('잔액 반영 완료')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final bonusSfx = r.bonus > 0 ? ' (+${r.bonus} 보너스)' : '';
    final detail = r.isVoucher
        ? '공고권 ${r.qty}장'
        : '충전 ${r.amount}원$bonusSfx';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.appBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(detail,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('uid: ${_short(r.ownerUid)} · ${_fmtTs(r.createdAt)}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('금액: ${r.amount.toString()}원',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          SizedBox(
            height: 30,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _apply,
              icon: _busy
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check, size: 14),
              label: const Text('입금 확인 → 잔액 반영'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 2) 세금계산서 요청 (taxRequests)
// ══════════════════════════════════════════════════════════════
class _TaxColumn extends StatelessWidget {
  const _TaxColumn();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TaxRequestRow>>(
      stream: AdminBillingService.watchTaxRequests(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Column(
            title: '세금계산서 요청',
            icon: Icons.receipt_long_outlined,
            color: AppColors.success,
            child: AdminLoadingState(),
          );
        }
        if (snap.hasError) {
          return _Column(
            title: '세금계산서 요청',
            icon: Icons.receipt_long_outlined,
            color: AppColors.success,
            child: AdminErrorState(message: '${snap.error}'),
          );
        }
        final rows = snap.data ?? const [];
        return _Column(
          title: '세금계산서 요청',
          icon: Icons.receipt_long_outlined,
          color: AppColors.success,
          badgeCount: rows.length,
          child: rows.isEmpty
              ? const AdminEmptyState(message: '대기 중인 세금계산서 요청이 없습니다')
              : Column(
                  children:
                      rows.map((r) => _TaxTile(row: r)).toList(),
                ),
        );
      },
    );
  }
}

class _TaxTile extends StatefulWidget {
  final TaxRequestRow row;
  const _TaxTile({required this.row});

  @override
  State<_TaxTile> createState() => _TaxTileState();
}

class _TaxTileState extends State<_TaxTile> {
  bool _busy = false;

  Future<void> _markIssued() async {
    final extId = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogCtx) => AppModalDialog(
            insetPadding: const EdgeInsets.all(AppSpacing.xl),
            borderOpacity: 0.7,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '발급 완료 마킹',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: extId,
                  decoration: const InputDecoration(
                    labelText: '외부 발급 ID (선택)',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(
                    labelText: '메모 (선택)',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          backgroundColor: AppColors.surfaceMuted,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.cardPrimary,
                          foregroundColor: AppColors.onCardEmphasis,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('완료'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await AdminBillingService.markTaxIssued(
        requestId: widget.row.id,
        externalId: extId.text.trim().isEmpty ? null : extId.text.trim(),
        note: note.text.trim().isEmpty ? null : note.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('발급 완료 처리됨')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.appBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${r.clinicName} (${r.bizNo})',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('대표: ${r.ownerName} · 금액: ${r.amount}원',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          Text('이메일: ${r.email}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          Text(_fmtTs(r.createdAt),
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textDisabled)),
          const SizedBox(height: 6),
          SizedBox(
            height: 30,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _markIssued,
              icon: _busy
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline, size: 14),
              label: const Text('발급 완료'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.success,
                side: const BorderSide(color: AppColors.success),
                textStyle: const TextStyle(fontSize: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 3) 현금영수증 요청 (cashReceiptRequests)
// ══════════════════════════════════════════════════════════════
class _CashReceiptColumn extends StatelessWidget {
  const _CashReceiptColumn();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CashReceiptRequestRow>>(
      stream: AdminBillingService.watchCashReceiptRequests(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Column(
            title: '현금영수증 요청',
            icon: Icons.receipt_outlined,
            color: AppColors.warning,
            child: AdminLoadingState(),
          );
        }
        if (snap.hasError) {
          return _Column(
            title: '현금영수증 요청',
            icon: Icons.receipt_outlined,
            color: AppColors.warning,
            child: AdminErrorState(message: '${snap.error}'),
          );
        }
        final rows = snap.data ?? const [];
        return _Column(
          title: '현금영수증 요청',
          icon: Icons.receipt_outlined,
          color: AppColors.warning,
          badgeCount: rows.length,
          child: rows.isEmpty
              ? const AdminEmptyState(message: '대기 중인 현금영수증 요청이 없습니다')
              : Column(
                  children: rows
                      .map((r) => _CashTile(row: r))
                      .toList(),
                ),
        );
      },
    );
  }
}

class _CashTile extends StatefulWidget {
  final CashReceiptRequestRow row;
  const _CashTile({required this.row});

  @override
  State<_CashTile> createState() => _CashTileState();
}

class _CashTileState extends State<_CashTile> {
  bool _busy = false;

  Future<void> _markIssued() async {
    final extId = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogCtx) => AppModalDialog(
            insetPadding: const EdgeInsets.all(AppSpacing.xl),
            borderOpacity: 0.7,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '발급 완료 마킹',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: extId,
                  decoration: const InputDecoration(
                    labelText: '외부 발급 ID (선택)',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(
                    labelText: '메모 (선택)',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          backgroundColor: AppColors.surfaceMuted,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.cardPrimary,
                          foregroundColor: AppColors.onCardEmphasis,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('완료'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await AdminBillingService.markCashReceiptIssued(
        requestId: widget.row.id,
        externalId: extId.text.trim().isEmpty ? null : extId.text.trim(),
        note: note.text.trim().isEmpty ? null : note.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('발급 완료 처리됨')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final typeLabel =
        r.receiptType == 'income' ? '소득공제' : '지출증빙';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.appBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$typeLabel · ${r.amount}원',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('식별번호: ${r.identifier}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          Text('uid: ${_short(r.ownerUid)} · ${_fmtTs(r.createdAt)}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textDisabled)),
          const SizedBox(height: 6),
          SizedBox(
            height: 30,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _markIssued,
              icon: _busy
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline, size: 14),
              label: const Text('발급 완료'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side: const BorderSide(color: AppColors.warning),
                textStyle: const TextStyle(fontSize: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// utils
// ══════════════════════════════════════════════════════════════
String _short(String uid) =>
    uid.length <= 10 ? uid : '${uid.substring(0, 6)}…${uid.substring(uid.length - 4)}';

String _fmtTs(DateTime? t) {
  if (t == null) return '-';
  return '${t.month}/${t.day} '
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}
