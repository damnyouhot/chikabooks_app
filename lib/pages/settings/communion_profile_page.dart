import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_primary_button.dart';
import '../../models/user_public_profile.dart';
import '../../services/admin_activity_service.dart';
import '../../services/app_error_logger.dart';
import '../../services/user_profile_service.dart';

/// 교감 프로필 수정 페이지 (설정 > 교감 프로필)
class CommunionProfilePage extends StatefulWidget {
  const CommunionProfilePage({super.key});

  @override
  State<CommunionProfilePage> createState() => _CommunionProfilePageState();
}

class _CommunionProfilePageState extends State<CommunionProfilePage> {
  final _nicknameCtrl = TextEditingController();
  String? _selectedRegion;
  String? _selectedCareer;
  String _existingCareerGroup = ''; // 기존 careerGroup 보존용
  final Set<String> _selectedConcerns = {};
  String? _selectedWorkplace;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile =
        await UserProfileService.getMyProfile(forceRefresh: true);
    if (profile != null && mounted) {
      setState(() {
        _nicknameCtrl.text = profile.nickname;
        _selectedRegion =
            profile.region.isNotEmpty ? profile.region : null;
        _selectedCareer =
            profile.careerBucket.isNotEmpty ? profile.careerBucket : null;
        _existingCareerGroup = profile.careerGroup; // 기존 값 보존
        _selectedConcerns.addAll(profile.mainConcerns);
        _selectedWorkplace = profile.workplaceType;
      });
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  void _generateRandomNickname() {
    final rng = Random();
    final num = rng.nextInt(900) + 100;
    _nicknameCtrl.text = '익명치위$num';
    setState(() {});
  }

  void _toggleConcern(String concern) {
    setState(() {
      if (_selectedConcerns.contains(concern)) {
        _selectedConcerns.remove(concern);
      } else if (_selectedConcerns.length < 2) {
        _selectedConcerns.add(concern);
      }
    });
  }

  bool get _canSave =>
      _nicknameCtrl.text.trim().length >= 2 &&
      _nicknameCtrl.text.trim().length <= 10 &&
      _selectedRegion != null &&
      _selectedCareer != null &&
      !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);

    try {
      // careerGroup: 기존 값 보존. careerBucket이 바뀌었으면 라벨 맵에서 파생
      final careerGroup = _existingCareerGroup.isNotEmpty
          ? _existingCareerGroup
          : (UserPublicProfile.careerBucketLabels[_selectedCareer!] ?? _selectedCareer!);

      final profile = UserPublicProfile(
        nickname: _nicknameCtrl.text.trim(),
        region: _selectedRegion!,
        careerBucket: _selectedCareer!,
        careerGroup: careerGroup,
        mainConcerns: _selectedConcerns.toList(),
        workplaceType: _selectedWorkplace,
      );
      await UserProfileService.updateFullProfile(profile);
      // 캐시 초기화 → 결 탭 복귀 시 publicProfiles에서 최신 닉네임 재조회
      UserProfileService.clearCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필이 저장되었어요 ✨')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('교감 프로필'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 닉네임 ──
                  _sectionTitle('닉네임'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nicknameCtrl,
                          maxLength: 10,
                          decoration: InputDecoration(
                            hintText: '2~10자',
                            counterText: '',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _generateRandomNickname,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child:
                            const Text('🎲', style: TextStyle(fontSize: 18)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── 지역 ──
                  _sectionTitle('지역'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedRegion,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    hint: const Text('광역/도 선택'),
                    items: UserPublicProfile.regionList
                        .map((r) =>
                            DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedRegion = v),
                  ),
                  const SizedBox(height: 24),

                  // ── 연차 ──
                  _sectionTitle('연차'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    children:
                        UserPublicProfile.careerBuckets.map((bucket) {
                      final selected = _selectedCareer == bucket;
                      return ChoiceChip(
                        label: Text(
                          UserPublicProfile.careerBucketLabels[bucket] ??
                              bucket,
                        ),
                        selected: selected,
                        selectedColor: AppColors.accent.withOpacity(0.15),
                        onSelected: (_) =>
                            setState(() => _selectedCareer = bucket),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),
                  const Divider(),
                  const SizedBox(height: 12),

                  // ── 주 고민 (파트너용 선택, 최대 2개) ──
                  _sectionTitle('주로 하는 고민 (파트너 매칭용, 최대 2개)'),
                  const SizedBox(height: 8),
                  ...UserPublicProfile.concernOptions.map((concern) {
                    final selected =
                        _selectedConcerns.contains(concern);
                    final disabled =
                        !selected && _selectedConcerns.length >= 2;
                    return CheckboxListTile(
                      value: selected,
                      title: Text(
                        concern,
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              disabled ? AppColors.textDisabled : AppColors.textPrimary,
                        ),
                      ),
                      activeColor: AppColors.accent,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: disabled && !selected
                          ? null
                          : (_) => _toggleConcern(concern),
                    );
                  }),
                  const SizedBox(height: 20),

                  // ── 근무 유형 ──
                  _sectionTitle('근무 유형 (선택)'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedWorkplace,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    hint: const Text('선택 안 함'),
                    items: UserPublicProfile.workplaceTypes
                        .map((t) =>
                            DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedWorkplace = v),
                  ),
                  const SizedBox(height: 32),

                  // ── 저장 ──
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: AppPrimaryButton(
                      label: '저장',
                      onPressed: _canSave ? _save : null,
                      isEnabled: _canSave,
                      isLoading: _saving,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── 로그아웃 ──
                  Center(
                    child: TextButton.icon(
                      onPressed: () async {
                        AdminActivityService.clearCache();
                        AppErrorLogger.clearCache();
                        UserProfileService.clearCache();
                        await FirebaseAuth.instance.signOut();
                      },
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('로그아웃'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}



