import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/web_site_footer.dart';

/// 고객지원 (`/support`) — 웹 정적 `support.html`과 동일 내용 (브랜드: 하이진랩 / HygieneLab, `pubspec` 버전 예시 반영)
class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  static TextStyle _body(BuildContext context) => GoogleFonts.notoSansKr(
        fontSize: 15,
        height: 1.75,
        color: AppColors.textPrimary,
      );

  static TextStyle _h2(BuildContext context) => GoogleFonts.notoSansKr(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  @override
  Widget build(BuildContext context) {
    final body = _body(context);
    final h2 = _h2(context);

    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        backgroundColor: AppColors.appBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
        title: Text(
          '하이진랩 앱 지원',
          style: GoogleFonts.notoSansKr(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(
              '안녕하세요. 하이진랩 앱 지원 페이지입니다.',
              style: body,
            ),
            const SizedBox(height: 16),
            Text(
              '"하이진랩"(영문 HygieneLab, 이하 "서비스")는 치과위생사 및 관련 전공자를 위한 학습, 성장, 커리어, 정보 탐색을 돕는 모바일 서비스입니다.\n'
              '앱 이용 중 문의사항, 오류 제보, 계정 관련 요청이 있으시면 아래 방법으로 연락해 주세요.',
              style: body,
            ),
            const SizedBox(height: 24),
            Text('문의 방법', style: h2),
            const SizedBox(height: 8),
            _EmailRow(body: body),
            const SizedBox(height: 24),
            Text('문의 가능 내용', style: h2),
            const SizedBox(height: 8),
            ..._bullets(body, const [
              '앱 실행 오류 및 접속 문제',
              '로그인 및 계정 관련 문의',
              '전자책 열람 오류',
              '구매 또는 이용 내역 관련 문의',
              '구직/커리어 기능 관련 문의',
              '기타 서비스 이용 중 불편사항 및 개선 의견',
            ]),
            const SizedBox(height: 24),
            Text('문의 접수 시 함께 보내주시면 좋은 정보', style: h2),
            const SizedBox(height: 8),
            Text(
              '보다 빠르고 정확한 확인을 위해 아래 내용을 함께 보내주시면 도움이 됩니다.',
              style: body,
            ),
            const SizedBox(height: 8),
            ..._bullets(body, const [
              '사용 기기: 예) iPhone 15 Pro Max',
              '운영체제 버전: 예) iOS 18.x',
              '앱 버전: 예) 1.1.0',
              '문제 발생 시점',
              '문제가 발생한 화면 또는 기능 이름',
              '오류 메시지 내용',
              '가능하다면 관련 스크린샷',
            ]),
            const SizedBox(height: 24),
            Text('답변 안내', style: h2),
            const SizedBox(height: 8),
            Text(
              '문의 메일은 접수 순서대로 확인하며, 영업일 기준 최대 3일 이내 답변을 드리기 위해 노력하고 있습니다.\n'
              '다만 문의량이 많거나 추가 확인이 필요한 경우 답변이 다소 지연될 수 있습니다.',
              style: body,
            ),
            const SizedBox(height: 24),
            Text('계정 및 개인정보 관련', style: h2),
            const SizedBox(height: 8),
            Text(
              '개인정보 처리와 관련한 사항은 아래 개인정보처리방침을 참고해 주세요.',
              style: body,
            ),
            TextButton(
              onPressed: () => context.push('/privacy'),
              child: Text(
                '개인정보처리방침 보기',
                style: GoogleFonts.notoSansKr(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '서비스 이용 기준 및 운영 원칙은 아래 이용약관을 참고해 주세요.',
              style: body,
            ),
            TextButton(
              onPressed: () => context.push('/terms'),
              child: Text(
                '이용약관 보기',
                style: GoogleFonts.notoSansKr(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('계정 삭제 요청', style: h2),
            const SizedBox(height: 8),
            Text(
              '회원 탈퇴 또는 계정 삭제를 원하시는 경우 앱 내 제공 기능을 이용하시거나, 위 문의 이메일로 요청해 주세요.\n'
              '요청 확인 후 관련 절차에 따라 처리됩니다.',
              style: body,
            ),
            const SizedBox(height: 24),
            Text('서비스 안내', style: h2),
            const SizedBox(height: 8),
            Text(
              '하이진랩은 치과위생사의 실무 학습과 정보 접근성을 높이기 위해 전자책, 학습 기능, 성장형 콘텐츠, 커리어 관련 기능을 제공하고 있습니다.\n'
              '일부 기능은 서비스 업데이트에 따라 변경되거나 추가될 수 있습니다.',
              style: body,
            ),
            const SizedBox(height: 32),
            Divider(color: AppColors.divider),
            const SizedBox(height: 16),
            Text('감사합니다.', style: body),
            const SizedBox(height: 8),
            Text(
              '하이진랩 드림',
              style: GoogleFonts.notoSansKr(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const WebSiteFooter(backgroundColor: AppColors.appBg),
    );
  }

  static List<Widget> _bullets(TextStyle body, List<String> lines) {
    return lines
        .map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: body),
                Expanded(child: Text(line, style: body)),
              ],
            ),
          ),
        )
        .toList();
  }
}

class _EmailRow extends StatelessWidget {
  const _EmailRow({required this.body});

  final TextStyle body;

  @override
  Widget build(BuildContext context) {
    const email = 'chikabooks.app@gmail.com';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('이메일: ', style: body),
        Expanded(
          child: InkWell(
            onTap: () async {
              final uri = Uri.parse('mailto:$email');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            child: Text(
              email,
              style: body.copyWith(
                color: AppColors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
