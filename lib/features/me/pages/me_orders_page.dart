import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart' show AppRadius, AppSpacing;
import '../../../core/widgets/app_modal_scaffold.dart';
import '../../../models/job_order.dart';
import '../../../services/order_service.dart';
import '../../jobs/web/web_typography.dart';
import '../widgets/me_page_shell.dart';

/// /me/orders — 결제 내역 + 세금계산서/현금영수증 발급 요청 페이지
///
/// 1차 운영(현재): 사용자가 "발급 요청" 클릭 → 서버 Callable
/// (`requestTaxInvoice` / `requestCashReceipt`) 가 요청 문서를 적재하고
/// 운영팀이 토스/외주 콘솔에서 수동 발급.
///
/// 2차 운영(외주 API 발급 후): 동일 화면, 어댑터 내부만 교체.
class MeOrdersPage extends StatelessWidget {
  const MeOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MePageShell(
      title: '결제 · 세금계산서',
      activeMenuId: 'orders',
      child: FutureBuilder<List<JobOrder>>(
        future: OrderService.getMyOrders(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final orders = snap.data ?? const [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _IntroBanner(),
              const SizedBox(height: AppSpacing.lg),
              if (orders.isEmpty)
                const _EmptyState()
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < orders.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.md),
                      _OrderCard(order: orders[i]),
                    ],
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _IntroBanner extends StatelessWidget {
  const _IntroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.appBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 22, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('세금계산서·현금영수증',
                    style: WebTypo.sectionTitle(
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  '발급 요청 시 운영팀이 영업일 1-2일 내 토스 / 외주 채널로 발급해 드립니다.',
                  style: WebTypo.caption(
                      color: AppColors.textSecondary, size: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 28),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined,
              size: 36, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text('결제 내역이 없어요',
              style: WebTypo.sectionTitle(color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(
            '공고를 게시하면 결제 내역이 여기에 쌓입니다.',
            style:
                WebTypo.caption(color: AppColors.textSecondary, size: 12.5),
          ),
        ],
      ),
    );
  }
}

// ── 주문 카드 ──────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final JobOrder order;

  @override
  Widget build(BuildContext context) {
    final paid = order.isPaid;
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '주문 #${order.id.substring(0, order.id.length.clamp(0, 8).toInt())}',
                      style: WebTypo.sectionTitle(
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    if (order.createdAt != null)
                      Text(
                        DateFormat('yyyy.MM.dd HH:mm')
                            .format(order.createdAt!),
                        style: WebTypo.caption(
                            color: AppColors.textSecondary, size: 12),
                      ),
                  ],
                ),
              ),
              _StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetaItem(
                  label: '결제 금액',
                  value: order.isFreeWithVoucher
                      ? '공고권 1장'
                      : '${NumberFormat('#,###').format(order.amount)}원',
                ),
              ),
              Expanded(
                child: _MetaItem(
                  label: '노출 기간',
                  value: '${order.exposureDays}일',
                ),
              ),
              Expanded(
                child: _MetaItem(
                  label: '결제 수단',
                  value: order.paymentProvider == 'voucher_only'
                      ? '공고권'
                      : (order.paymentProvider ?? '-').toUpperCase(),
                ),
              ),
            ],
          ),
          if (paid) ...[
            const Divider(height: 28, color: AppColors.divider),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openTaxInvoiceDialog(context, order),
                  icon: const Icon(Icons.description_outlined, size: 16),
                  label: const Text('세금계산서 요청'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _openCashReceiptDialog(context, order),
                  icon: const Icon(Icons.receipt_outlined, size: 16),
                  label: const Text('현금영수증 요청'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: WebTypo.caption(
                color: AppColors.textSecondary, size: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      OrderStatus.paid => ('결제 완료', AppColors.success),
      OrderStatus.paymentPending => ('결제 대기', AppColors.warning),
      OrderStatus.created => ('주문 생성', AppColors.textSecondary),
      OrderStatus.failed => ('실패', AppColors.error),
      OrderStatus.refunded => ('환불 완료', AppColors.textSecondary),
      OrderStatus.cancelled => ('취소', AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color)),
    );
  }
}

// ── 세금계산서 요청 다이얼로그 ───────────────────────────
Future<void> _openTaxInvoiceDialog(
  BuildContext context,
  JobOrder order,
) async {
  await showDialog(
    context: context,
    builder: (_) => _TaxInvoiceDialog(order: order),
  );
}

class _TaxInvoiceDialog extends StatefulWidget {
  const _TaxInvoiceDialog({required this.order});
  final JobOrder order;

  @override
  State<_TaxInvoiceDialog> createState() => _TaxInvoiceDialogState();
}

