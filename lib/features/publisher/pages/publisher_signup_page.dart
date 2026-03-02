import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'publisher_shared.dart';
import '../services/publisher_service.dart';

class PublisherSignupPage extends StatefulWidget {
  const PublisherSignupPage({super.key});

  @override
  State<PublisherSignupPage> createState() => _PublisherSignupPageState();
}

class _PublisherSignupPageState extends State<PublisherSignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();

  bool _obscurePw = true;
  bool _obscureConfirm = true;
  bool _agreeTerms = false;
  bool _agreePrivacy = false;
  bool _agreeMarketing = false;
  bool _isLoading = false;
  String? _errorMsg;

  // 비밀번호 정책 체크
  bool get _hasLength => _pwCtrl.text.length >= 8;
  bool get _hasNumber => _pwCtrl.text.contains(RegExp(r'\d'));
  bool get _hasLetter => _pwCtrl.text.contains(RegExp(r'[a-zA-Z]'));

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pwConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeTerms || !_agreePrivacy) {
      setState(() => _errorMsg = '필수 약관에 동의해주세요.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text,
      );
      await PublisherService.initPublisherRole();
      if (!mounted) return;
      context.go('/publisher/onboarding');
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
      case 'email-already-in-use':
        return '이미 사용 중인 이메일이에요. 로그인해주세요.';
      case 'invalid-email':
        return '올바른 이메일 형식이 아니에요.';
      case 'weak-password':
        return '비밀번호가 너무 단순해요. 좀 더 복잡하게 설정해주세요.';
      default:
        return '회원가입 중 오류가 발생했어요. 다시 시도해주세요.';
    }
  }

  Widget _policyCheckRow({
    required bool value,
    required String label,
    required bool required,
    required ValueChanged<bool?> onChanged,
    VoidCallback? onDetail,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: kPubBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: BorderSide(color: kPubBorder),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: kPubText),
              children: [
                if (required)
                  const TextSpan(
                    text: '[필수] ',
                    style: TextStyle(
                      color: kPubBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  TextSpan(
                    text: '[선택] ',
                    style: TextStyle(color: kPubText.withOpacity(0.4)),
                  ),
                TextSpan(text: label),
              ],
            ),
          ),
        ),
        if (onDetail != null)
          GestureDetector(
            onTap: onDetail,
            child: Text(
              '보기',
              style: TextStyle(
                fontSize: 11,
                color: kPubBlue.withOpacity(0.7),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
      ],
    );
  }

  Widget _pwCheckItem(bool ok, String label) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 14,
          color: ok ? kPubBlue : kPubText.withOpacity(0.3),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: ok ? kPubBlue : kPubText.withOpacity(0.4),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PubScaffold(
      title: '게시자 회원가입',
      subtitle: '치과 공고 등록 계정 만들기',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              onChanged: () => setState(() {}),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── 이메일 ───────────────────
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

                        // ── 비밀번호 ─────────────────
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
                            if (v == null || v.length < 8) {
                              return '비밀번호는 8자 이상이어야 해요.';
                            }
                            return null;
                          },
                        ),

                        // 비밀번호 정책 체크 표시
                        if (_pwCtrl.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _pwCheckItem(_hasLength, '8자 이상'),
                              const SizedBox(width: 12),
                              _pwCheckItem(_hasNumber, '숫자 포함'),
                              const SizedBox(width: 12),
                              _pwCheckItem(_hasLetter, '영문 포함'),
                            ],
                          ),
                        ],

                        const SizedBox(height: 12),

                        // ── 비밀번호 확인 ──────────
                        PubTextField(
                          controller: _pwConfirmCtrl,
                          label: '비밀번호 확인',
                          obscure: _obscureConfirm,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: kPubText.withOpacity(0.4),
                              size: 20,
                            ),
                            onPressed:
                                () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
                          ),
                          validator: (v) {
                            if (v != _pwCtrl.text) {
                              return '비밀번호가 일치하지 않아요.';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // ── 약관 동의 ────────────────
                        _policyCheckRow(
                          value: _agreeTerms,
                          label: '이용약관 동의',
                          required: true,
                          onChanged:
                              (v) => setState(() => _agreeTerms = v ?? false),
                        ),
                        const SizedBox(height: 10),
                        _policyCheckRow(
                          value: _agreePrivacy,
                          label: '개인정보 처리방침 동의',
                          required: true,
                          onChanged:
                              (v) => setState(() => _agreePrivacy = v ?? false),
                        ),
                        const SizedBox(height: 10),
                        _policyCheckRow(
                          value: _agreeMarketing,
                          label: '마케팅 수신 동의',
                          required: false,
                          onChanged:
                              (v) =>
                                  setState(() => _agreeMarketing = v ?? false),
                        ),

                        // ── 에러 ─────────────────────
                        if (_errorMsg != null) ...[
                          const SizedBox(height: 12),
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
                          label: '계정 만들기',
                          isLoading: _isLoading,
                          onPressed: _signup,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '이미 계정이 있으신가요?  ',
                        style: TextStyle(
                          fontSize: 13,
                          color: kPubText.withOpacity(0.5),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.pop(),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: const Text(
                          '로그인',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kPubBlue,
                          ),
                        ),
                      ),
                    ],
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


