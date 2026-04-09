import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../models/clinic_profile.dart';
import '../../../models/voucher.dart';
import '../../../services/job_draft_service.dart';
import '../../../services/order_service.dart';
import '../../../services/voucher_service.dart';
import '../../publisher/services/clinic_auth_service.dart';
import '../../publisher/services/clinic_profile_service.dart';
import '../../auth/web/web_account_menu_button.dart';

/// 게시 전 최종 단계 페이지 (/post-job/publish/:draftId)
///
/// 체크리스트: 등록증 인증 / 본인인증 / 필수항목
/// 인증 → 결제 → 게시
class JobPublishPage extends StatefulWidget {
  final String draftId;
  const JobPublishPage({super.key, required this.draftId});

  @override
  State<JobPublishPage> createState() => _JobPublishPageState();
}

class _JobPublishPageState extends State<JobPublishPage> {
  bool _isLoading = true;
  bool _isPublishing = false;

  ClinicStatus _status = const ClinicStatus();
  ClinicProfile? _profile;
  String? _clinicProfileId;
  List<Voucher> _vouchers = [];
  String? _selectedVoucherId;

  // 체크리스트 상태
  bool get _identityOk => _status.identityVerified;
  bool get _bizOk => _profile?.isBusinessVerified ?? false;
  bool get _allReady => _identityOk && _bizOk;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final draft = await JobDraftService.fetchDraft(widget.draftId);
    _clinicProfileId = draft?.toMap()['clinicProfileId'] as String?;

    final status = await ClinicAuthService.getStatus();
    ClinicProfile? profile;
    if (_clinicProfileId != null) {
      profile = await ClinicProfileService.getProfile(_clinicProfileId!);
    }
    final vouchers = await VoucherService.getAvailableVouchers();

    if (!mounted) return;
    setState(() {
      _status = status;
      _profile = profile;
      _vouchers = vouchers;
      if (vouchers.isNotEmpty) _selectedVoucherId = vouchers.first.id;
      _isLoading = false;
    });
  }

  Future<void> _publish() async {
    if (!_allReady || _clinicProfileId == null) return;
    setState(() => _isPublishing = true);

    try {
      final orderResult = await OrderService.createOrder(
        draftId: widget.draftId,
        clinicProfileId: _clinicProfileId!,
        voucherId: _selectedVoucherId,
      );

      if (!orderResult.requiresPayment) {
        // 공고권 전용 (0원) → 바로 게시 확인
        final confirmResult = await OrderService.confirmPayment(
          orderId: orderResult.orderId,
        );
        if (mounted && confirmResult.success) {
          context.go('/post-job/success/${confirmResult.jobId}');
        }
      } else {
        // TODO: Phase 8 — 토스페이먼츠 결제 UI 호출
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('유료 결제는 곧 지원됩니다. 무료 공고권을 사용해주세요.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('게시 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.webPublisherPageBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (kIsWeb)
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: const Row(
                children: [
                  Spacer(),
                  WebAccountMenuButton(),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 40,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 24),
                            _buildChecklist(),
                            const SizedBox(height: 24),
                            if (_vouchers.isNotEmpty) ...[
                              _buildVoucherSection(),
                              const SizedBox(height: 24),
                            ],
                            _buildPublishButton(),
                            const SizedBox(height: 16),
                            _buildBackButton(),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '게시 전 마지막 확인',
          style: GoogleFonts.notoSansKr(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '아래 항목을 확인하면 바로 게시할 수 있어요',
          style: GoogleFonts.notoSansKr(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildChecklist() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          _checkItem(
            icon: Icons.verified_user_outlined,
            title: '본인인증',
            done: _identityOk,
            actionLabel: '인증하기',
            onAction: () {
              // TODO: Phase 8 — 토스 본인확인 / Firebase OTP
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('본인인증 연동은 곧 지원됩니다.')),
              );
            },
          ),
          Container(height: 1, color: AppColors.divider),
          _checkItem(
            icon: Icons.business_outlined,
            title: '사업자 인증',
            subtitle: _profile?.effectiveName,
            done: _bizOk,
            actionLabel: '등록증 업로드',
            onAction: () {
              context.pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _checkItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool done,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: done
                  ? AppColors.accent.withOpacity(0.1)
                  : AppColors.error.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              done ? Icons.check : icon,
              size: 16,
              color: done ? AppColors.accent : AppColors.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: done ? AppColors.textPrimary : AppColors.error,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (done)
            Text(
              '완료',
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            )
          else
            SizedBox(
              height: 32,
              child: OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.accent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(
                  actionLabel,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVoucherSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '무료 공고권',
            style: GoogleFonts.notoSansKr(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ..._vouchers.map((v) {
            final selected = _selectedVoucherId == v.id;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedVoucherId = selected ? null : v.id;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.accent.withOpacity(0.06)
                      : AppColors.webPublisherPageBg,
                  border: Border.all(
                    color: selected ? AppColors.accent : AppColors.divider,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      size: 18,
                      color: selected ? AppColors.accent : AppColors.textDisabled,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        v.displayLabel,
                        style: GoogleFonts.notoSansKr(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (v.daysUntilExpiry != null)
                      Text(
                        '${v.daysUntilExpiry}일 남음',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 11,
                          color: v.daysUntilExpiry! <= 7
                              ? AppColors.error
                              : AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPublishButton() {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: (_allReady && !_isPublishing) ? _publish : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.disabledBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
          ),
        ),
        child: _isPublishing
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
            : Text(
                _selectedVoucherId != null ? '무료 공고권으로 게시하기' : '결제하고 게시하기',
                style: GoogleFonts.notoSansKr(fontSize: 15, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Center(
      child: TextButton(
        onPressed: () => context.pop(),
        child: Text(
          '← 공고 수정으로 돌아가기',
          style: GoogleFonts.notoSansKr(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
