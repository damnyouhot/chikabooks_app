import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

// ── 하이진랩 게시자 화면 공통 팔레트 ─────────────────────
// 아래 상수들은 외부 참조(web_login_page 등)가 있으므로 이름은 유지하되
// AppColors 토큰으로 값을 통일합니다.
const kPubBg      = AppColors.appBg;
const kPubText    = AppColors.textPrimary;
const kPubBlue    = AppColors.accent;
// kPubPink: AppColors.error(0xFFE57373) 계열 연분홍 — const 한계로 리터럴 유지
const kPubPink    = Color(0xFFF7CBCA); // ≈ AppColors.error.withOpacity(0.25)
const kPubPinkDark = AppColors.error;
const kPubBorder  = AppColors.divider;
const kPubCard    = AppColors.white;

// ── 공통 텍스트 필드 ──────────────────────────────────────
class PubTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  /// true: 라운드 없는 테두리 + [fieldFillColor] (웹 통합 로그인 등)
  final bool squareOutline;
  final Color? fieldFillColor;

  const PubTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.suffixIcon,
    this.squareOutline = false,
    this.fieldFillColor,
  });

  @override
  Widget build(BuildContext context) {
    final radius =
        squareOutline ? BorderRadius.zero : BorderRadius.circular(12);
    final fill = fieldFillColor ?? AppColors.appBg;

    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.notoSansKr(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.18,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        hintStyle: GoogleFonts.notoSansKr(
          fontSize: 13,
          letterSpacing: -0.12,
          color: AppColors.textDisabled,
        ),
        labelStyle: GoogleFonts.notoSansKr(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.12,
          color: AppColors.textSecondary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.error.withOpacity(0.7)),
        ),
        filled: true,
        fillColor: fill,
      ),
    );
  }
}

// ── 메인 CTA 버튼 ─────────────────────────────────────────
class PubPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const PubPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child:
            isLoading
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
                : Text(
                  label,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.18,
                  ),
                ),
      ),
    );
  }
}

// ── 게시자 화면 공통 레이아웃 ────────────────────────────
class PubScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final bool showBack;

  /// true: 웹 공고자 인증 진행(흰 배경·상단 라인 구분)
  final bool webPublisherShell;

  const PubScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.showBack = true,
    this.webPublisherShell = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = webPublisherShell ? AppColors.white : AppColors.appBg;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: showBack,
        bottom:
            webPublisherShell
                ? PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(height: 1, color: AppColors.divider),
                )
                : null,
        leading:
            showBack
                ? IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: AppColors.textPrimary,
                    size: 18,
                  ),
                  onPressed:
                      () =>
                          Navigator.canPop(context)
                              ? Navigator.pop(context)
                              : null,
                )
                : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.notoSansKr(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: GoogleFonts.notoSansKr(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.06,
                ),
              ),
          ],
        ),
      ),
      body: child,
    );
  }
}
