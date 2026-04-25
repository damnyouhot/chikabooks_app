import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/web/web_account_menu_button.dart';
import '../../me/providers/me_providers.dart';
import '../services/job_image_uploader.dart';

/// 치과 사업자 인증 페이지 (/clinic-verify)
///
/// 사업자등록증 사진을 올리면:
/// 1. Firebase Storage에 업로드
/// 2. AI가 자동으로 정보 읽기 (Mock → 실제 OpenAI 연동 예정)
/// 3. 국세청 API로 사업자 실재 확인 (Mock → 실제 API 발급 후 연동 예정)
/// 4. 통과 시 clinicVerified = true 처리
class ClinicVerifyPage extends ConsumerStatefulWidget {
  const ClinicVerifyPage({super.key, this.profileId});

  /// 어느 지점(clinic_profiles 문서 id)에 대해 인증을 진행할지.
  /// null 이면 레거시 동작(uid 기준 단일 인증).
  final String? profileId;

  @override
  ConsumerState<ClinicVerifyPage> createState() => _ClinicVerifyPageState();
}

class _ClinicVerifyPageState extends ConsumerState<ClinicVerifyPage> {
  XFile? _docImage;
  bool _isLoading = false;
  bool _submitted = false;

  // AI가 읽어온 결과값들 (수정 가능)
  final _bizNoCtrl = TextEditingController();
  final _clinicNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _openedAtCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  bool _aiExtracted = false;
  bool _confirmed = false; // "내용 확인했습니다" 체크박스
  double _uploadProgress = 0.0;

