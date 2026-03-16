import 'dart:math';
import 'package:flutter/material.dart';
import '../models/user_public_profile.dart';
import '../services/user_profile_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_primary_button.dart';

/// Step A 게이트: 닉네임 / 지역 / 연차 입력
///
/// [onComplete] — 저장 성공 후 호출 (시트 닫은 뒤 원래 기능 실행용)
class ProfileGateSheet extends StatefulWidget {
  final VoidCallback? onComplete;

  const ProfileGateSheet({super.key, this.onComplete});

  @override
  State<ProfileGateSheet> createState() => _ProfileGateSheetState();
}

class _ProfileGateSheetState extends State<ProfileGateSheet> {
  final _nicknameCtrl = TextEditingController();
  String? _selectedRegion;
  String? _selectedCareer;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final profile = await UserProfileService.getMyProfile();
    if (profile != null && mounted) {
      setState(() {
        if (profile.nickname.isNotEmpty) {
          _nicknameCtrl.text = profile.nickname;
        }
        if (profile.region.isNotEmpty) _selectedRegion = profile.region;
        if (profile.careerBucket.isNotEmpty) {
          _selectedCareer = profile.careerBucket;
        }
      });
    }
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  void _generateRandomNickname() {
    final rng = Random();
    final num = rng.nextInt(900) + 100; // 100~999
    _nicknameCtrl.text = '익명치위$num';
    setState(() {});
  }

  bool get _canSave =>
      _nicknameCtrl.text.trim().length >= 2 &&
      _nicknameCtrl.text.trim().length <= 10 &&
      _selectedRegion != null &&
      _selectedCareer != null &&
      !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // careerBucket → careerGroup 역산 (매칭 서버 호환)
      final bucket = _selectedCareer!;
      final careerGroup = bucket == '0-2'
          ? '0-2년차'
          : bucket == '3-5'
              ? '3-5년차'
              : '6년차 이상';

      await UserProfileService.updateBasicProfile(
        nickname: _nicknameCtrl.text.trim(),
        region: _selectedRegion!,
        careerBucket: _selectedCareer!,
        careerGroup: careerGroup,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onComplete?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '저장 실패: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 드래그 핸들
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 제목
            const Center(
              child: Text(
                '교감 프로필',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                '서로를 너무 자세히는 몰라도 돼요.\n세 가지만 알려주세요. (20초)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textDisabled),
              ),
            ),
            const SizedBox(height: 24),

            // ── 닉네임 ──
            _label('닉네임'),
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
                        borderRadius: BorderRadius.circular(AppRadius.md),
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
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: const Text('🎲', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── 지역 ──
            _label('지역'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedRegion,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              hint: const Text('광역/도 선택'),
              items: UserPublicProfile.regionList
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedRegion = v),
            ),
            const SizedBox(height: 20),

            // ── 연차 ──
            _label('연차'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              children: UserPublicProfile.careerBuckets.map((bucket) {
                final selected = _selectedCareer == bucket;
                return ChoiceChip(
                  label: Text(
                      UserPublicProfile.careerBucketLabels[bucket] ?? bucket),
                  selected: selected,
                  selectedColor: AppColors.accent.withOpacity(0.15),
                  onSelected: (_) =>
                      setState(() => _selectedCareer = bucket),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            // 에러 메시지
            if (_error != null) ...[
              Text(_error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12)),
              const SizedBox(height: 8),
            ],

            // ── 저장 버튼 ──
            AppPrimaryButton(
              label: '저장하고 계속',
              onPressed: _canSave ? _save : null,
              isLoading: _saving,
              radius: AppRadius.md,
            ),
            const SizedBox(height: 10),

            // 나중에 버튼
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textDisabled,
                ),
                child: const Text('나중에', style: TextStyle(fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
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
