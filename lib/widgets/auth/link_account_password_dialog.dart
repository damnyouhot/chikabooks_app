import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_modal_scaffold.dart';

/// 동일 이메일의 이메일·비밀번호 계정과 SNS를 연결하기 위해 비밀번호를 받는다.
/// 취소 시 `null`, 확인 시 비밀번호 문자열(빈 문자열은 호출 측에서 거름).
Future<String?> showLinkAccountPasswordDialog(
  BuildContext context, {
  required String email,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _LinkAccountPasswordDialog(email: email),
  );
}

class _LinkAccountPasswordDialog extends StatefulWidget {
  const _LinkAccountPasswordDialog({required this.email});

  final String email;

  @override
  State<_LinkAccountPasswordDialog> createState() =>
      _LinkAccountPasswordDialogState();
}

class _LinkAccountPasswordDialogState extends State<_LinkAccountPasswordDialog> {
  final _pwCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _pwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: AppModalCard(
        borderOpacity: 0.7,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '계정 연결',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '이미 같은 이메일로 가입된 계정이 있어요.\n'
              '아래에 그 계정의 비밀번호를 입력하면 SNS와 연결돼요.\n\n'
              '${widget.email}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _pwCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: '비밀번호',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.textDisabled,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      backgroundColor: AppColors.surfaceMuted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.cardPrimary,
                      foregroundColor: AppColors.onCardEmphasis,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: const Text('연결하고 로그인'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    Navigator.of(context).pop(_pwCtrl.text);
  }
}
