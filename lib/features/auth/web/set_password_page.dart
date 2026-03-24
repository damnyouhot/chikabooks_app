import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../publisher/pages/publisher_shared.dart';

/// Firebase 비밀번호 재설정 이메일 링크로 진입하는 커스텀 비밀번호 설정 화면.
/// URL 파라미터: oobCode (Firebase action code)
class SetPasswordPage extends StatefulWidget {
  final String oobCode;

  const SetPasswordPage({super.key, required this.oobCode});

  @override
  State<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends State<SetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _pwCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();

  bool _obscurePw = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _done = false;
  String? _errorMsg;

  bool get _hasLength => _pwCtrl.text.length >= 8;
  bool get _hasNumber => _pwCtrl.text.contains(RegExp(r'\d'));
  bool get _hasLetter => _pwCtrl.text.contains(RegExp(r'[a-zA-Z]'));
  bool get _pwValid => _hasLength && _hasNumber && _hasLetter;

  @override
  void initState() {
    super.initState();
    _pwCtrl.addListener(() => setState(() {}));
    _pwConfirmCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pwCtrl.dispose();
    _pwConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_pwValid) {
      setState(() => _errorMsg = '비밀번호 조건을 모두 충족해 주세요.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      await FirebaseAuth.instance.confirmPasswordReset(
        code: widget.oobCode,
        newPassword: _pwCtrl.text,
      );
      if (!mounted) return;
      setState(() => _done = true);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMsg = switch (e.code) {
          'expired-action-code' => '링크가 만료되었습니다. 다시 이메일을 요청해 주세요.',
          'invalid-action-code' => '링크가 유효하지 않습니다. 다시 이메일을 요청해 주세요.',
          'weak-password' => '비밀번호가 너무 약합니다. (8자 이상, 영문+숫자 포함)',
          _ => '오류가 발생했습니다. (${e.message})',
        };
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _checkItem(bool ok, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
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
    return Scaffold(
      backgroundColor: kPubBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 로고 ──────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: AppColors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'HygieneLab',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: kPubText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // ── 제목 ──────────────────────────────────
                const Text(
                  '네이버 웹 비밀번호 설정',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: kPubText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '네이버 메일 + 아래 비밀번호로 로그인하세요.',
                  style: TextStyle(
                    fontSize: 14,
                    color: kPubText.withOpacity(0.55),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                if (_done) ...[
                  // ── 완료 화면 ──────────────────────────
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.success.withOpacity(0.25),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '비밀번호가 설정되었습니다!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: kPubText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '이제 새 비밀번호로 로그인할 수 있습니다.',
                          style: TextStyle(
                            fontSize: 13,
                            color: kPubText.withOpacity(0.55),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => context.go('/login'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: AppColors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('로그인 페이지로'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // ── 비밀번호 입력 폼 ───────────────────
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: kPubCard,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 새 비밀번호
                          TextFormField(
                            controller: _pwCtrl,
                            obscureText: _obscurePw,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              labelText: '새 비밀번호',
                              hintText: '영문+숫자 포함 8자 이상',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePw
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: kPubText.withOpacity(0.4),
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _obscurePw = !_obscurePw),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: kPubBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: kPubBlue,
                                  width: 1.5,
                                ),
                              ),
                              filled: true,
                              fillColor: kPubBg,
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return '비밀번호를 입력해 주세요.';
                              }
                              if (!_pwValid) {
                                return '비밀번호 조건을 모두 충족해 주세요.';
                              }
                              return null;
                            },
                          ),

                          // 비밀번호 조건 표시
                          if (_pwCtrl.text.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _checkItem(_hasLength, '8자 이상'),
                                const SizedBox(width: 12),
                                _checkItem(_hasNumber, '숫자 포함'),
                                const SizedBox(width: 12),
                                _checkItem(_hasLetter, '영문 포함'),
                              ],
                            ),
                          ],

                          const SizedBox(height: 14),

                          // 비밀번호 확인
                          TextFormField(
                            controller: _pwConfirmCtrl,
                            obscureText: _obscureConfirm,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              labelText: '비밀번호 확인',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: kPubText.withOpacity(0.4),
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: kPubBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: kPubBlue,
                                  width: 1.5,
                                ),
                              ),
                              filled: true,
                              fillColor: kPubBg,
                            ),
                            validator: (v) {
                              if (v != _pwCtrl.text) {
                                return '비밀번호가 일치하지 않아요.';
                              }
                              return null;
                            },
                          ),

                          if (_errorMsg != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: kPubPink,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    size: 16,
                                    color: kPubPinkDark,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMsg!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: kPubPinkDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed:
                                  (_isLoading || !_pwValid)
                                      ? null
                                      : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: AppColors.white,
                                disabledBackgroundColor: AppColors.success
                                    .withOpacity(0.4),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child:
                                  _isLoading
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.white,
                                        ),
                                      )
                                      : const Text(
                                        '비밀번호 설정 완료',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                            ),
                          ),
                        ],
                      ),
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
