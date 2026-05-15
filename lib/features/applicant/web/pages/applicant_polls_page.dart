import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../widgets/bond/bond_poll_section.dart';
import '../widgets/applicant_web_shell.dart';

/// `/bond/polls` — 공감투표 (웹).
///
/// 모바일과 동일한 [BondPollSection] 위젯을 [ApplicantWebShell] 안에 그대로 배치한다.
/// 좌측 사이드바 + 본문 폭 제한(`AppApplicant.contentMaxWidth`) 이 적용되므로
/// 데스크탑에서도 가독성을 유지한 한 칼럼 레이아웃으로 노출된다.
class ApplicantPollsPage extends StatelessWidget {
  const ApplicantPollsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ApplicantWebShell(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          _PageHeader(),
          SizedBox(height: 16),
          BondPollSection(),
          SizedBox(height: 60),
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
            '공감투표',
            style: GoogleFonts.notoSansKr(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '오늘의 한 표로 같은 마음을 발견해 보세요. 종료된 투표에는 한마디를 남길 수 있어요.',
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
