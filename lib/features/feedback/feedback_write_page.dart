import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/feedback_post.dart';
import '../../services/feedback_service.dart';

/// 피드백 작성 페이지
class FeedbackWritePage extends StatefulWidget {
  final String sourceScreenLabel;
  final String sourceRoute;

  const FeedbackWritePage({
    super.key,
    required this.sourceScreenLabel,
    required this.sourceRoute,
  });

  @override
  State<FeedbackWritePage> createState() => _FeedbackWritePageState();
}

class _FeedbackWritePageState extends State<FeedbackWritePage> {
  static const _prefKey = 'feedback_display_name';

  final _formKey = GlobalKey<FormState>();
  final _textCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  FeedbackType _type = FeedbackType.improvement;
  FeedbackPriority _priority = FeedbackPriority.medium;
  FeedbackVisibility _visibility = FeedbackVisibility.public;

  final List<XFile> _images = [];
  bool _submitting = false;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadAppVersion();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey) ?? '';
    if (saved.isNotEmpty && mounted) {
      setState(() => _nameCtrl.text = saved);
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = info.version);
    } catch (_) {
      _appVersion = 'unknown';
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_images.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지는 최대 3장까지 첨부할 수 있어요')),
      );
      return;
    }
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (file != null && mounted) {
      setState(() => _images.add(file));
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_submitting) return;

    setState(() => _submitting = true);

    // SharedPreferences에 식별명 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _nameCtrl.text.trim());

    final id = await FeedbackService.create(
      type: _type,
      priority: _priority,
      visibility: _visibility,
      text: _textCtrl.text.trim(),
      displayName: _nameCtrl.text.trim(),
      appVersion: _appVersion,
      sourceRoute: widget.sourceRoute,
      sourceScreenLabel: widget.sourceScreenLabel,
      imageFiles: _images,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (id != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('피드백이 등록되었어요. 감사합니다 🙏'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('등록에 실패했어요. 다시 시도해 주세요.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          '테스트 기간 중 피드백 남기기',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '등록',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 60),
          children: [
            // ── 화면 출처 (자동) ──────────────────────────────────
            _SectionLabel('작성 화면'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    widget.sourceScreenLabel.isNotEmpty
                        ? widget.sourceScreenLabel
                        : widget.sourceRoute,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 식별명 ────────────────────────────────────────────
            _SectionLabel('식별명'),
            const SizedBox(height: 4),
            Text(
              '누가 보낸 피드백인지 알 수 있도록 이름이나 별명을 입력해 주세요.\n'
              '(로그인 계정: ${user?.displayName ?? user?.email ?? '알 수 없음'})',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textDisabled,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              decoration: _inputDeco(hint: '예: 홍길동, 테스터A …'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '식별명을 입력해 주세요' : null,
            ),
            const SizedBox(height: 20),

            // ── 유형 ──────────────────────────────────────────────
            _SectionLabel('유형'),
            const SizedBox(height: 8),
            Row(
              children: FeedbackType.values.map((t) {
                final selected = _type == t;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _type = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: EdgeInsets.only(
                          right: t == FeedbackType.values.last ? 0 : 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.accent
                            : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Center(
                        child: Text(
                          t.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? AppColors.onAccent
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── 중요도 ────────────────────────────────────────────
            _SectionLabel('중요도'),
            const SizedBox(height: 8),
            Row(
              children: FeedbackPriority.values.map((p) {
                final selected = _priority == p;
                final color = switch (p) {
                  FeedbackPriority.high => AppColors.error,
                  FeedbackPriority.medium => AppColors.warning,
                  FeedbackPriority.low => AppColors.textDisabled,
                };
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _priority = p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: EdgeInsets.only(
                          right: p == FeedbackPriority.values.last ? 0 : 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? color.withOpacity(0.15)
                            : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: selected
                            ? Border.all(color: color, width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          p.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color:
                                selected ? color : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── 공개/비공개 ────────────────────────────────────────
            _SectionLabel('공개 설정'),
            const SizedBox(height: 8),
            Row(
              children: FeedbackVisibility.values.map((v) {
                final selected = _visibility == v;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _visibility = v),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: EdgeInsets.only(
                          right: v == FeedbackVisibility.values.last ? 0 : 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.accent
                            : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            v == FeedbackVisibility.public
                                ? Icons.public
                                : Icons.lock_outline,
                            size: 16,
                            color: selected
                                ? AppColors.onAccent
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            v == FeedbackVisibility.public ? '공개' : '비공개',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? AppColors.onAccent
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_visibility == FeedbackVisibility.private)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '비공개 글은 작성자와 관리자만 볼 수 있어요',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // ── 본문 ──────────────────────────────────────────────
            _SectionLabel('내용'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _textCtrl,
              maxLines: 6,
              maxLength: 1000,
              decoration: _inputDeco(hint: '불편했던 점, 개선이 필요한 부분, 좋았던 경험을 자유롭게 적어주세요'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '내용을 입력해 주세요' : null,
            ),
            const SizedBox(height: 20),

            // ── 이미지 첨부 ────────────────────────────────────────
            Row(
              children: [
                _SectionLabel('이미지 첨부'),
                const SizedBox(width: 6),
                Text(
                  '(${_images.length}/3)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textDisabled,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // 추가 버튼
                  if (_images.length < 3)
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: AppColors.divider,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 24, color: AppColors.textDisabled),
                            SizedBox(height: 4),
                            Text(
                              '추가',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textDisabled,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // 선택된 이미지들
                  ..._images.asMap().entries.map((entry) {
                    final i = entry.key;
                    final file = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Stack(
                        children: [
                          FutureBuilder<dynamic>(
                            future: file.readAsBytes(),
                            builder: (_, snap) {
                              if (!snap.hasData) {
                                return Container(
                                  width: 80,
                                  height: 80,
                                  color: AppColors.surfaceMuted,
                                );
                              }
                              return ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                child: Image.memory(
                                  snap.data!,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              );
                            },
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => _removeImage(i),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── 앱 버전 안내 ──────────────────────────────────────
            Text(
              '앱 버전 $_appVersion · ${widget.sourceScreenLabel} 화면에서 작성',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco({required String hint}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 13,
          color: AppColors.textDisabled,
        ),
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}
