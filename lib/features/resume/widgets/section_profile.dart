import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../models/resume.dart';
import '../../../models/resume_intro_enums.dart';
import '../../../core/theme/app_colors.dart';
import '../services/resume_photo_uploader.dart';
import 'resume_ocr_prompt.dart';
import 'resume_inline_underline_field.dart';

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

  late ExperienceLevel _experienceLevel;
  late JobGoal _jobGoal;

  static const _maxPhotos = 1;
  static const _workTypeOptions = ['정규직', '파트타임', '주말', '야간', '단기'];

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
    _experienceLevel = p.experienceLevel;
    _jobGoal = p.jobGoal;
    final rawPhotos = List<String>.from(p.photoUrls);
    _photoUrls = rawPhotos.length > 1 ? [rawPhotos.first] : rawPhotos;
    _selectedPhotoIndex = 0;
    if (rawPhotos.length > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _emit();
      });
    }
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
    final p = widget.profile ?? const ResumeProfile();
    widget.onChanged(
      p.copyWith(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        region: _regionCtrl.text.trim(),
        workTypes: _workTypes,
        headline: _headlineCtrl.text.trim(),
        summary: p.summary,
        clinicalSkillsComment: p.clinicalSkillsComment,
        softSkillsComment: p.softSkillsComment,
        photoUrls: _photoUrls,
        selectedPhotoIndex: _selectedPhotoIndex,
        experienceLevel: _experienceLevel,
        jobGoal: _jobGoal,
      ),
    );
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_photoUrls.isNotEmpty || _isUploadingPhoto) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    if (!mounted) return;

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
        _photoUrls = [url];
        _selectedPhotoIndex = 0;
      });
      _emit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('사진 업로드 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  /// 1장만 허용 — 기존 사진을 탭했을 때 갤러리에서 다시 고름
  Future<void> _replacePhoto() async {
    if (_photoUrls.isEmpty || _isUploadingPhoto) return;
    final previousUrl = _photoUrls.first;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    if (!mounted) return;

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
        _photoUrls = [url];
        _selectedPhotoIndex = 0;
      });
      _emit();
      await ResumePhotoUploader.deletePhoto(previousUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('사진 교체 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
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
        _sectionTitle('이력서 사진', '정사각형 1장만 등록할 수 있어요. 등록한 사진을 탭하면 교체돼요.'),
        const SizedBox(height: 12),
        _buildPhotoSection(),

        const SizedBox(height: 24),
        _sectionTitle('기본정보', '이름과 연락처는 지원 시 익명 처리돼요.'),
        const SizedBox(height: 12),
        const ResumeOcrPrompt(),

        ResumeInlineUnderlineField(
          label: '이름 *',
          hint: '홍길동',
          controller: _nameCtrl,
          onChanged: (_) => _emit(),
        ),
        ResumeInlineUnderlineField(
          label: '휴대폰 *',
          hint: '010-0000-0000',
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          onChanged: (_) => _emit(),
        ),
        ResumeInlineUnderlineField(
          label: '이메일 *',
          hint: 'example@email.com',
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => _emit(),
        ),
        ResumeInlineUnderlineField(
          label: '거주지 (시/구)',
          hint: '서울시 강남구',
          controller: _regionCtrl,
          onChanged: (_) => _emit(),
        ),
        ResumeInlineUnderlineField(
          label: '한줄소개',
          hint: '밝고 성실한 3년차 치과위생사입니다.',
          controller: _headlineCtrl,
          onChanged: (_) => _emit(),
        ),

        const SizedBox(height: 20),
        _sectionTitle('희망 근무형태', '복수 선택 가능'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.start,
          children:
              _workTypeOptions.map((type) {
                final selected = _workTypes.contains(type);
                return FilterChip(
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
                    color:
                        selected
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
                );
              }).toList(),
        ),

        const SizedBox(height: 20),
        _sectionTitle('경력 단계 · 희망 방향', '자기소개 문장 추천에 반영돼요. 비워 두면 스킬·경력만으로 맞춰요.'),
        const SizedBox(height: 8),
        Text(
          '경력 단계',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _levelChip('선택 안 함', ExperienceLevel.any),
            _levelChip('신입·초급', ExperienceLevel.junior),
            _levelChip('중간', ExperienceLevel.mid),
            _levelChip('시니어', ExperienceLevel.senior),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '희망 방향',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _goalChip('일반', JobGoal.general),
            _goalChip('교정', JobGoal.orthodontics),
            _goalChip('수술·임플란트', JobGoal.surgery),
            _goalChip('상담·CS', JobGoal.counseling),
            _goalChip('팀·운영', JobGoal.manager),
            _goalChip('재취업', JobGoal.reemployment),
          ],
        ),
      ],
    );
  }

  Widget _levelChip(String label, ExperienceLevel value) {
    final selected = _experienceLevel == value;
    return FilterChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      selected: selected,
      selectedColor: AppColors.accent.withOpacity(0.15),
      checkmarkColor: AppColors.accent,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(
        color: selected ? AppColors.accent.withOpacity(0.5) : AppColors.divider,
      ),
      onSelected: (_) {
        setState(() => _experienceLevel = value);
        _emit();
      },
    );
  }

  Widget _goalChip(String label, JobGoal value) {
    final selected = _jobGoal == value;
    return FilterChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      selected: selected,
      selectedColor: AppColors.accent.withOpacity(0.15),
      checkmarkColor: AppColors.accent,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(
        color: selected ? AppColors.accent.withOpacity(0.5) : AppColors.divider,
      ),
      onSelected: (_) {
        setState(() => _jobGoal = value);
        _emit();
      },
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
            final highlight = _maxPhotos == 1 || isSelected;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: _replacePhoto,
                onLongPress: () => _showDeleteDialog(i),
                child: Stack(
                  children: [
                    Container(
                      width: thumb,
                      height: thumb,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              highlight ? AppColors.accent : AppColors.divider,
                          width: highlight ? 2.5 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => Container(
                                color: AppColors.divider,
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  color: AppColors.textDisabled,
                                ),
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
                          child: const Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.white,
                          ),
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
                child:
                    _isUploadingPhoto
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
                            Icon(
                              Icons.add_a_photo_outlined,
                              size: 24,
                              color: AppColors.textDisabled,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_photoUrls.length}/$_maxPhotos',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textDisabled,
                              ),
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
      builder:
          (ctx) => AlertDialog(
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
}
