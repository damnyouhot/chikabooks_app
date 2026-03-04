import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'publisher_shared.dart';
import '../services/clinic_auth_service.dart';

class PublisherProfilePage extends StatefulWidget {
  const PublisherProfilePage({super.key});

  @override
  State<PublisherProfilePage> createState() => _PublisherProfilePageState();
}

class _PublisherProfilePageState extends State<PublisherProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _clinicCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  String _position = '실장';
  bool _isLoading = false;

  static const _positions = ['원장', '실장', '코디', '기타'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _clinicCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ClinicAuthService.saveProfile(
        name: _nameCtrl.text.trim(),
        position: _position,
        clinicNameDraft: _clinicCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        contactEmail: _emailCtrl.text.trim(),
      );
      if (!mounted) return;
      context.go('/publisher/onboarding');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장 중 오류가 발생했어요. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PubScaffold(
      title: '기본 정보 입력',
      subtitle: 'STEP 2 · 담당자 정보',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 안내 배너 ────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kPubBlue.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kPubBlue.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: kPubBlue.withOpacity(0.7),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '사업자 인증 완료 후 치과 정보가 최종 확정됩니다.',
                            style: TextStyle(
                              fontSize: 12,
                              color: kPubBlue.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── 카드 ─────────────────────────────
                  _card(
                    title: '담당자 정보',
                    children: [
                      PubTextField(
                        controller: _nameCtrl,
                        label: '실명',
                        hint: '홍길동',
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? '실명을 입력해주세요.'
                                    : null,
                      ),
                      const SizedBox(height: 12),

                      // 직책 선택
                      DropdownButtonFormField<String>(
                        value: _position,
                        items:
                            _positions
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(
                                      p,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: kPubText,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setState(() => _position = v ?? '실장'),
                        decoration: InputDecoration(
                          labelText: '직책',
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
                            borderSide: const BorderSide(
                              color: kPubBlue,
                              width: 1.5,
                            ),
                          ),
                          filled: true,
                          fillColor: kPubBg,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _card(
                    title: '치과 정보',
                    children: [
                      PubTextField(
                        controller: _clinicCtrl,
                        label: '치과명 (임시)',
                        hint: '○○치과',
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? '치과명을 입력해주세요.'
                                    : null,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _card(
                    title: '연락처',
                    children: [
                      PubTextField(
                        controller: _phoneCtrl,
                        label: '연락 전화번호',
                        hint: '01012345678',
                        keyboardType: TextInputType.phone,
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? '연락처를 입력해주세요.'
                                    : null,
                      ),
                      const SizedBox(height: 12),
                      PubTextField(
                        controller: _emailCtrl,
                        label: '연락 이메일',
                        hint: 'admin@clinic.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return '이메일을 입력해주세요.';
                          }
                          if (!v.contains('@')) return '올바른 이메일 형식이 아니에요.';
                          return null;
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  PubPrimaryButton(
                    label: '저장하고 다음 단계로',
                    isLoading: _isLoading,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kPubCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kPubText,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}


