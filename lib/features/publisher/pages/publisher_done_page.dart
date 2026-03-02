import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'publisher_shared.dart';

/// 게시자 인증 완료 화면 (/publisher/done)
class PublisherDonePage extends StatelessWidget {
  const PublisherDonePage({super.key});

  @override
  Widget build(BuildContext context) {
    return PubScaffold(
      title: '인증 완료',
      showBack: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 완료 아이콘
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: kPubBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: kPubBlue,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 28),

                const Text(
                  '인증이 완료됐어요!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: kPubText,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '이제 구인 공고를 작성하고\n치과위생사를 찾을 수 있어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: kPubText.withOpacity(0.5),
                    height: 1.7,
                  ),
                ),

                const SizedBox(height: 32),

                // 완료 배지
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kPubBlue.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kPubBlue.withOpacity(0.15)),
                  ),
                  child: Column(
                    children: [
                      _checkRow('휴대폰 본인확인', true),
                      const SizedBox(height: 8),
                      _checkRow('기본 정보 입력', true),
                      const SizedBox(height: 8),
                      _checkRow('사업자 인증', true),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                PubPrimaryButton(
                  label: '공고 작성 시작하기',
                  onPressed: () => context.go('/post-job'),
                ),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: () => context.go('/publisher/onboarding'),
                  child: Text(
                    '홈으로 돌아가기',
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

  Widget _checkRow(String label, bool done) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 18,
          color: done ? kPubBlue : kPubBorder,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: done ? kPubText : kPubText.withOpacity(0.4),
            fontWeight: done ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}


