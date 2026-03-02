import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'publisher_shared.dart';

/// 게시자 사업자 인증 페이지 (/publisher/verify-business)
/// 기존 ClinicVerifyPage와 동일한 로직, 완료 후 /publisher/pending 이동
class PublisherVerifyBusinessPage extends StatefulWidget {
  const PublisherVerifyBusinessPage({super.key});

  @override
  State<PublisherVerifyBusinessPage> createState() =>
      _PublisherVerifyBusinessPageState();
}

class _PublisherVerifyBusinessPageState
    extends State<PublisherVerifyBusinessPage> {
  XFile? _docImage;
  bool _isLoading = false;
  bool _submitted = false;

  final _bizNoCtrl = TextEditingController();
  final _clinicNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _openedAtCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  bool _aiExtracted = false;
  bool _confirmed = false;
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

  // ── 이미지 선택 ─────────────────────────────────────
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() {
        _docImage = img;
        _aiExtracted = false;
      });
    }
  }

  // ── AI 추출 + 서버 제출 ──────────────────────────────
  Future<void> _submitVerification() async {
    if (_docImage == null) {
      _snack('사업자등록증 사진을 먼저 올려주세요.');
      return;
    }
    if (!_confirmed) {
      _snack('내용을 확인했다는 체크박스를 눌러주세요.');
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _snack('로그인이 필요해요.');
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0;
    });
    try {
      // Storage 업로드
      final ext = _docImage!.name.split('.').last;
      final ref = FirebaseStorage.instance.ref(
        'clinic_verifications/$uid/bizreg.$ext',
      );

      late UploadTask task;
      if (kIsWeb) {
        final bytes = await _docImage!.readAsBytes();
        task = ref.putData(bytes);
      } else {
        task = ref.putFile(File(_docImage!.path));
      }

      task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0 && mounted) {
          setState(() => _uploadProgress = s.bytesTransferred / s.totalBytes);
        }
      });
      await task;
      final docUrl = await ref.getDownloadURL();

      // Cloud Function 호출
      final fn = FirebaseFunctions.instance.httpsCallable(
        'submitClinicVerification',
      );
      final res = await fn.call({'docUrl': docUrl, 'uid': uid});
      final data = Map<String, dynamic>.from(res.data as Map);

      // AI 추출값 자동 입력
      final extracted = Map<String, dynamic>.from(
        data['extracted'] as Map? ?? {},
      );
      setState(() {
        _bizNoCtrl.text = extracted['bizNo']?.toString() ?? '';
        _clinicNameCtrl.text = extracted['clinicName']?.toString() ?? '';
        _ownerNameCtrl.text = extracted['ownerName']?.toString() ?? '';
        _openedAtCtrl.text = extracted['openedAt']?.toString() ?? '';
        _addressCtrl.text = extracted['address']?.toString() ?? '';
        _aiExtracted = true;
        _isLoading = false;
      });

      if (data['_mock'] == true) {
        _snack('AI 키 미설정 상태입니다. 내용을 직접 확인하고 제출해주세요.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('처리 중 오류가 발생했어요. 잠시 후 다시 시도해주세요.');
      }
    }
  }

  Future<void> _finalSubmit() async {
    if (!_confirmed) {
      _snack('내용 확인 체크박스를 눌러주세요.');
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      final fn = FirebaseFunctions.instance.httpsCallable(
        'submitClinicVerification',
      );
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await fn.call({
        'uid': uid,
        'finalData': {
          'bizNo': _bizNoCtrl.text.trim(),
          'clinicName': _clinicNameCtrl.text.trim(),
          'ownerName': _ownerNameCtrl.text.trim(),
          'openedAt': _openedAtCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
        },
        'confirmed': true,
      });
      if (!mounted) return;
      setState(() => _submitted = true);
    } catch (_) {
      if (mounted) _snack('제출 중 오류가 발생했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _buildSuccessView();
    return PubScaffold(
      title: '사업자 인증',
      subtitle: 'STEP 3 · 치과 실재 확인',
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _stepUploadCard(),
                    if (_aiExtracted) ...[
                      const SizedBox(height: 16),
                      _stepReviewCard(),
                      const SizedBox(height: 16),
                      _confirmAndSubmit(),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading) _loadingOverlay(),
        ],
      ),
    );
  }

  // ── STEP 1: 업로드 카드 ──────────────────────────────
  Widget _stepUploadCard() {
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
          _stepLabel('STEP 1', '사업자등록증 업로드'),
          const SizedBox(height: 14),

          // 이미지 미리보기 / 업로드 영역
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: kPubBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      _docImage != null
                          ? kPubBlue.withOpacity(0.4)
                          : kPubBorder,
                  style: BorderStyle.solid,
                ),
              ),
              child:
                  _docImage == null
                      ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.upload_file_rounded,
                            size: 40,
                            color: kPubText.withOpacity(0.25),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '사진을 탭해서 업로드하세요\n(JPG · PNG · PDF)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: kPubText.withOpacity(0.4),
                            ),
                          ),
                        ],
                      )
                      : ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child:
                            kIsWeb
                                ? Image.network(
                                  _docImage!.path,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                )
                                : Image.file(
                                  File(_docImage!.path),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                      ),
            ),
          ),

          if (_uploadProgress > 0 && _uploadProgress < 1) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: kPubBorder.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(kPubBlue),
            ),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _docImage == null ? null : _submitVerification,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text(
                'AI로 자동 읽기',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC4899),
                foregroundColor: Colors.white,
                disabledBackgroundColor: kPubBorder.withOpacity(0.4),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_docImage != null && !_aiExtracted) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                '사진 선택 후 "AI로 자동 읽기"를 눌러주세요.',
                style: TextStyle(
                  fontSize: 11,
                  color: kPubText.withOpacity(0.45),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── STEP 2: 내용 검토 카드 ───────────────────────────
  Widget _stepReviewCard() {
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
          _stepLabel('STEP 2', 'AI 추출 내용 검토'),
          const SizedBox(height: 4),
          Text(
            '잘못된 내용이 있으면 직접 수정해주세요.',
            style: TextStyle(fontSize: 12, color: kPubText.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          _reviewField('사업자 번호', _bizNoCtrl, '000-00-00000'),
          const SizedBox(height: 10),
          _reviewField('상호 (치과명)', _clinicNameCtrl, '○○치과의원'),
          const SizedBox(height: 10),
          _reviewField('대표자명', _ownerNameCtrl, '홍길동'),
          const SizedBox(height: 10),
          _reviewField('개업일', _openedAtCtrl, 'YYYYMMDD'),
          const SizedBox(height: 10),
          _reviewField('사업장 주소', _addressCtrl, '서울시 강남구 …'),
        ],
      ),
    );
  }

  Widget _reviewField(String label, TextEditingController ctrl, String hint) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(fontSize: 14, color: kPubText),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: kPubText.withOpacity(0.35)),
        labelStyle: TextStyle(fontSize: 12, color: kPubText.withOpacity(0.65)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
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
          borderSide: const BorderSide(color: kPubBlue, width: 1.5),
        ),
        filled: true,
        fillColor: kPubBg,
      ),
    );
  }

  // ── STEP 3: 확인 + 최종 제출 ─────────────────────────
  Widget _confirmAndSubmit() {
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepLabel('STEP 3', '확인 및 제출'),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _confirmed,
                  onChanged: (v) => setState(() => _confirmed = v ?? false),
                  activeColor: kPubBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: const BorderSide(color: kPubBorder),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'AI가 읽어온 내용을 직접 확인했습니다.',
                  style: TextStyle(fontSize: 13, color: kPubText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PubPrimaryButton(
            label: '제출하기',
            isLoading: _isLoading,
            onPressed: _confirmed ? _finalSubmit : null,
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '제출 후 당일~1영업일 내 검토됩니다.',
              style: TextStyle(fontSize: 11, color: kPubText.withOpacity(0.4)),
            ),
          ),
        ],
      ),
    );
  }

  // ── 제출 완료 화면 ────────────────────────────────────
  Widget _buildSuccessView() {
    return PubScaffold(
      title: '사업자 인증',
      showBack: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: kPubBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: kPubBlue,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '서류를 제출했어요!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: kPubText,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '서류를 검토 중이에요.\n보통 당일~1영업일 내 처리됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: kPubText.withOpacity(0.5),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              PubPrimaryButton(
                label: '진행 상태 확인하기',
                onPressed: () => context.go('/publisher/onboarding'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepLabel(String step, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: kPubBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            step,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: kPubBlue,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: kPubText,
          ),
        ),
      ],
    );
  }

  Widget _loadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: kPubBlue),
              const SizedBox(height: 16),
              Text(
                'AI가 사업자등록증을 읽는 중...',
                style: TextStyle(
                  fontSize: 13,
                  color: kPubText.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


