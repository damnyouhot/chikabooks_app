import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'publisher_shared.dart';
import '../services/publisher_service.dart';

/// 휴대폰 OTP 인증 화면
/// - 웹: Firebase reCAPTCHA verifier 사용 (signInWithPhoneNumber)
/// - 앱: verifyPhoneNumber 콜백 방식
class PublisherVerifyPhonePage extends StatefulWidget {
  const PublisherVerifyPhonePage({super.key});

  @override
  State<PublisherVerifyPhonePage> createState() =>
      _PublisherVerifyPhonePageState();
}

class _PublisherVerifyPhonePageState extends State<PublisherVerifyPhonePage> {
  // ── 상태 ──────────────────────────────────────────────
  final _phoneCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrls = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocuses = List.generate(6, (_) => FocusNode());

  bool _isSending = false;
  bool _isVerifying = false;
  bool _codeSent = false;
  String? _verificationId; // 앱 전용
  ConfirmationResult? _confirmationResult; // 웹 전용
  String? _errorMsg;
  int _resendCooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpFocuses) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ── 인증번호 발송 ─────────────────────────────────────
  Future<void> _sendCode() async {
    final raw = _phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.length < 10) {
      setState(() => _errorMsg = '올바른 휴대폰 번호를 입력해주세요.');
      return;
    }
    // 국제번호 형식으로 변환 (01x → +821x)
    final phone = '+82${raw.startsWith('0') ? raw.substring(1) : raw}';

    setState(() {
      _isSending = true;
      _errorMsg = null;
    });

    try {
      if (kIsWeb) {
        _confirmationResult = await FirebaseAuth.instance.signInWithPhoneNumber(
          phone,
        );
      } else {
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phone,
          verificationCompleted: (PhoneAuthCredential cred) async {
            // Android 자동 인증
            await _linkPhoneCredential(cred);
          },
          verificationFailed: (FirebaseAuthException e) {
            if (mounted) {
              setState(() {
                _errorMsg = _mapPhoneError(e.code);
                _isSending = false;
              });
            }
          },
          codeSent: (String verificationId, int? resendToken) {
            if (mounted) {
              setState(() {
                _verificationId = verificationId;
                _codeSent = true;
                _isSending = false;
              });
              _startCooldown();
            }
          },
          codeAutoRetrievalTimeout: (_) {},
          timeout: const Duration(seconds: 60),
        );
        return; // codeSent 콜백에서 상태 변경
      }

      // 웹: 발송 성공
      if (mounted) {
        setState(() {
          _codeSent = true;
          _isSending = false;
        });
        _startCooldown();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = '인증번호 발송 중 오류가 발생했어요. 다시 시도해주세요.';
          _isSending = false;
        });
      }
    }
  }

  // ── OTP 확인 ─────────────────────────────────────────
  Future<void> _verifyCode() async {
    final code = _otpCtrls.map((c) => c.text).join();
    if (code.length < 6) {
      setState(() => _errorMsg = '6자리 인증번호를 모두 입력해주세요.');
      return;
    }
    setState(() {
      _isVerifying = true;
      _errorMsg = null;
    });

    try {
      if (kIsWeb && _confirmationResult != null) {
        final result = await _confirmationResult!.confirm(code);
        await _onPhoneVerified(result.user);
      } else if (_verificationId != null) {
        final cred = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: code,
        );
        await _linkPhoneCredential(cred);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg =
              e.code == 'invalid-verification-code'
                  ? '인증번호가 올바르지 않아요. 다시 확인해주세요.'
                  : '인증 중 오류가 발생했어요. 다시 시도해주세요.';
        });
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  // ── 인증 완료 처리 ────────────────────────────────────
  Future<void> _linkPhoneCredential(PhoneAuthCredential cred) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        await currentUser.linkWithCredential(cred);
      } on FirebaseAuthException catch (e) {
        // 이미 연결된 경우 무시
        if (e.code != 'provider-already-linked' &&
            e.code != 'credential-already-in-use')
          rethrow;
      }
    }
    await _onPhoneVerified(currentUser);
  }

  Future<void> _onPhoneVerified(User? user) async {
    final raw = _phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    await PublisherService.markPhoneVerified(raw);
    if (!mounted) return;
    context.go('/publisher/onboarding');
  }

  // ── 재발송 쿨다운 타이머 ──────────────────────────────
  void _startCooldown() {
    _timer?.cancel();
    setState(() => _resendCooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) t.cancel();
      });
    });
  }

  String _mapPhoneError(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return '올바른 휴대폰 번호 형식이 아니에요.';
      case 'too-many-requests':
        return '너무 많이 시도했어요. 잠시 후 다시 시도해주세요.';
      case 'quota-exceeded':
        return '오늘 인증 한도를 초과했어요. 내일 다시 시도해주세요.';
      default:
        return '인증번호 발송에 실패했어요. ($code)';
    }
  }

  // ── OTP 입력 박스 ─────────────────────────────────────
  Widget _otpBox(int index) {
    return SizedBox(
      width: 44,
      height: 54,
      child: TextFormField(
        controller: _otpCtrls[index],
        focusNode: _otpFocuses[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: kPubText,
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kPubBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kPubBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kPubBlue, width: 2),
          ),
          filled: true,
          fillColor: kPubBg,
        ),
        onChanged: (v) {
          if (v.isNotEmpty && index < 5) {
            _otpFocuses[index + 1].requestFocus();
          } else if (v.isEmpty && index > 0) {
            _otpFocuses[index - 1].requestFocus();
          }
          if (index == 5 && v.isNotEmpty) {
            _verifyCode();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PubScaffold(
      title: '휴대폰 본인확인',
      subtitle: 'STEP 1 · 담당자 인증',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: _codeSent ? _buildOtpView() : _buildPhoneView(),
          ),
        ),
      ),
    );
  }

  // ── 전화번호 입력 뷰 ──────────────────────────────────
  Widget _buildPhoneView() {
    return Container(
      padding: const EdgeInsets.all(28),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: kPubBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.phone_iphone_rounded,
              color: kPubBlue,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '휴대폰 번호를 입력해주세요',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: kPubText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '인증번호 6자리를 문자로 보내드려요.',
            style: TextStyle(fontSize: 13, color: kPubText.withOpacity(0.5)),
          ),
          const SizedBox(height: 24),

          // 전화번호 입력
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 16, color: kPubText),
            decoration: InputDecoration(
              labelText: '휴대폰 번호',
              hintText: '01012345678',
              prefixText: '🇰🇷 +82  ',
              prefixStyle: TextStyle(
                fontSize: 14,
                color: kPubText.withOpacity(0.6),
              ),
              hintStyle: TextStyle(
                fontSize: 14,
                color: kPubText.withOpacity(0.35),
              ),
              labelStyle: TextStyle(
                fontSize: 13,
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
              filled: true,
              fillColor: kPubBg,
            ),
          ),

          if (_errorMsg != null) ...[
            const SizedBox(height: 10),
            _errorBox(_errorMsg!),
          ],

          const SizedBox(height: 20),
          PubPrimaryButton(
            label: '인증번호 받기',
            isLoading: _isSending,
            onPressed: _sendCode,
          ),

          const SizedBox(height: 12),
          Text(
            '본인 명의 휴대폰 번호만 사용해주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: kPubText.withOpacity(0.35)),
          ),
        ],
      ),
    );
  }

  // ── OTP 입력 뷰 ───────────────────────────────────────
  Widget _buildOtpView() {
    final phone = _phoneCtrl.text.trim();
    return Container(
      padding: const EdgeInsets.all(28),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: kPubBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.sms_outlined, color: kPubBlue, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            '인증번호를 입력해주세요',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: kPubText,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: kPubText.withOpacity(0.5)),
              children: [
                const TextSpan(text: ''),
                TextSpan(
                  text: phone,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: kPubText,
                  ),
                ),
                const TextSpan(text: '\n으로 인증번호 6자리를 보냈어요.'),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // OTP 박스
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, _otpBox),
          ),

          if (_errorMsg != null) ...[
            const SizedBox(height: 16),
            _errorBox(_errorMsg!),
          ],

          const SizedBox(height: 24),
          PubPrimaryButton(
            label: '확인',
            isLoading: _isVerifying,
            onPressed: _verifyCode,
          ),

          const SizedBox(height: 16),

          // 재발송 버튼
          Center(
            child:
                _resendCooldown > 0
                    ? Text(
                      '$_resendCooldown초 후 재발송 가능',
                      style: TextStyle(
                        fontSize: 13,
                        color: kPubText.withOpacity(0.4),
                      ),
                    )
                    : TextButton(
                      onPressed:
                          () => setState(() {
                            _codeSent = false;
                            for (final c in _otpCtrls) c.clear();
                            _errorMsg = null;
                          }),
                      child: const Text(
                        '번호 변경 또는 재발송',
                        style: TextStyle(
                          fontSize: 13,
                          color: kPubBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String msg) {
    return Container(
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
              msg,
              style: TextStyle(
                fontSize: 12,
                color: kPubPinkDark.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