class _TaxInvoiceDialogState extends State<_TaxInvoiceDialog> {
  final _bizNo = TextEditingController();
  final _clinicName = TextEditingController();
  final _ownerName = TextEditingController();
  final _address = TextEditingController();
  final _bizType = TextEditingController();
  final _bizItem = TextEditingController();
  final _email = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    for (final c in [
      _bizNo,
      _clinicName,
      _ownerName,
      _address,
      _bizType,
      _bizItem,
      _email,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_bizNo.text.trim().isEmpty ||
        _clinicName.text.trim().isEmpty ||
        _ownerName.text.trim().isEmpty ||
        _address.text.trim().isEmpty ||
        _email.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('필수 항목을 모두 입력해주세요.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('requestTaxInvoice');
      await callable.call({
        'clinicId': widget.order.clinicProfileId,
        'orderRef': widget.order.id,
        'bizNo': _bizNo.text.trim(),
        'clinicName': _clinicName.text.trim(),
        'ownerName': _ownerName.text.trim(),
        'address': _address.text.trim(),
        'bizType': _bizType.text.trim(),
        'bizItem': _bizItem.text.trim(),
        'amount': widget.order.amount,
        'email': _email.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('세금계산서 발급 요청을 접수했습니다. 영업일 1-2일 내 발급됩니다.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('요청 실패: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppModalDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '세금계산서 발급 요청',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '주문 #${widget.order.id.substring(0, widget.order.id.length.clamp(0, 8).toInt())} · '
                    '${NumberFormat('#,###').format(widget.order.amount)}원',
                    style: WebTypo.caption(
                        color: AppColors.textSecondary, size: 12),
                  ),
                  const SizedBox(height: 16),
                  _Field(label: '사업자번호 *', controller: _bizNo, hint: '123-45-67890'),
                  const SizedBox(height: 12),
                  _Field(label: '상호 *', controller: _clinicName),
                  const SizedBox(height: 12),
                  _Field(label: '대표자명 *', controller: _ownerName),
                  const SizedBox(height: 12),
                  _Field(label: '사업장 주소 *', controller: _address),
                  const SizedBox(height: 12),
                  _Field(label: '업태', controller: _bizType, hint: '서비스, 의료업 등'),
                  const SizedBox(height: 12),
                  _Field(label: '종목', controller: _bizItem, hint: '치과의원'),
                  const SizedBox(height: 12),
                  _Field(
                      label: '수신 이메일 *',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _sending ? null : () => Navigator.of(context).pop(),
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
                  onPressed: _sending ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.white,
                  ),
                  child: Text(_sending ? '요청 중...' : '발급 요청'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 현금영수증 요청 다이얼로그 ───────────────────────────
Future<void> _openCashReceiptDialog(
  BuildContext context,
  JobOrder order,
) async {
  await showDialog(
    context: context,
    builder: (_) => _CashReceiptDialog(order: order),
  );
}

class _CashReceiptDialog extends StatefulWidget {
  const _CashReceiptDialog({required this.order});
  final JobOrder order;

  @override
  State<_CashReceiptDialog> createState() => _CashReceiptDialogState();
}

class _CashReceiptDialogState extends State<_CashReceiptDialog> {
  String _type = 'business'; // 지출증빙(사업자) 우선
  final _identifier = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _identifier.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_identifier.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('식별자를 입력해주세요.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('requestCashReceipt');
      await callable.call({
        'clinicId': widget.order.clinicProfileId,
        'orderRef': widget.order.id,
        'receiptType': _type,
        'identifier': _identifier.text.trim(),
        'amount': widget.order.amount,
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('현금영수증 발급 요청을 접수했습니다. 영업일 1-2일 내 발급됩니다.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('요청 실패: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppModalDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '현금영수증 발급 요청',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '주문 #${widget.order.id.substring(0, widget.order.id.length.clamp(0, 8).toInt())} · '
                  '${NumberFormat('#,###').format(widget.order.amount)}원',
                  style: WebTypo.caption(
                      color: AppColors.textSecondary, size: 12),
                ),
                const SizedBox(height: 16),
                const Text('발급 유형',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        value: 'business',
                        groupValue: _type,
                        title: const Text('지출증빙', style: TextStyle(fontSize: 13)),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setState(() => _type = v ?? 'business'),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        value: 'income',
                        groupValue: _type,
                        title: const Text('소득공제', style: TextStyle(fontSize: 13)),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setState(() => _type = v ?? 'business'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _Field(
                  label: _type == 'business' ? '사업자번호' : '휴대폰번호',
                  controller: _identifier,
                  hint: _type == 'business' ? '123-45-67890' : '010-1234-5678',
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _sending ? null : () => Navigator.of(context).pop(),
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
                  onPressed: _sending ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.white,
                  ),
                  child: Text(_sending ? '요청 중...' : '발급 요청'),
                ),
              ),
            ],
          ),
        ],
      ),
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
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700)),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}
