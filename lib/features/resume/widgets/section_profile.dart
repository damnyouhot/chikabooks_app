import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../models/resume.dart';
import '../../../core/theme/app_colors.dart';
import '../services/resume_photo_uploader.dart';
import 'resume_ocr_prompt.dart';

/// A. 기본정보 섹션 (이력서 사진 포함)
class SectionProfile extends StatefulWidget {
  final ResumeProfile? profile;
  final ValueChanged<ResumeProfile> onChanged;

  const SectionProfile({super.key, this.profile, required this.onChanged});

  @override
  State<SectionProfile> createState() => _SectionProfileState();
}

class _SectionProfileState extends State<SectionProfile> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _regionCtrl;
  late final TextEditingController _headlineCtrl;
  List<String> _workTypes = [];

  List<String> _photoUrls = [];
  int _selectedPhotoIndex = 0;
  bool _isUploadingPhoto = false;

  static const _maxPhotos = 3;
  static const _workTypeOptions = [
    '정규직',
    '파트타임',
    '주말',
    '야간',
    '단기',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.profile ?? const ResumeProfile();
    _nameCtrl = TextEditingController(text: p.name);
    _phoneCtrl = TextEditingController(text: p.phone);
    _emailCtrl = TextEditingController(text: p.email);
    _regionCtrl = TextEditingController(text: p.region);
    _headlineCtrl = TextEditingController(text: p.headline);
    _workTypes = List<String>.from(p.workTypes);
    _photoUrls = List<String>.from(p.photoUrls);
    _selectedPhotoIndex = p.selectedPhotoIndex;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _regionCtrl.dispose();
    _headlineCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(ResumeProfile(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      region: _regionCtrl.text.trim(),
      workTypes: _workTypes,
      headline: _headlineCtrl.text.trim(),
      summary: widget.profile?.summary ?? '',
      photoUrls: _photoUrls,
      selectedPhotoIndex: _selectedPhotoIndex,
    ));
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_photoUrls.length >= _maxPhotos || _isUploadingPhoto) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    // 정사각형 크롭 (웹에서는 image_cropper_for_web 사용)
    CroppedFile? cropped;
    try {
      cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 85,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '이력서 사진 자르기',
            toolbarColor: AppColors.accent,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
            hideBottomControls: true,
          ),
          IOSUiSettings(
            title: '이력서 사진 자르기',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
          WebUiSettings(
            context: context,
            size: const CropperSize(width: 400, height: 400),
          ),
        ],
      );
    } catch (e) {
      debugPrint('⚠️ ImageCropper error: $e');
    }

    if (cropped == null) return;
    if (!mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final url = await ResumePhotoUploader.uploadPhoto(
        userId: uid,
        image: XFile(cropped.path),
      );
      if (!mounted) return;
      setState(() {
        _photoUrls.add(url);
        if (_photoUrls.length == 1) _selectedPhotoIndex = 0;
      });
      _emit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사진 업로드 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _selectPhoto(int index) {
    setState(() => _selectedPhotoIndex = index);
    _emit();
  }

  Future<void> _deletePhoto(int index) async {
    final url = _photoUrls[index];
    setState(() {
      _photoUrls.removeAt(index);
      if (_selectedPhotoIndex >= _photoUrls.length) {
        _selectedPhotoIndex = _photoUrls.isEmpty ? 0 : _photoUrls.length - 1;
      }
    });
    _emit();
    ResumePhotoUploader.deletePhoto(url);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        _sectionTitle(
            '이력서 사진', '최대 3장, 정사각형. 대표 사진을 탭으로 선택하세요.'),
        const SizedBox(height: 12),
        _buildPhotoSection(),

        const SizedBox(height: 24),
        _sectionTitle('기본정보', '이름과 연락처는 지원 시 익명 처리돼요.'),
        const SizedBox(height: 12),
        const ResumeOcrPrompt(),

        _field('이름 *', _nameCtrl, '홍길동'),
        _field('휴대폰 *', _phoneCtrl, '010-0000-0000',
            keyboard: TextInputType.phone),
        _field('이메일 *', _emailCtrl, 'example@email.com',
            keyboard: TextInputType.emailAddress),
        _field('거주지 (시/구)', _regionCtrl, '서울시 강남구'),
        _field('한줄소개', _headlineCtrl, '밝고 성실한 3년차 치과위생사입니다.'),

        const SizedBox(height: 20),
        _sectionTitle('희망 근무형태', '복수 선택 가능'),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) {
            const gap = 8.0;
            final w = (c.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: _workTypeOptions.map((type) {
                final selected = _workTypes.contains(type);
                return SizedBox(
                  width: w,
                  child: FilterChip(
                    label: Text(
                      type,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: selected,
                    selectedColor: AppColors.accent.withOpacity(0.15),
                    checkmarkColor: AppColors.accent,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide(
                      color: selected
                          ? AppColors.accent.withOpacity(0.5)
                          : AppColors.divider,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _workTypes.add(type);
                        } else {
                          _workTypes.remove(type);
                        }
                      });
                      _emit();
                    },
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    const thumb = 120.0;
    return SizedBox(
      height: thumb,
      child: Row(
        children: [
          ..._photoUrls.asMap().entries.map((entry) {
            final i = entry.key;
            final url = entry.value;
            final isSelected = i == _selectedPhotoIndex;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => _selectPhoto(i),
                onLongPress: () => _showDeleteDialog(i),
                child: Stack(
                  children: [
                    Container(
                      width: thumb,
                      height: thumb,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.accent : AppColors.divider,
                          width: isSelected ? 2.5 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.divider,
                            child: const Icon(Icons.broken_image_outlined,
                                color: AppColors.textDisabled),
                          ),
                        ),
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        bottom: 4,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '대표',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => _showDeleteDialog(i),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (_photoUrls.length < _maxPhotos)
            GestureDetector(
              onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
              child: Container(
                width: thumb,
                height: thumb,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                  color: AppColors.appBg,
                ),
                child: _isUploadingPhoto
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined,
                              size: 24, color: AppColors.textDisabled),
                          const SizedBox(height: 4),
                          Text(
                            '${_photoUrls.length}/$_maxPhotos',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textDisabled),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }

  void _showDeleteDialog(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('사진 삭제'),
        content: const Text('이 이력서 사진을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deletePhoto(index);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
        ),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    String hint, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        onChanged: (_) => _emit(),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textDisabled),
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}

