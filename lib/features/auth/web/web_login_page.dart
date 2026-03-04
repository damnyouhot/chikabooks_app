import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/kakao_auth_service.dart';
import '../../../services/apple_auth_service.dart';
import '../../../services/email_auth_service.dart';
import '../../../services/sign_in_tracker.dart';
import '../../publisher/services/clinic_auth_service.dart';
import '../../publisher/pages/publisher_shared.dart';

// ── 디자인 상수 ────────────────────────────────────────────
const _kBg = Color(0xFFF8F6F9);
const _kText = Color(0xFF3D4A5C);
const _kBlue = Color(0xFF4A90D9);
const _kGreen = Color(0xFF4CAF50);
const _kNaver = Color(0xFF03C75A); // 네이버 그린

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
      backgroundColor: _kBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                _buildLogo(),
                const SizedBox(height: 36),

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

                const SizedBox(height: 24),

                // ── 하단 링크 ────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '© 치카북스',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(width: 16),
                    _link('개인정보처리방침', '/privacy'),
                    _dot(),
                    _link('이용약관', '/terms'),
                  ],
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
            color: _kBlue,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.local_hospital_outlined,
            size: 28,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '치카북스',
          style: GoogleFonts.notoSansKr(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: _kText,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '치과 커뮤니티 & 구인구직 플랫폼',
          style: GoogleFonts.notoSansKr(
            fontSize: 13,
            color: _kText.withOpacity(0.5),
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
            color: Colors.grey[600],
            decoration: TextDecoration.underline,
            decorationColor: Colors.grey[400],
          ),
        ),
      ),
    );
  }

  Widget _dot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text('·', style: TextStyle(color: Colors.grey[400])),
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
  bool _isPasswordReset = false; // 비밀번호 만들기(재설정) 모드
  bool _isSignUp = false;
  String? _lastProvider;
  bool _resetSent = false; // 재설정 이메일 발송 완료 여부

  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _resetEmailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBadge();
  }

  Future<void> _loadBadge() async {
    final p = await SignInTracker.getLocalLastProvider();
    if (mounted && p != null) setState(() => _lastProvider = p);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  // ── 로그인 후 공통 라우팅 ──────────────────────────────────
  Future<void> _handlePostLogin(String provider) async {
    await SignInTracker.record(provider);
    if (!mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final role = doc.data()?['role'] as String?;
      if (!mounted) return;

      if (role == 'clinic') {
        final status = await ClinicAuthService.getStatus();
        if (!mounted) return;
        context.go(
          status.canPost
              ? (widget.nextRoute ?? '/post-job')
              : '/publisher/onboarding',
        );
      } else {
        context.go(widget.nextRoute ?? '/applicant/resumes');
      }
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

      final userCredential =
          await FirebaseAuth.instance.signInWithPopup(googleProvider);

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

  // ── 비밀번호 재설정 이메일 발송 ───────────────────────────
  Future<void> _sendPasswordReset() async {
    final email = _resetEmailCtrl.text.trim();
    if (email.isEmpty) {
      _showError('이메일을 입력해주세요.');
      return;
    }
    _setLoading('reset');
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) setState(() => _resetSent = true);
    } on FirebaseAuthException catch (e) {
      _showError(e.code == 'user-not-found' ? '등록되지 않은 이메일이에요.' : '오류가 발생했어요. 다시 시도해주세요.');
    } catch (_) {
      _showError('오류가 발생했어요. 다시 시도해주세요.');
    } finally {
      _clearLoading();
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
        user = await EmailAuthService.signUp(
          email: email,
          password: password,
        );
      } else {
        user = await EmailAuthService.signIn(
          email: email,
          password: password,
        );
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
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
                  color: _kGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: _kGreen,
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
                      color: _kText,
                    ),
                  ),
                  Text(
                    '이력서 작성 · 공고 지원',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 12,
                      color: _kText.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── 소셜 로그인 버튼들 ──────────────
          _snsBtn('kakao', Icons.chat_bubble, '카카오로 로그인',
              const Color(0xFFFEE500), Colors.black87, _loginKakao),
          const SizedBox(height: 10),
          _snsBtn('google', Icons.g_mobiledata, 'Google로 로그인',
              Colors.white, Colors.black87, _loginGoogle,
              border: Colors.grey[300]),
          const SizedBox(height: 10),
          _snsBtn('apple', Icons.apple, 'Apple로 로그인', Colors.black,
              Colors.white, _loginApple),
          const SizedBox(height: 10),

          // 네이버 (비활성)
          _snsBtn('naver', Icons.language, '네이버로 로그인',
              Colors.grey[200]!, Colors.grey[500]!, null,
              trailingLabel: '앱에서만 가능해요'),

          const SizedBox(height: 12),

          // ── 네이버 이용자 비밀번호 만들기 안내 ────────────
          if (!_isPasswordReset && !_showEmailForm) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  _isPasswordReset = true;
                  _showEmailForm = false;
                  _resetSent = false;
                  _errorMsg = null;
                }),
                icon: const Icon(Icons.lock_reset, size: 15),
                label: Text(
                  '네이버 로그인 가입자 비밀번호 만들기',
                  style: GoogleFonts.notoSansKr(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kNaver,
                  side: BorderSide(color: _kNaver.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '비밀번호 만들기 후 이메일 로그인으로 이용해주세요.',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansKr(
                fontSize: 11,
                color: _kText.withOpacity(0.5),
                height: 1.5,
              ),
            ),
          ] else if (_isPasswordReset) ...[
            // ── 비밀번호 재설정 폼 ─────────────────────────
            if (_resetSent) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: _kGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: _kGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '재설정 링크를 이메일로 보냈어요.\n메일함을 확인해주세요.',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 12,
                          color: _kGreen,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () => setState(() {
                    _isPasswordReset = false;
                    _resetSent = false;
                    _resetEmailCtrl.clear();
                  }),
                  child: Text(
                    '로그인으로 돌아가기',
                    style: TextStyle(fontSize: 12, color: _kText.withOpacity(0.5)),
                  ),
                ),
              ),
            ] else ...[
              PubTextField(
                controller: _resetEmailCtrl,
                label: '가입한 이메일',
                hint: 'email@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_loadingProvider == 'reset') ? null : _sendPasswordReset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kNaver,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: (_loadingProvider == 'reset')
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          '비밀번호 설정 링크 보내기',
                          style: GoogleFonts.notoSansKr(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () => setState(() {
                    _isPasswordReset = false;
                    _resetEmailCtrl.clear();
                    _errorMsg = null;
                  }),
                  child: Text(
                    '취소',
                    style: TextStyle(fontSize: 12, color: _kText.withOpacity(0.5)),
                  ),
                ),
              ),
            ],
          ],

          const SizedBox(height: 18),

          // ── 구분선 ─────────────────────────
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey[300])),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '또는',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey[300])),
            ],
          ),
          const SizedBox(height: 14),

          // ── 이메일 로그인 ──────────────────
          if (!_showEmailForm)
            OutlinedButton.icon(
              icon: Icon(
                Icons.email_outlined,
                size: 18,
                color: _kText.withOpacity(0.6),
              ),
              label: Text(
                '이메일로 로그인',
                style: TextStyle(
                  fontSize: 14,
                  color: _kText.withOpacity(0.7),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey[300]!),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => setState(() {
                _showEmailForm = true;
                _isPasswordReset = false;
                _errorMsg = null;
              }),
            )
          else ...[
            PubTextField(
              controller: _emailCtrl,
              label: '이메일',
              hint: 'email@example.com',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            PubTextField(
              controller: _pwCtrl,
              label: '비밀번호',
              obscure: true,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_loadingProvider == 'email') ? null : _loginEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: (_loadingProvider == 'email')
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
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
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(
                  _isSignUp ? '이미 계정이 있어요' : '아직 계정이 없어요 (회원가입)',
                  style: TextStyle(
                    fontSize: 12,
                    color: _kText.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ],

          // ── 에러 메시지 ────────────────────
          if (_errorMsg != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kPubPinkDark.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: kPubPinkDark.withOpacity(0.8),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMsg!,
                      style: TextStyle(
                        fontSize: 12,
                        color: kPubPinkDark.withOpacity(0.9),
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
            icon: busy
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
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      trailingLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
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
                side: border != null
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
                color: _kGreen,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: _kGreen.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                '마지막 로그인',
                style: GoogleFonts.notoSansKr(
                  fontSize: 9,
                  color: Colors.white,
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
                color: Colors.grey[500],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '마지막 로그인 (앱)',
                style: GoogleFonts.notoSansKr(
                  fontSize: 9,
                  color: Colors.white,
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

      // provider 기록
      await SignInTracker.record('email');

      if (!mounted) return;
      final status = await ClinicAuthService.getStatus();
      if (!mounted) return;

      if (status.canPost) {
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
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
                    color: _kBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.business_center_rounded,
                    color: _kBlue,
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
                        color: _kText,
                      ),
                    ),
                    Text(
                      '공고 등록 · 지원자 관리',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 12,
                        color: _kText.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── 안내 문구 ─────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '치과 계정은 SNS 로그인을 지원하지 않습니다.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'SNS로 가입했다면 비밀번호를 만들어 주세요.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 11,
                    color: _kText.withOpacity(0.55),
                  ),
                ),
              ],
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
            const SizedBox(height: 12),

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
                  color: _kText.withOpacity(0.4),
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
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: kPubPinkDark.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: kPubPinkDark.withOpacity(0.8),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorMsg!,
                        style: TextStyle(
                          fontSize: 12,
                          color: kPubPinkDark.withOpacity(0.9),
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

            const SizedBox(height: 12),

            // 비밀번호 만들기 버튼 (SNS 가입자 대상)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/publisher/forgot'),
                icon: const Icon(Icons.lock_reset, size: 15),
                label: Text(
                  'SNS가입자 비밀번호 만들기',
                  style: GoogleFonts.notoSansKr(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kBlue,
                  side: BorderSide(color: _kBlue.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 4),

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
                      color: _kText.withOpacity(0.5),
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
                      color: _kBlue,
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
