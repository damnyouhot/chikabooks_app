import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/kakao_auth_service.dart';
import '../../../services/apple_auth_service.dart';
import '../../../services/email_auth_service.dart';
import '../../../services/sign_in_tracker.dart';
import '../../publisher/services/clinic_auth_service.dart';
import '../../publisher/pages/publisher_shared.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// 통합 로그인 페이지 (/login)
///
/// 좌: 지원자 로그인 (카카오 · 구글 · 애플 · 이메일  /  네이버는 앱 전용)
/// 우: 치과 로그인 (이메일/비밀번호)
class WebLoginPage extends StatefulWidget {
  final String? nextRoute;
  const WebLoginPage({super.key, this.nextRoute});

  @override
  State<WebLoginPage> createState() => _WebLoginPageState();
}

class _WebLoginPageState extends State<WebLoginPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.xxl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                _buildLogo(),
                const SizedBox(height: AppSpacing.xxl),

                // ── 좌(지원자) / 우(치과) ────────────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 620) {
                      return Column(
                        children: [
                          _ApplicantLoginCard(nextRoute: widget.nextRoute),
                          const SizedBox(height: 20),
                          _ClinicLoginCard(nextRoute: widget.nextRoute),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _ApplicantLoginCard(
                            nextRoute: widget.nextRoute,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _ClinicLoginCard(nextRoute: widget.nextRoute),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: AppSpacing.xxl),

                // ── 하단 링크 ────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '© 치카북스',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textDisabled,
                        ),
                      ),
                      const SizedBox(width: 16),
                      _link('개인정보처리방침', '/privacy'),
                      _dot(),
                      _link('이용약관', '/terms'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.local_hospital_outlined,
            size: 28,
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '치카북스',
          style: GoogleFonts.notoSansKr(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '치과 커뮤니티 & 구인구직 플랫폼',
          style: GoogleFonts.notoSansKr(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _link(String label, String path) {
    return InkWell(
      onTap: () => context.push(path),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.textDisabled,
          ),
        ),
      ),
    );
  }

  Widget _dot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text('·', style: TextStyle(color: AppColors.textDisabled)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 지원자 로그인 카드 (소셜 + 이메일)
// ═══════════════════════════════════════════════════════════════
class _ApplicantLoginCard extends StatefulWidget {
  final String? nextRoute;
  const _ApplicantLoginCard({this.nextRoute});

  @override
  State<_ApplicantLoginCard> createState() => _ApplicantLoginCardState();
}

class _ApplicantLoginCardState extends State<_ApplicantLoginCard> {
  bool _isLoading = false;
  String? _loadingProvider;
  String? _errorMsg;
  bool _showEmailForm = false;
  bool _isSignUp = false;
  String? _lastProvider;

  // 네이버 비밀번호 설정 링크 전송 폼
  bool _showNaverResetForm = false;
  bool _naverResetSent = false;
  bool _naverResetLoading = false;
  final _naverEmailCtrl = TextEditingController();

  // 네이버 비밀번호 설정 완료 기록 (SharedPreferences)
  String? _naverPwSetEmail;

  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBadge();
  }

  Future<void> _loadBadge() async {
    final p = await SignInTracker.getLocalLastProvider();
    final prefs = await SharedPreferences.getInstance();
    final naverEmail = prefs.getString('naver_pw_set_email');
    if (mounted) {
      setState(() {
        _lastProvider = p;
        _naverPwSetEmail = naverEmail;
        if (naverEmail != null) {
          _showEmailForm = true;
          _emailCtrl.text = naverEmail;
        }
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _naverEmailCtrl.dispose();
    super.dispose();
  }

  // ── 로그인 후 공통 라우팅 ──────────────────────────────────
  Future<void> _handlePostLogin(String provider) async {
    if (!mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // 공고자 계정인지 확인 → clinics_accounts 문서 존재 시 차단
      final clinicDoc = await FirebaseFirestore.instance
          .collection('clinics_accounts')
          .doc(uid)
          .get();
      if (clinicDoc.exists) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        _showError(
          '이 계정은 공고자 계정으로 등록되어 있어 위생사 로그인을 할 수 없습니다.\n'
          '오른쪽의 치과 로그인을 이용해주세요.',
        );
        return;
      }

      await SignInTracker.record(provider);
      if (!mounted) return;
      context.go(widget.nextRoute ?? '/applicant/resumes');
    } catch (_) {
      if (mounted) context.go(widget.nextRoute ?? '/applicant/resumes');
    }
  }

  // ── 카카오 ─────────────────────────────────────────────────
  Future<void> _loginKakao() async {
    _setLoading('kakao');
    try {
      final user = await KakaoAuthService.signInWithKakao();
      if (user == null) {
        _showError('카카오 로그인에 실패했어요. 다시 시도해주세요.');
        return;
      }
      await _handlePostLogin('kakao');
    } catch (e) {
      _showError('카카오 로그인 오류: $e');
    } finally {
      _clearLoading();
    }
  }

  // ── 구글 ───────────────────────────────────────────────────
  Future<void> _loginGoogle() async {
    _setLoading('google');
    try {
      // 웹에서는 signInWithPopup 방식 사용 (idToken null 문제 해결)
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      final userCredential = await FirebaseAuth.instance.signInWithPopup(
        googleProvider,
      );

      if (userCredential.user == null) {
        _showError('Google 로그인에 실패했어요.');
        return;
      }
      await _handlePostLogin('google');
    } catch (e) {
      _showError('Google 로그인 오류: $e');
    } finally {
      _clearLoading();
    }
  }

  // ── 애플 ───────────────────────────────────────────────────
  Future<void> _loginApple() async {
    _setLoading('apple');
    try {
      final user = await AppleAuthService.signInWithApple();
      if (user == null) {
        _showError('Apple 로그인에 실패했어요.');
        return;
      }
      await _handlePostLogin('apple');
    } catch (e) {
      _showError('Apple 로그인 오류: $e');
    } finally {
      _clearLoading();
    }
  }

  // ── 네이버 웹 비밀번호 설정 링크 발송 ──────────────────────
  Future<void> _sendNaverPasswordReset() async {
    final email = _naverEmailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMsg = '올바른 이메일 주소를 입력해주세요.');
      return;
    }
    setState(() {
      _naverResetLoading = true;
      _errorMsg = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        // SharedPreferences에 네이버 이메일 저장 → 다음 방문 시 안내
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('naver_pw_set_email', email);
        setState(() {
          _naverResetSent = true;
          _naverResetLoading = false;
          _naverPwSetEmail = email;
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _naverResetLoading = false;
          _errorMsg = e.code == 'user-not-found'
              ? '등록된 이메일이 아니에요. 가입한 네이버 이메일을 다시 확인해주세요.'
              : '발송 중 오류가 발생했어요. 다시 시도해주세요.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _naverResetLoading = false;
          _errorMsg = '발송 중 오류가 발생했어요. 다시 시도해주세요.';
        });
      }
    }
  }

  // ── 이메일 ─────────────────────────────────────────────────
  Future<void> _loginEmail() async {
    final email = _emailCtrl.text.trim();
    final password = _pwCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showError('이메일과 비밀번호를 입력해주세요.');
      return;
    }
    _setLoading('email');
    try {
      User? user;
      if (_isSignUp) {
        if (password.length < 8) {
          _showError('비밀번호는 8자 이상이어야 해요.');
          return;
        }
        // 회원가입 전: 공고자 계정 중복 체크 (normalizedEmail 기준)
        final dupMsg =
            await ClinicAuthService.checkDuplicateForApplicantSignup(email);
        if (dupMsg != null) {
          _showError(dupMsg);
          return;
        }
        user = await EmailAuthService.signUp(email: email, password: password);
      } else {
        user = await EmailAuthService.signIn(email: email, password: password);
      }
      if (user == null) {
        _showError(_isSignUp ? '회원가입에 실패했어요.' : '로그인에 실패했어요.');
        return;
      }
      await _handlePostLogin('email');
    } on FirebaseAuthException catch (e) {
      _showError(_mapAuthError(e.code));
    } catch (e) {
      _showError('이메일 로그인 오류: $e');
    } finally {
      _clearLoading();
    }
  }

  // ── 헬퍼 ───────────────────────────────────────────────────
  void _setLoading(String p) {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadingProvider = p;
        _errorMsg = null;
      });
    }
  }

  void _clearLoading() {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _loadingProvider = null;
      });
    }
  }

  void _showError(String msg) {
    if (mounted) setState(() => _errorMsg = msg);
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return '등록되지 않은 이메일이에요.';
      case 'wrong-password':
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 올바르지 않아요.';
      case 'email-already-in-use':
        return '이미 사용 중인 이메일이에요.';
      case 'weak-password':
        return '비밀번호가 너무 약해요.';
      default:
        return '로그인 중 오류가 발생했어요.';
    }
  }

  // ── UI ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.divider.withOpacity(0.25),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 제목 ─────────────────────────────
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '지원자 (치과위생사)',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '이력서 작성 · 공고 지원',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── 소셜 로그인 버튼들 ──────────────
          _snsBtn(
            'kakao',
            Icons.chat_bubble,
            '카카오로 로그인',
            const Color(0xFFFEE500),
            Colors.black87,
            _loginKakao,
          ),
          const SizedBox(height: AppSpacing.sm),
          _snsBtn(
            'google',
            Icons.g_mobiledata,
            'Google로 로그인',
            AppColors.white,
            Colors.black87,
            _loginGoogle,
            border: AppColors.divider,
          ),
          const SizedBox(height: AppSpacing.sm),
          _snsBtn(
            'apple',
            Icons.apple,
            'Apple로 로그인',
            Colors.black,
            AppColors.white,
            _loginApple,
          ),
          const SizedBox(height: AppSpacing.sm),

          // 네이버 (웹: 비밀번호 설정 링크 방식)
          _snsBtn(
            'naver',
            Icons.language,
            '네이버로 로그인',
            _naverPwSetEmail != null
                ? AppColors.textDisabled
                : const Color(0xFF03C75A),
            AppColors.white,
            _naverPwSetEmail != null
                ? null
                : () {
                    setState(() {
                      _showNaverResetForm = !_showNaverResetForm;
                      _naverResetSent = false;
                      _naverEmailCtrl.clear();
                      _errorMsg = null;
                    });
                  },
            trailingLabel: _naverPwSetEmail != null
                ? '이메일+비밀번호로 로그인하세요'
                : '웹에서는 비밀번호 설정이 필요해요',
            trailingBadgeBg: _naverPwSetEmail != null
                ? AppColors.textDisabled.withOpacity(0.25)
                : const Color(0xFF03C75A).withOpacity(0.3),
          ),

          // 네이버 비밀번호 설정 완료 시 이메일 폼 안내
          if (_naverPwSetEmail != null && _showEmailForm) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF03C75A).withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF03C75A).withOpacity(0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: Color(0xFF03C75A),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '네이버 이메일 + 설정한 비밀번호로 로그인하세요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary.withOpacity(0.75),
                        height: 1.4,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('naver_pw_set_email');
                      if (mounted) {
                        setState(() {
                          _naverPwSetEmail = null;
                          _emailCtrl.clear();
                          _showEmailForm = false;
                        });
                      }
                    },
                    child: Text(
                      '초기화',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withOpacity(0.6),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 네이버 비밀번호 설정 링크 폼 (토글)
          if (_showNaverResetForm) ...[
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF03C75A).withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF03C75A).withOpacity(0.25),
                ),
              ),
              child: _naverResetSent
                  ? Column(
                      children: [
                        const Icon(
                          Icons.mark_email_read_outlined,
                          color: Color(0xFF03C75A),
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '비밀번호 설정 링크를 보냈어요!\n메일함을 확인해주세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => setState(() {
                            _naverResetSent = false;
                            _naverEmailCtrl.clear();
                          }),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          child: const Text(
                            '다시 입력하기',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF03C75A),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '네이버로 가입한 이메일 주소를 입력하면\n비밀번호 설정 링크를 보내드려요.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        PubTextField(
                          controller: _naverEmailCtrl,
                          label: '가입한 네이버 이메일',
                          hint: 'example@naver.com',
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _naverResetLoading
                                ? null
                                : _sendNaverPasswordReset,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF03C75A),
                              foregroundColor: AppColors.white,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _naverResetLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.white,
                                    ),
                                  )
                                : const Text(
                                    '메일로 비밀번호 설정 링크 보내기',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],

          const SizedBox(height: 12),

          // ── 이메일 로그인 ──────────────────
          if (!_showEmailForm)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(
                  Icons.email_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                label: const Text(
                  '이메일로 로그인',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.divider),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed:
                    () => setState(() {
                      _showEmailForm = true;
                      _errorMsg = null;
                    }),
              ),
            )
          else ...[
            PubTextField(
              controller: _emailCtrl,
              label: '이메일',
              hint: 'email@example.com',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.sm),
            PubTextField(controller: _pwCtrl, label: '비밀번호', obscure: true),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_loadingProvider == 'email') ? null : _loginEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    (_loadingProvider == 'email')
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                        : Text(
                          _isSignUp ? '회원가입' : '로그인',
                          style: GoogleFonts.notoSansKr(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(
                  _isSignUp ? '이미 계정이 있어요' : '아직 계정이 없어요 (회원가입)',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],

          // ── 에러 메시지 ────────────────────
          if (_errorMsg != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: AppColors.error.withOpacity(0.8),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMsg!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.error.withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 소셜 로그인 버튼 (마지막 로그인 배지 포함)
  Widget _snsBtn(
    String provider,
    IconData icon,
    String label,
    Color bgColor,
    Color fgColor,
    VoidCallback? onPressed, {
    Color? border,
    String? trailingLabel,
    Color? trailingBadgeBg,
  }) {
    final isLast = _lastProvider == provider;
    final busy = _loadingProvider == provider;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            icon:
                busy
                    ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fgColor,
                      ),
                    )
                    : Icon(icon, color: fgColor, size: 22),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: fgColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (trailingLabel != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: trailingBadgeBg ?? AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      trailingLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: trailingBadgeBg != null
                            ? fgColor.withOpacity(0.85)
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: bgColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side:
                    border != null
                        ? BorderSide(color: border)
                        : BorderSide.none,
              ),
            ),
            onPressed: _isLoading ? null : onPressed,
          ),
        ),

        // "마지막 로그인" 배지
        if (isLast && onPressed != null)
          Positioned(
            right: 8,
            top: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '마지막 로그인',
                style: GoogleFonts.notoSansKr(
                  fontSize: 9,
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

        // 네이버에 마지막 로그인 배지 + 앱 안내
        if (isLast && onPressed == null)
          Positioned(
            right: 8,
            top: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.textDisabled,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '마지막 로그인 (앱)',
                style: GoogleFonts.notoSansKr(
                  fontSize: 9,
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 치과 로그인 카드 (이메일/비밀번호)
// ═══════════════════════════════════════════════════════════════
class _ClinicLoginCard extends StatefulWidget {
  final String? nextRoute;
  const _ClinicLoginCard({this.nextRoute});

  @override
  State<_ClinicLoginCard> createState() => _ClinicLoginCardState();
}

class _ClinicLoginCardState extends State<_ClinicLoginCard> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _obscurePw = true;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text,
      );

      if (!mounted) return;
      final status = await ClinicAuthService.getStatus();
      if (!mounted) return;

      if (!status.exists) {
        // clinics_accounts 문서 없음 → 공고자 계정이 아님
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() {
          _errorMsg = '이 이메일은 공고자 계정으로 등록되어 있지 않습니다.\n'
              '위생사(지원자) 계정이라면 왼쪽의 지원자 로그인을 이용해주세요.\n'
              '공고자 계정이 없다면 아래 회원가입을 진행해주세요.';
        });
        return;
      }

      await SignInTracker.record('email');
      await ClinicAuthService.recordLogin();

      if (!mounted) return;
      if (status.isApprovedAndCanPost) {
        context.go(widget.nextRoute ?? '/post-job');
      } else {
        context.go('/publisher/onboarding');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMsg = _mapError(e.code));
    } catch (_) {
      setState(() => _errorMsg = '로그인 중 오류가 발생했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapError(String code) {
    switch (code) {
      case 'user-not-found':
        return '등록되지 않은 이메일이에요.';
      case 'wrong-password':
        return '비밀번호가 올바르지 않아요.';
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 올바르지 않아요.';
      case 'user-disabled':
        return '이 계정은 비활성화 상태예요.';
      case 'too-many-requests':
        return '시도 횟수를 초과했어요. 잠시 후 다시 시도해주세요.';
      default:
        return '로그인 중 오류가 발생했어요. 다시 시도해주세요.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.divider.withOpacity(0.25),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 아이콘 + 제목
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.business_center_rounded,
                    color: AppColors.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '치과 로그인',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '공고 등록 · 지원자 관리',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── 안내 문구 ─────────────────────────────
            Text(
              '치과 계정은 기존 일반유저 계정으로 가입할 수 없습니다.',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // 이메일
            PubTextField(
              controller: _emailCtrl,
              label: '이메일',
              hint: 'admin@clinic.com',
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return '이메일을 입력해주세요.';
                if (!v.contains('@')) return '올바른 이메일 형식이 아니에요.';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // 비밀번호
            PubTextField(
              controller: _pwCtrl,
              label: '비밀번호',
              obscure: _obscurePw,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePw
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textDisabled,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePw = !_obscurePw),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return '비밀번호를 입력해주세요.';
                return null;
              },
            ),

            // 에러
            if (_errorMsg != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: AppColors.error.withOpacity(0.8),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorMsg!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.error.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            PubPrimaryButton(
              label: '로그인',
              isLoading: _isLoading,
              onPressed: _login,
            ),

            const SizedBox(height: AppSpacing.md),

            // 비밀번호 찾기 + 회원가입
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => context.push('/publisher/forgot'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: Text(
                    '비밀번호를 잊으셨나요?',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/publisher/signup'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: const Text(
                    '회원가입',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
