import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// 공고 등록 흐름 상단바에서 사용하는 페이지 단계 정의
class JobPostStep {
  const JobPostStep({required this.title});

  final String title;

  static const home = JobPostStep(title: '홈');
  static const input = JobPostStep(title: '공고 시작');
  static const edit = JobPostStep(title: '공고 확인 / 인증');
  static const product = JobPostStep(title: '공고플랜');
}

/// 공고 등록 흐름 공통 상단바.
///
/// 기준 디자인은 기존 「게시 단계로」 ElevatedButton(accent 배경, w800)을 따른다.
/// 좌측 [prevStep], 우측 [nextStep]에 각각 `<`, `>` 아이콘과 함께 다음/이전 페이지명을 표시한다.
/// `prevStep`/`nextStep`이 null 이면 해당 위치 버튼은 표시되지 않는다.
class JobPostTopBar extends StatelessWidget {
  const JobPostTopBar({
    super.key,
    required this.currentStep,
    this.prevStep,
    this.nextStep,
    this.onPrev,
    this.onNext,
    this.leading,
    this.trailing,
  });

  /// 중앙 타이틀에 표기되는 현재 단계
  final JobPostStep currentStep;

  /// 좌측 버튼 라벨에 사용되는 이전 단계 (없으면 표시하지 않음)
  final JobPostStep? prevStep;

  /// 우측 버튼 라벨에 사용되는 다음 단계 (없으면 표시하지 않음)
  final JobPostStep? nextStep;

  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  /// 좌측 버튼 자리에 들어갈 커스텀 위젯 (prevStep 보다 우선)
  final Widget? leading;

  /// 우측 버튼 자리에 들어갈 커스텀 위젯 (nextStep 보다 우선)
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          if (leading != null)
            leading!
          else if (prevStep != null)
            _StepNavButton(
              step: prevStep!,
              direction: _NavDirection.prev,
              onPressed: onPrev,
            ),
          const Spacer(),
          _CenterTitle(step: currentStep),
          const Spacer(),
          if (trailing != null)
            trailing!
          else if (nextStep != null)
            _StepNavButton(
              step: nextStep!,
              direction: _NavDirection.next,
              onPressed: onNext,
            ),
        ],
      ),
    );
  }
}

class _CenterTitle extends StatelessWidget {
  const _CenterTitle({required this.step});

  final JobPostStep step;

  @override
  Widget build(BuildContext context) {
    return Text(
      step.title,
      style: GoogleFonts.notoSansKr(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: AppColors.textPrimary,
      ),
    );
  }
}

enum _NavDirection { prev, next }

/// 좌(이전)/우(다음) 단계 이동용 버튼.
///
/// `JobPostTopBar`의 `leading`/`trailing`에 다른 위젯과 함께 배치할 때 직접 사용한다.
class JobStepNavButton extends StatelessWidget {
  const JobStepNavButton.prev({
    super.key,
    required this.step,
    required this.onPressed,
  }) : direction = _NavDirection.prev;

  const JobStepNavButton.next({
    super.key,
    required this.step,
    required this.onPressed,
  }) : direction = _NavDirection.next;

  final JobPostStep step;
  final _NavDirection direction;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => _StepNavButton(
        step: step,
        direction: direction,
        onPressed: onPressed,
      );
}

class _StepNavButton extends StatelessWidget {
  const _StepNavButton({
    required this.step,
    required this.direction,
    required this.onPressed,
  });

  final JobPostStep step;
  final _NavDirection direction;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isPrev = direction == _NavDirection.prev;
    final label = Text(
      step.title,
      style: GoogleFonts.notoSansKr(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: AppColors.white,
      ),
    );

    return SizedBox(
      height: AppPublisher.ctaHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPrev) ...[
              const Icon(Icons.chevron_left, size: 18),
              const SizedBox(width: 4),
              label,
            ] else ...[
              label,
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
