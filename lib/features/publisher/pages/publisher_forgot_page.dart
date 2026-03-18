import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import 'publisher_shared.dart';

class PublisherForgotPage extends StatefulWidget {
  const PublisherForgotPage({super.key});

  @override
  State<PublisherForgotPage> createState() => _PublisherForgotPageState();
}

class _PublisherForgotPageState extends State<PublisherForgotPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailCtrl.text.trim(),
      );
      if (mounted) setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMsg =
            e.code == 'user-not-found'
                ? '등록되지 않은 이메일이에요.'
                : '메일 전송 중 오류가 발생했어요. 다시 시도해주세요.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PubScaffold(
      title: '비밀번호 재설정',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: _sent ? _buildSentView() : _buildFormView(),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Container(
      padding: const EdgeInsets.all(28),
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_reset_rounded, size: 44, color: kPubBlue),
            const SizedBox(height: 16),
            const Text(
              '비밀번호를 잊으셨나요?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kPubText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '가입 시 사용한 이메일을 입력하면\n비밀번호 설정 링크를 보내드려요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: kPubText.withOpacity(0.5),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
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
                child: Text(
                  _errorMsg!,
                  style: TextStyle(
                    fontSize: 12,
                    color: kPubPinkDark.withOpacity(0.9),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            PubPrimaryButton(
              label: '비밀번호 설정 링크 보내기',
              isLoading: _isLoading,
              onPressed: _sendReset,
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => context.pop(),
                child: Text(
                  '로그인으로 돌아가기',
                  style: TextStyle(
                    fontSize: 13,
                    color: kPubText.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentView() {
    return Container(
      padding: const EdgeInsets.all(28),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: kPubBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              color: kPubBlue,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '메일을 확인해주세요!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: kPubText,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_emailCtrl.text.trim()}으로\n비밀번호 설정 링크를 보냈어요.\n메일함을 확인해주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: kPubText.withOpacity(0.5),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          PubPrimaryButton(
            label: '로그인으로 돌아가기',
            onPressed: () => context.go('/publisher/login'),
          ),
        ],
      ),
    );
  }
}


