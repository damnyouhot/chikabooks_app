import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';

/// 결제·게시 동의 정책 버전 (서버 동의 로그와 1:1 매칭).
///
/// 약관 본문 변경 시 새 날짜 버전으로 올리고, 본문은 별도 파일로
/// `web/legal/<doc>_<version>.html`에 보존하는 것을 권장한다.
class PaymentConsentVersions {
  static const String terms = '2026-04-20';
  static const String privacy = '2026-04-20';
  static const String refund = '2026-04-20';

  /// 서버 createOrder에 함께 전달할 페이로드.
  static Map<String, dynamic> payload({
    required bool agreeTerms,
    required bool agreePrivacy,
    required bool agreeRefund,
    required bool withdrawalNoticeShown,
  }) {
    return {
      'terms': {'version': terms, 'agreed': agreeTerms, 'required': true},
      'privacy': {
        'version': privacy,
        'agreed': agreePrivacy,
        'required': true,
      },
      'refund': {'version': refund, 'agreed': agreeRefund, 'required': true},
      'withdrawalNoticeShown': withdrawalNoticeShown,
    };
  }
}

/// 결제 직전 필수 동의 카드.
///
/// - 필수 3종(이용약관 / 개인정보 수집·이용 / 환불·청약철회) 모두 체크해야
///   `onChanged(true)`가 호출된다.
/// - "전체 동의"는 3개를 한 번에 토글한다.
/// - 청약철회 제한 고지(전자상거래법 §17②)는 항상 노출된다.
class PaymentConsentSection extends StatefulWidget {
  /// 필수 3종이 모두 체크된 상태가 바뀔 때 호출.
  final ValueChanged<bool> onAllRequiredChanged;

  /// 외부에서 현재 동의 상태(필수3 + 청약철회 고지 노출 여부)를 읽어가야 할 때 사용.
  final ValueChanged<PaymentConsentState>? onStateChanged;

  const PaymentConsentSection({
    super.key,
    required this.onAllRequiredChanged,
    this.onStateChanged,
  });

  @override
  State<PaymentConsentSection> createState() => _PaymentConsentSectionState();
}

class PaymentConsentState {
  final bool terms;
  final bool privacy;
  final bool refund;
  final bool withdrawalNoticeShown;
  const PaymentConsentState({
    required this.terms,
    required this.privacy,
    required this.refund,
    required this.withdrawalNoticeShown,
  });

  bool get allRequired => terms && privacy && refund;
}

class _PaymentConsentSectionState extends State<PaymentConsentSection> {
  bool _terms = false;
  bool _privacy = false;
  bool _refund = false;

  bool get _allRequired => _terms && _privacy && _refund;

  void _emit() {
    widget.onAllRequiredChanged(_allRequired);
    widget.onStateChanged?.call(
      PaymentConsentState(
        terms: _terms,
        privacy: _privacy,
        refund: _refund,
        // 본 위젯이 트리에 빌드되어 있다는 사실 자체가 고지 노출을 의미.
        withdrawalNoticeShown: true,
      ),
    );
  }

  void _toggleAll(bool? v) {
    final next = v ?? false;
    setState(() {
      _terms = next;
      _privacy = next;
      _refund = next;
    });
    _emit();
  }

  @override
  void initState() {
    super.initState();
    // 초기 상태(모두 false)도 부모에 알려서 버튼 비활성화를 보장.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emit();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWithdrawalNotice(context),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 8),
          _ConsentRow(
            value: _allRequired,
            onChanged: _toggleAll,
            label: '아래 필수 항목에 모두 동의합니다',
            bold: true,
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 4),
          _ConsentRow(
            value: _terms,
            onChanged: (v) {
              setState(() => _terms = v ?? false);
              _emit();
            },
            label: '(필수) 이용약관 동의',
            trailing: _LinkButton(
              label: '보기',
              onTap: () => context.push('/terms'),
            ),
          ),
          _ConsentRow(
            value: _privacy,
            onChanged: (v) {
              setState(() => _privacy = v ?? false);
              _emit();
            },
            label: '(필수) 개인정보 수집·이용 동의',
            trailing: _LinkButton(
              label: '보기',
              onTap: () => context.push('/privacy'),
            ),
          ),
          _ConsentRow(
            value: _refund,
            onChanged: (v) {
              setState(() => _refund = v ?? false);
              _emit();
            },
            label: '(필수) 환불 및 청약철회 정책 동의',
            trailing: _LinkButton(
              label: '보기',
              onTap: () => context.push('/refund'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalNotice(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border(
          left: BorderSide(color: AppColors.warning, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.notoSansKr(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.textPrimary,
                ),
                children: [
                  const TextSpan(
                    text: '청약철회 안내 ',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(
                    text:
                        '— 본 상품은 온라인 공고 게재 서비스로, '
                        '결제 후 공고가 게시되어 노출이 시작된 이후에는 '
                        '청약철회가 제한됩니다(전자상거래법 §17②). '
                        '게시 시작 전에는 전액 환불됩니다. 자세한 내용은 ',
                  ),
                  TextSpan(
                    text: '환불 및 청약철회 정책',
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                      color: AppColors.blue,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => context.push('/refund'),
                  ),
                  const TextSpan(text: '을 확인해 주세요.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String label;
  final Widget? trailing;
  final bool bold;

  const _ConsentRow({
    required this.value,
    required this.onChanged,
    required this.label,
    this.trailing,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeColor: AppColors.accent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LinkButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: GoogleFonts.notoSansKr(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.blue,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
