import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../senior_qna/widgets/senior_question_feed.dart';
import '../widgets/applicant_web_shell.dart';

/// `/bond/qna` — 시니어 Q&A (웹).
///
/// 모바일과 동일한 [SeniorQuestionFeed] 위젯(질문 작성 컴포저 + 질문 카드 피드)
/// 을 [ApplicantWebShell] 안에 그대로 배치한다.
///
/// SeniorQuestionFeed 자체가 [ListView] 로 스크롤을 처리하므로 셸의
/// `scrollable` 은 false 로 두어 이중 스크롤을 방지한다.
class ApplicantSeniorQnaPage extends StatelessWidget {
  const ApplicantSeniorQnaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ApplicantWebShell(
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          _PageHeader(),
          Expanded(child: SeniorQuestionFeed()),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '속닥속닥',
            style: GoogleFonts.notoSansKr(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '동료에게 살짝 묻고 싶은 한 마디. 익명으로 편하게 적어 보세요.',
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
