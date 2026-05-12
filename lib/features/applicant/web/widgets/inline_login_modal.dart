import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../services/apple_auth_service.dart';
import '../../../../services/kakao_auth_service.dart';
import '../../../../services/naver_auth_service.dart';
import '../../../../services/sign_in_tracker.dart';
import '../../../publisher/services/clinic_auth_service.dart';

const _kNaver = Color(0xFF03C75A);

/// 페이지 이동 없이 로그인 단계를 끼워넣기 위한 인라인 로그인 모달.
///
/// 사용 흐름:
///  1) 로그인 필요한 액션(공고 클릭, 지원하기 등)에서 [showInlineLoginRequired] 호출.
///  2) 모달이 떠 있는 동안 사용자가 카카오/구글/애플로 로그인.
///  3) 로그인 성공 → 모달 자동 닫힘 + Future 가 `true` 로 resolve.
///  4) 호출부는 그 자리에서 원래 하려던 액션을 이어서 실행.
///
/// 더 풍부한 옵션(네이버/이메일 가입 등)이 필요하면 모달 하단의 "이메일로 로그인"
/// 버튼이 통합 로그인 페이지(`/login?next=...`)로 안내한다.
Future<bool> showInlineLoginRequired(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? nextPath,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _InlineLoginDialog(
      title: title,
      subtitle: subtitle,
      nextPath: nextPath,
    ),
  );
  return result == true;
}

class _InlineLoginDialog extends StatefulWidget {
  const _InlineLoginDialog({
    required this.title,
    this.subtitle,
    this.nextPath,
  });

  final String title;
  final String? subtitle;
  final String? nextPath;

  @override
  State<_InlineLoginDialog> createState() => _InlineLoginDialogState();
}

class _InlineLoginDialogState extends State<_InlineLoginDialog> {
  StreamSubscription<User?>? _authSub;
  String? _busyProvider;
  String? _errorMsg;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    // 로그인 성공을 인라인으로 감지: signInWith*가 끝나기 전에 SDK 가
    // currentUser 를 채울 수 있으므로 stream listener 로 안전하게 처리.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null || _closed || !mounted) return;

      // 치과 전용 계정이 SNS 로그인으로 들어왔다면 즉시 차단(로그아웃)
      final blockMsg =
          await ClinicAuthService.blockClinicAccountFromApplicantLogin();
      if (!mounted) return;
      if (blockMsg != null) {
        setState(() {
          _busyProvider = null;
          _errorMsg = blockMsg;
        });
        return;
      }

      // 로그인 확정 → 모달 닫기 (호출부는 그대로 액션 이어가기 가능)
      _closed = true;
      Navigator.of(context).pop(true);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _signInGoogle() async {
    setState(() {
      _busyProvider = 'google';
      _errorMsg = null;
    });
    try {
      final googleProvider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      await FirebaseAuth.instance.signInWithPopup(googleProvider);
      // 성공 시 authStateChanges 리스너에서 닫힘 처리
      await SignInTracker.record('google');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busyProvider = null;
        _errorMsg = 'Google 로그인 오류: $e';
      });
    }
  }

  Future<void> _signInKakao() async {
    setState(() {
      _busyProvider = 'kakao';
      _errorMsg = null;
    });
    try {
      final user = await KakaoAuthService.signInWithKakao();
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _busyProvider = null;
          _errorMsg = '카카오 로그인에 실패했어요. 다시 시도해주세요.';
        });
        return;
      }
      await SignInTracker.record('kakao');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busyProvider = null;
        _errorMsg = '카카오 로그인 오류: $e';
      });
    }
  }

  Future<void> _signInApple() async {
    setState(() {
      _busyProvider = 'apple';
      _errorMsg = null;
    });
    try {
      final user = await AppleAuthService.signInWithApple();
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _busyProvider = null;
          _errorMsg = 'Apple 로그인에 실패했어요.';
        });
        return;
      }
      await SignInTracker.record('apple');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busyProvider = null;
        _errorMsg = 'Apple 로그인 오류: $e';
      });
    }
  }

  Future<void> _signInNaver() async {
    setState(() {
      _busyProvider = 'naver';
      _errorMsg = null;
    });
    try {
      final result = await NaverAuthService.signInWithNaver();
      if (result.user == null) {
        if (!mounted) return;
        setState(() {
          _busyProvider = null;
          _errorMsg = result.errorMessage ?? '네이버 로그인에 실패했어요.';
        });
        return;
      }
      await SignInTracker.record('naver');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busyProvider = null;
        _errorMsg = '네이버 로그인 오류: $e';
      });
    }
  }

  void _goFullLoginPage() {
    Navigator.of(context).pop(false);
    final next = widget.nextPath;
    final query = (next != null && next.isNotEmpty)
        ? '?next=${Uri.encodeComponent(next)}'
        : '';
    GoRouter.of(context).push('/login$query');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.notoSansKr(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1.35,
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle!,
                            style: GoogleFonts.notoSansKr(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    iconSize: 18,
                    splashRadius: 18,
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textDisabled,
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    tooltip: '닫기',
                  ),
                ],
              ),
              const SizedBox(height: 22),

              _SocialBtn(
                provider: 'kakao',
                label: '카카오로 1초만에 로그인',
                icon: Icons.chat_bubble,
                bg: const Color(0xFFFEE500),
                fg: Colors.black87,
                busy: _busyProvider == 'kakao',
                onPressed: _busyProvider == null ? _signInKakao : null,
              ),
              const SizedBox(height: 8),
              _SocialBtn(
                provider: 'google',
                label: 'Google로 로그인',
                icon: Icons.g_mobiledata,
                bg: AppColors.white,
                fg: Colors.black87,
                border: AppColors.divider,
                busy: _busyProvider == 'google',
                onPressed: _busyProvider == null ? _signInGoogle : null,
              ),
              const SizedBox(height: 8),
              _SocialBtn(
                provider: 'naver',
                label: '네이버로 로그인',
                icon: Icons.text_fields_rounded,
                bg: _kNaver,
                fg: AppColors.white,
                busy: _busyProvider == 'naver',
                onPressed: _busyProvider == null ? _signInNaver : null,
              ),
              const SizedBox(height: 8),
              _SocialBtn(
                provider: 'apple',
                label: 'Apple로 로그인',
                icon: Icons.apple,
                bg: Colors.black,
                fg: AppColors.white,
                busy: _busyProvider == 'apple',
                onPressed: _busyProvider == null ? _signInApple : null,
              ),

              if (_errorMsg != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 16,
                        color: AppColors.error.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMsg!,
                          style: GoogleFonts.notoSansKr(
                            fontSize: 12,
                            color: AppColors.error.withValues(alpha: 0.95),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.divider)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '또는',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 11,
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: AppColors.divider)),
                ],
              ),
              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: _goFullLoginPage,
                icon: const Icon(Icons.email_outlined, size: 17),
                label: Text(
                  '이메일로 로그인 / 회원가입',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.divider),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialBtn extends StatelessWidget {
  const _SocialBtn({
    required this.provider,
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.busy,
    required this.onPressed,
    this.border,
  });

  final String provider;
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final bool busy;
  final VoidCallback? onPressed;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: busy
            ? SizedBox(
                width: 16,
                height: 16,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            : Icon(icon, color: fg, size: 20),
        label: Text(
          label,
          style: GoogleFonts.notoSansKr(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: border != null
                ? BorderSide(color: border!)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
