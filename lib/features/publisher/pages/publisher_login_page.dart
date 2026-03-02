import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'publisher_shared.dart';
import '../services/publisher_service.dart';

class PublisherLoginPage extends StatefulWidget {
  const PublisherLoginPage({super.key});

  @override
  State<PublisherLoginPage> createState() => _PublisherLoginPageState();
}

class _PublisherLoginPageState extends State<PublisherLoginPage> {
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
      // 온보딩 상태 확인 후 적절한 화면으로
      final status = await PublisherService.getStatus();
      if (!mounted) return;
      if (status.canPost) {
        context.go('/post-job');
      } else {
        context.go('/publisher/onboarding');
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMsg = _mapError(e.code);
      });
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
    return PubScaffold(
      title: '게시자 로그인',
      subtitle: '치과 공고 등록 계정',
      showBack: false,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 상단 로고/소개 ────────────────────
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: kPubCard,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: kPubBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.business_center_rounded,
                            color: kPubBlue,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '치과 공고 등록',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: kPubText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '게시자 계정으로 로그인해 공고를 작성합니다.',
                          style: TextStyle(
                            fontSize: 13,
                            color: kPubText.withOpacity(0.5),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // ── 입력 필드 ─────────────────
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
                        PubTextField(
                          controller: _pwCtrl,
                          label: '비밀번호',
                          obscure: _obscurePw,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePw
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: kPubText.withOpacity(0.4),
                              size: 20,
                            ),
                            onPressed:
                                () => setState(() => _obscurePw = !_obscurePw),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return '비밀번호를 입력해주세요.';
                            return null;
                          },
                        ),

                        // ── 에러 메시지 ───────────────
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
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.push('/publisher/forgot'),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              '비밀번호를 잊으셨나요?',
                              style: TextStyle(
                                fontSize: 12,
                                color: kPubText.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── 회원가입 유도 ─────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '계정이 없으신가요?  ',
                        style: TextStyle(
                          fontSize: 13,
                          color: kPubText.withOpacity(0.5),
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
                            color: kPubBlue,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: kPubBlue.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '공고는 인증된 치과만 게시할 수 있어요.',
                        style: TextStyle(
                          fontSize: 11,
                          color: kPubBlue.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


