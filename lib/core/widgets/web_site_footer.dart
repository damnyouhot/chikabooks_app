import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// 웹 공통 하단 사업자 정보(토스 등 심사용) 및 약관 링크
///
/// 하단 **좌우 전체 폭** 띠로 표시되며, 1줄: 사업자 정보 / 2줄: 저작권·약관 링크.
class WebSiteFooter extends StatelessWidget {
  const WebSiteFooter({
    super.key,
    this.backgroundColor = AppColors.white,
    this.showLegalLinks = true,
    this.padding = const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
  });

  final Color backgroundColor;
  final bool showLegalLinks;
  final EdgeInsets padding;

  static const double _fontSize = 10;

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.notoSansKr(
      fontSize: _fontSize,
      height: 1.0,
      color: AppColors.textDisabled,
    );
    // 둘째 줄도 첫째 줄과 동일한 폰트/사이즈/색상으로 통일하고, 링크만 밑줄로 구분
    final linkStyle = textStyle.copyWith(
      decoration: TextDecoration.underline,
      decorationColor: AppColors.textDisabled,
    );

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: backgroundColor,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '상호: 더글라스필름  |  대표: 홍덕우  |  사업자등록번호: 211-09-93780  |  '
                  '사업장 주소: 서울시 강남구 역삼로 215 남국빌딩 2층  |  전화: 070-8200-1030',
                  textAlign: TextAlign.center,
                  style: textStyle,
                ),
                if (showLegalLinks) ...[
                  const SizedBox(height: 7),
                  Align(
                    alignment: Alignment.center,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        Text('© 하이진랩', style: textStyle),
                        Text('·', style: textStyle),
                        _FooterLink(
                          label: '개인정보처리방침',
                          onTap: () => context.push('/privacy'),
                          style: linkStyle,
                        ),
                        Text('·', style: textStyle),
                        _FooterLink(
                          label: '이용약관',
                          onTap: () => context.push('/terms'),
                          style: linkStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({
    required this.label,
    required this.onTap,
    required this.style,
  });

  final String label;
  final VoidCallback onTap;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(label, style: style),
      ),
    );
  }
}
