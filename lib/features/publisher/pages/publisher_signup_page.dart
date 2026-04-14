import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import 'publisher_shared.dart';
import '../services/clinic_auth_service.dart';

/// `?next=` 는 앱 내부 경로만 허용 (오픈 리다이렉트 방지)
String _safePostSignupDestination(BuildContext context) {
  final next = GoRouterState.of(context).uri.queryParameters['next'];
  if (next != null &&
      next.isNotEmpty &&
      next.startsWith('/') &&
      !next.startsWith('//')) {
    return next;
  }
  return '/post-job/input';
}

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
  bool _agreeRefund = false;
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
    if (!_agreeTerms || !_agreePrivacy || !_agreeRefund) {
      setState(() => _errorMsg = '필수 약관에 동의해주세요.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    // authStateChanges 로 GoRouter가 refresh되면 위젯이 rebuild되어
    // mounted=false 가 됨 → async 작업 전에 router/destination 미리 캡처
    final router = GoRouter.of(context);
    final destination = _safePostSignupDestination(context);

    try {
      final email = _emailCtrl.text.trim();
      final normalizedEmail = email.toLowerCase();

      // Auth 계정 생성 전: 이메일 기준으로 위생사 계정 중복 체크 (관리자 계정 제외)
      final isAdmin = ClinicAuthService.isAdminEmailWhitelisted(normalizedEmail);
      if (!isAdmin) {
        final existingApplicant = await FirebaseFirestore.instance
            .collection('users')
            .where('normalizedEmail', isEqualTo: normalizedEmail)
            .limit(1)
            .get();
        if (existingApplicant.docs.isNotEmpty) {
          if (mounted) {
            setState(() {
              _errorMsg = '이 이메일은 이미 위생사 계정으로 가입되어 있어\n'
                  '공고자 계정으로 사용할 수 없습니다.\n'
                  '공고자 가입은 별도의 이메일로 진행해 주세요.';
            });
          }
          return;
        }
      }

      // Firebase Auth 계정 생성
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: _pwCtrl.text,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          await _handleAlreadyInUse(email, _pwCtrl.text, router, destination);
          return;
        }
        if (mounted) setState(() => _errorMsg = _mapError(e.code));
        return;
      }

      // Auth 계정 생성 후: uid 기준 중복 체크 + clinics_accounts 문서 생성
      final dupMsg = await ClinicAuthService.checkDuplicateForClinicSignup(email);
      if (dupMsg != null) {
        await FirebaseAuth.instance.currentUser?.delete();
        if (mounted) setState(() => _errorMsg = dupMsg);
        return;
      }

      await ClinicAuthService.initClinicAccount();
      router.go(destination);
    } catch (_) {
      if (mounted) setState(() => _errorMsg = '회원가입 중 오류가 발생했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// email-already-in-use 에러 처리:
  /// Auth 계정은 있지만 Firestore(clinics_accounts) 문서가 날아간 경우를 복구한다.
  ///
  /// - 같은 비번으로 로그인 성공 + clinics_accounts 없음 → 문서만 재생성 후 진행
  /// - 같은 비번으로 로그인 성공 + clinics_accounts 있음 → 이미 정상 계정, 로그인 유도
  /// - 같은 비번으로 로그인 성공 + users 문서 있음       → 위생사 계정, 차단
  /// - 비번 틀림                                        → 비밀번호 찾기 안내
  Future<void> _handleAlreadyInUse(
    String email,
    String password,
    GoRouter router,
    String destination,
  ) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = FirebaseAuth.instance.currentUser?.uid;
      final status = await ClinicAuthService.getStatus();

      // users 문서 존재 여부 확인 (위생사 계정 체크)
      final usersDoc =
          uid != null
              ? await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .get()
              : null;

      final isAdmin = ClinicAuthService.isAdminEmailWhitelisted(email);
      if (!isAdmin && usersDoc != null && usersDoc.exists) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          setState(() {
            _errorMsg =
                '이 이메일은 이미 위생사 계정으로 가입되어 있어\n'
                '공고자 계정으로 사용할 수 없습니다.\n'
                '공고자 가입은 별도의 이메일로 진행해 주세요.';
          });
        }
      } else if (status.exists) {
        // clinics_accounts가 이미 있음 → 이미 정상 계정이므로 바로 진입
        router.go(destination);
      } else {
        // Auth만 있고 Firestore 문서 없음 → clinics_accounts만 재생성해서 복구
        final dupMsg =
            await ClinicAuthService.checkDuplicateForClinicSignup(email);
        if (dupMsg != null) {
          await FirebaseAuth.instance.signOut();
          if (mounted) setState(() => _errorMsg = dupMsg);
          return;
        }
        await ClinicAuthService.initClinicAccount();
        router.go(destination);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = switch (e.code) {
          'wrong-password' || 'invalid-credential' =>
            '이미 가입된 이메일이에요.\n비밀번호가 기억나지 않으면 로그인 화면의 비밀번호 찾기를 이용해주세요.',
          'too-many-requests' =>
            '로그인 시도가 너무 많아 일시적으로 차단됐어요.\n잠시 후(1~2분) 다시 시도해주세요.',
          _ => '회원가입 중 오류가 발생했어요. 다시 시도해주세요.',
        };
      });
    }
  }

  String _mapError(String code) {
    return switch (code) {
      'email-already-in-use' => '이미 사용 중인 이메일이에요. 로그인해주세요.',
      'invalid-email' => '올바른 이메일 형식이 아니에요.',
      'weak-password' => '비밀번호가 너무 단순해요. 좀 더 복잡하게 설정해주세요.',
      _ => '회원가입 중 오류가 발생했어요. 다시 시도해주세요.',
    };
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
                          color: AppColors.black.withOpacity(0.05),
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
                          onDetail: () => context.push('/terms'),
                        ),
                        const SizedBox(height: 10),
                        _policyCheckRow(
                          value: _agreePrivacy,
                          label: '개인정보처리방침 동의',
                          required: true,
                          onChanged:
                              (v) => setState(() => _agreePrivacy = v ?? false),
                          onDetail: () => context.push('/privacy'),
                        ),
                        const SizedBox(height: 10),
                        _policyCheckRow(
                          value: _agreeRefund,
                          label: '환불 및 청약철회 정책 확인',
                          required: true,
                          onChanged:
                              (v) => setState(() => _agreeRefund = v ?? false),
                          onDetail: () => context.push('/refund'),
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
                        onPressed:
                            () => context.go(
                              '/login?next=${Uri.encodeComponent('/post-job/input')}',
                            ),
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


