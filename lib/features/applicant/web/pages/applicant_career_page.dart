import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../pages/career/career_tab.dart';
import '../widgets/applicant_web_shell.dart';

/// `/me/profile` — 커리어 카드 (웹).
///
/// 모바일과 동일한 [CareerTab] 위젯(인적사항·이력서/지원 단축·스킬·커리어 단계
/// & 네트워크 통합 카드)을 [ApplicantWebShell] 안에 그대로 배치한다.
///
/// CareerTab 자체가 [ListView] 로 스크롤을 직접 처리하므로 셸의
/// `scrollable` 은 false 로 두어 이중 스크롤을 방지한다.
class ApplicantCareerPage extends StatelessWidget {
  const ApplicantCareerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ApplicantWebShell(
      scrollable: false,
      // 페이지 자체 헤더는 콘텐츠 위로 두고, 본문은 CareerTab 의 ListView 가
      // 자체 패딩/스크롤을 처리하도록 그대로 노출한다.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          _PageHeader(),
          Expanded(child: CareerTab()),
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
            '커리어 카드',
            style: GoogleFonts.notoSansKr(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '내 인적 정보·스킬·경력 네트워크를 한 화면에서 채우고 관리해 보세요.',
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
