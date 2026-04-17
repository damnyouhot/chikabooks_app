import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/web_site_footer.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/web/web_account_menu_button.dart';

/// 게시 완료 페이지 (/post-job/success/:jobId)
class JobPublishSuccessPage extends StatelessWidget {
  final String jobId;
  const JobPublishSuccessPage({super.key, required this.jobId});

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
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 44,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '공고가 게시되었어요!',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '구직자들이 지금 바로 볼 수 있어요',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // 게시된 공고 보기
                      SizedBox(
                        width: double.infinity,
                        height: AppPublisher.ctaHeight,
                        child: ElevatedButton(
                          onPressed: () => context.go('/post-job'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppPublisher.buttonRadius,
                              ),
                            ),
                          ),
                          child: Text(
                            '공고 관리 페이지로',
                            style: GoogleFonts.notoSansKr(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 새 공고 추가
                      SizedBox(
                        width: double.infinity,
                        height: AppPublisher.ctaHeight,
                        child: OutlinedButton(
                          onPressed: () => context.go('/post-job/input'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.accent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppPublisher.buttonRadius,
                              ),
                            ),
                          ),
                          child: Text(
                            '새 공고 추가하기',
                            style: GoogleFonts.notoSansKr(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (kIsWeb) const WebSiteFooter(backgroundColor: AppColors.white),
        ],
      ),
    );
  }
}
