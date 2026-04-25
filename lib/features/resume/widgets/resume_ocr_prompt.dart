import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_primary_button.dart';

class ResumeOcrPrompt extends StatelessWidget {
  const ResumeOcrPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '가지고 계신 이력서를 촬영 또는 업로드하면 내용이 자동으로 항목별 입력됩니다.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppPrimaryButton(
          label: '사진으로 입력하기',
          onPressed:
              () => GoRouter.of(context).push('/applicant/resumes/import'),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
