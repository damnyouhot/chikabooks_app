import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../publisher/services/clinic_auth_service.dart';
import '../../publisher/pages/publisher_shared.dart';

// ── 디자인 상수 ────────────────────────────────────────────
const _kBg = Color(0xFFF8F6F9);
const _kText = Color(0xFF3D4A5C);
const _kBlue = Color(0xFF4A90D9);
const _kGreen = Color(0xFF4CAF50);

/// 통합 로그인 페이지 (/login)
///
/// 좌: 지원자 로그인 (소셜 — 앱에서만 사용, 웹에서는 안내만)
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
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                // ── 로고 + 타이틀 ──────────────────────
                _buildLogo(),
                const SizedBox(height: 36),

                // ── 좌/우 분할 카드 ────────────────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 600) {
                      // 모바일 레이아웃: 세로로 쌓기
                      return Column(
                        children: [
                          _ClinicLoginCard(nextRoute: widget.nextRoute),
                          const SizedBox(height: 20),
                          const _ApplicantInfoCard(),
                        ],
                      );
                    }
                    // 데스크탑 레이아웃: 좌/우 분할
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _ClinicLoginCard(nextRoute: widget.nextRoute),
                        ),
                        const SizedBox(width: 24),
                        const Expanded(child: _ApplicantInfoCard()),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),

                // ── 하단 링크 ──────────────────────────
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

// ═══════════════════════════════════════════════════════════
// 치과 로그인 카드 (이메일/비밀번호)
// ═══════════════════════════════════════════════════════════
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

// ═══════════════════════════════════════════════════════════
// 지원자 안내 카드 (웹에서는 앱 안내, 향후 소셜 로그인 추가 가능)
// ═══════════════════════════════════════════════════════════
class _ApplicantInfoCard extends StatelessWidget {
  const _ApplicantInfoCard();

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
          // 아이콘 + 제목
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

          // 안내 배너
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kGreen.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kGreen.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.phone_android_rounded,
                  size: 40,
                  color: _kGreen.withOpacity(0.6),
                ),
                const SizedBox(height: 14),
                Text(
                  '치카북스 앱에서 이용해주세요',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _kText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '이력서 작성, 공고 지원, 커리어 관리까지\n모바일 앱에서 편리하게 이용할 수 있어요.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    color: _kText.withOpacity(0.5),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 기능 목록
          _featureRow(Icons.description_outlined, '이력서 작성 및 관리'),
          const SizedBox(height: 10),
          _featureRow(Icons.search_rounded, '맞춤 공고 탐색'),
          const SizedBox(height: 10),
          _featureRow(Icons.send_rounded, '원클릭 지원'),
          const SizedBox(height: 10),
          _featureRow(Icons.badge_outlined, '커리어 카드 · 네트워크'),

          const SizedBox(height: 20),

          // 앱 다운로드 안내
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _kText.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: _kText.withOpacity(0.4),
                ),
                const SizedBox(width: 8),
                Text(
                  '앱 출시 시 App Store / Play Store에서 다운로드',
                  style: TextStyle(
                    fontSize: 12,
                    color: _kText.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _kGreen.withOpacity(0.7)),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: _kText.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