  @override
  void dispose() {
    for (final c in [
      _bizNoCtrl,
      _clinicNameCtrl,
      _ownerNameCtrl,
      _openedAtCtrl,
      _addressCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── 사진 선택 ────────────────────────────────────────
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _docImage = picked);
  }

  // ── AI 자동추출 + 업로드 ────────────────────────────
  Future<void> _runExtract() async {
    if (_docImage == null) {
      _showSnack('사업자등록증 사진을 먼저 선택해주세요.');
      return;
    }
    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

      // 1) Storage 업로드 (jobs/{jobId}/images — jobId는 단일 세그먼트여야 규칙 매칭됨)
      final urls = await JobImageUploader.uploadImages(
        jobId: 'cv_$uid',
        images: [_docImage!],
        onProgress: (_, p) => setState(() => _uploadProgress = p),
      );

      // 2) Cloud Function 호출 (submitClinicVerification)
      final callable = FirebaseFunctions.instance.httpsCallable(
        'submitClinicVerification',
      );
      final result = await callable.call({
        'docUrl': urls.first,
        'uid': uid,
        if (widget.profileId != null) 'profileId': widget.profileId,
      });
      final res = Map<String, dynamic>.from(result.data as Map);

      // 3) 결과를 폼에 자동 입력
      if (!mounted) return;
      setState(() {
        _bizNoCtrl.text = res['bizNo'] as String? ?? '';
        _clinicNameCtrl.text = res['clinicName'] as String? ?? '';
        _ownerNameCtrl.text = res['ownerName'] as String? ?? '';
        _openedAtCtrl.text = res['openedAt'] as String? ?? '';
        _addressCtrl.text = res['address'] as String? ?? '';
        _aiExtracted = true;
        _confirmed = false;
      });

      if (res['_mock'] == true) {
        _showSnack('AI 키 미설정 상태입니다. 직접 입력 후 제출해주세요.');
      } else {
        _showSnack('AI 자동추출 완료! 내용을 꼭 확인해주세요.');
      }
    } catch (e) {
      _showSnack('추출 실패. 직접 입력 후 제출해주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── 최종 제출 ─────────────────────────────────────────
  Future<void> _submit() async {
    if (!_confirmed) {
      _showSnack('내용을 확인했다고 체크해주세요.');
      return;
    }
    if (_bizNoCtrl.text.trim().isEmpty || _clinicNameCtrl.text.trim().isEmpty) {
      _showSnack('사업자번호와 치과명은 필수예요.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'submitClinicVerification',
      );
      await callable.call({
        'bizNo': _bizNoCtrl.text.trim(),
        'clinicName': _clinicNameCtrl.text.trim(),
        'ownerName': _ownerNameCtrl.text.trim(),
        'openedAt': _openedAtCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'finalSubmit': true,
        if (widget.profileId != null) 'profileId': widget.profileId,
      });
      if (mounted) setState(() => _submitted = true);
    } catch (e) {
      _showSnack('제출 실패: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _buildSuccessScreen();

    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          '치과 사업자 인증',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 18),
          onPressed: () => context.canPop() ? context.pop() : null,
        ),
        actions: const [WebAccountMenuButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 안내 배너
          _buildInfoBanner(),
          const SizedBox(height: 20),

          // STEP 1: 사진 업로드
          _buildStep(
            step: '1',
            title: '사업자등록증 사진 올리기',
            child: _buildImageUpload(),
          ),
          const SizedBox(height: 16),

          // STEP 2: AI 자동추출 결과 확인
          _buildStep(
            step: '2',
            title: 'AI가 읽은 내용 확인',
            child: _buildExtractedFields(),
          ),
          const SizedBox(height: 16),

          // STEP 3: 제출
          _buildStep(step: '3', title: '제출', child: _buildSubmitSection()),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── 안내 배너 ──────────────────────────────────────────
  Widget _buildInfoBanner() {
    String? targetName;
    if (widget.profileId != null) {
      final profilesAsync = ref.watch(clinicProfilesProvider);
      profilesAsync.whenData((list) {
        for (final p in list) {
          if (p.id == widget.profileId) {
            targetName = p.effectiveName.isNotEmpty
                ? p.effectiveName
                : (p.clinicName.isNotEmpty ? p.clinicName : '이름 없음');
            break;
          }
        }
      });
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.profileId != null) ...[
            Row(
              children: [
                Icon(Icons.local_hospital_outlined,
                    size: 16, color: AppColors.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '대상 지점: ${targetName ?? '...'}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline,
                  color: AppColors.accent.withOpacity(0.8), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.profileId != null
                      ? '사업자등록증을 올리면 AI가 자동으로 정보를 읽어줘요.\n'
                          '제출 시 위 지점에 대한 인증 정보로 저장돼요.'
                      : '사업자등록증을 올리면 AI가 자동으로 정보를 읽어줘요.\n'
                          '내용을 확인하고 제출하면 검토 후 구인공고 등록이 가능해요.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary.withOpacity(0.8),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 스텝 카드 래퍼 ────────────────────────────────────
  Widget _buildStep({
    required String step,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    step,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // ── 이미지 업로드 섹션 ────────────────────────────────
  Widget _buildImageUpload() {
    return Column(
      children: [
        // 이미지 미리보기
        GestureDetector(
          onTap: _isLoading ? null : _pickImage,
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    _docImage != null ? AppColors.error.withOpacity(0.3) : AppColors.divider,
                width: 1.5,
              ),
            ),
            child:
                _docImage == null
                    ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 36,
                          color: AppColors.textPrimary.withOpacity(0.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '탭해서 사진 선택',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary.withOpacity(0.4),
                          ),
                        ),
                      ],
                    )
                    : Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child:
                              kIsWeb
                                  ? Image.network(
                                    _docImage!.path,
                                    fit: BoxFit.cover,
                                  )
                                  : Image.file(
                                    File(_docImage!.path),
                                    fit: BoxFit.cover,
                                  ),
                        ),
                        // 업로드 진행도
                        if (_uploadProgress > 0 && _uploadProgress < 1.0)
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.black.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Center(
                              child: Text(
                                '업로드 중 ${(_uploadProgress * 100).toInt()}%',
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        // 변경 버튼
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: _isLoading ? null : _pickImage,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.black.withOpacity(0.54),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '변경',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
          ),
        ),
        const SizedBox(height: 12),
        // AI 자동추출 버튼
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _runExtract,
            icon:
                _isLoading
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                    : const Icon(Icons.auto_awesome, size: 18),
            label: Text(_isLoading ? '분석 중...' : 'AI로 자동 읽기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── AI 추출 결과 폼 ───────────────────────────────────
  Widget _buildExtractedFields() {
    if (!_aiExtracted) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'STEP 1에서 AI 자동 읽기를 먼저 해주세요.\n또는 직접 입력해도 됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary.withOpacity(0.45),
              height: 1.5,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        _field(ctrl: _bizNoCtrl, label: '사업자 등록번호', hint: '예) 123-45-67890'),
        const SizedBox(height: 10),
        _field(ctrl: _clinicNameCtrl, label: '상호(치과명)', hint: '예) 서울미소치과'),
        const SizedBox(height: 10),
        _field(ctrl: _ownerNameCtrl, label: '대표자명', hint: '예) 홍길동'),
        const SizedBox(height: 10),
        _field(ctrl: _openedAtCtrl, label: '개업일', hint: '예) 20200101'),
        const SizedBox(height: 10),
        _field(ctrl: _addressCtrl, label: '사업장 주소', hint: '예) 서울시 강남구...'),
      ],
    );
  }

  // ── 제출 섹션 ──────────────────────────────────────────
  Widget _buildSubmitSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          value: _confirmed,
          onChanged: (v) => setState(() => _confirmed = v ?? false),
          title: const Text(
            'AI가 읽은 내용을 직접 확인했습니다.',
            style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.accent,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 15),
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
                      '인증 신청하기',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '검토 후 승인 완료 시 구인공고 등록이 가능해요.',
            style: TextStyle(fontSize: 12, color: AppColors.textPrimary.withOpacity(0.45)),
          ),
        ),
      ],
    );
  }

  // ── 완료 화면 ──────────────────────────────────────────
  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (kIsWeb)
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: const Row(
                children: [
                  Spacer(),
                  WebAccountMenuButton(),
                ],
              ),
            ),
          Expanded(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withOpacity(0.07),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  size: 36,
                  color: AppColors.error.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '인증 신청 완료!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '사업자 인증 신청이 접수됐어요.\n'
                '검토 완료 후 구인공고 등록이 가능해요.\n(보통 1~2 영업일 소요)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary.withOpacity(0.6),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/post-job'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('구인공고 작성하러 가기'),
                ),
              ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 공통 텍스트 필드 ───────────────────────────────────
  Widget _field({
    required TextEditingController ctrl,
    required String label,
    String? hint,
  }) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: AppColors.textDisabled),
        labelStyle: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.appBg,
      ),
    );
  }
}


