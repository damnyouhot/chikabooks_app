import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── 치카북스 게시자 화면 공통 팔레트 ─────────────────────
const kPubBg = Color(0xFFF8F6F9);
const kPubText = Color(0xFF3D4A5C);
const kPubBlue = Color(0xFF4A90D9);
const kPubPink = Color(0xFFF7CBCA);
const kPubPinkDark = Color(0xFFE57373);
const kPubBorder = Color(0xFFE0D8E8);
const kPubCard = Colors.white;

// ── 공통 텍스트 필드 ──────────────────────────────────────
class PubTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  const PubTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.notoSansKr(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.3,
        color: kPubText,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        hintStyle: GoogleFonts.notoSansKr(
          fontSize: 13,
          letterSpacing: -0.2,
          color: kPubText.withOpacity(0.4),
        ),
        labelStyle: GoogleFonts.notoSansKr(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.2,
          color: kPubText.withOpacity(0.7),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPubBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPubBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPubBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kPubPinkDark.withOpacity(0.7)),
        ),
        filled: true,
        fillColor: kPubBg,
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
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPubBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
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
                    color: Colors.white,
                  ),
                )
                : Text(
                  label,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
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

  const PubScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPubBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: showBack,
        leading:
            showBack
                ? IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: kPubText,
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
                color: kPubText,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: GoogleFonts.notoSansKr(
                  color: kPubText.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                ),
              ),
          ],
        ),
      ),
      body: child,
    );
  }
}


