import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_modal_scaffold.dart';
import 'publisher_shared.dart';
import '../services/clinic_auth_service.dart';

/// 사업자 인증 검토 대기 화면 (/publisher/pending)
class PublisherPendingPage extends StatefulWidget {
  const PublisherPendingPage({super.key});

  @override
  State<PublisherPendingPage> createState() => _PublisherPendingPageState();
}

class _PublisherPendingPageState extends State<PublisherPendingPage> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // 30초마다 승인 여부 폴링
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkApproval();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkApproval() async {
    final status = await ClinicAuthService.getStatus();
    if (!mounted) return;
    if (status.isApprovedAndCanPost) {
      context.go('/publisher/done');
    } else if (status.approvalStatus == 'rejected') {
      context.go('/publisher/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PubScaffold(
      title: '검토 중',
      showBack: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 애니메이션 아이콘 영역
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    color: AppColors.warning,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  '서류 확인 중이에요',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: kPubText,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '제출하신 사업자등록증을 검토하고 있어요.\n보통 당일~1영업일 내 처리됩니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: kPubText.withOpacity(0.5),
                    height: 1.7,
                  ),
                ),

                const SizedBox(height: 32),

                // 상태 카드
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '검토가 완료되면 공고 작성이 자동으로 열려요.',
                          style: TextStyle(
                            fontSize: 13,
                            color: kPubText.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 새로고침 버튼
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _checkApproval,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('승인 여부 확인하기'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPubBlue,
                      side: const BorderSide(color: kPubBlue),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 문의하기
                TextButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder:
                          (dialogCtx) => AppModalDialog(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '문의하기',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                const Text(
                                  '검토가 늦어지거나 문제가 있으신가요?\n\n이메일로 문의해주세요:\nsupport@chikabooks.com',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    height: 1.45,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogCtx),
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          AppColors.textSecondary,
                                      backgroundColor:
                                          AppColors.surfaceMuted,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.md,
                                        ),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    child: const Text('닫기'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                    );
                  },
                  child: Text(
                    '문의하기',
                    style: TextStyle(
                      fontSize: 13,
                      color: kPubText.withOpacity(0.45),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


