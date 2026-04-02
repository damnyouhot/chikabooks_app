import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/clinic_profile.dart';
import '../services/clinic_profile_service.dart';

/// 치과 선택/생성 다이얼로그
///
/// 프로필 0개 → 새 치과 추가 폼
/// 프로필 1개 → 자동 선택 (호출자에게 즉시 반환)
/// 프로필 2개+ → 목록에서 선택
class ClinicSelector {
  /// 치과를 선택하거나 새로 생성한 뒤 profileId를 반환.
  /// null이면 취소.
  static Future<ClinicProfile?> select(BuildContext context) async {
    final profiles = await ClinicProfileService.getProfiles();

    if (profiles.length == 1) return profiles.first;

    if (!context.mounted) return null;

    if (profiles.isEmpty) {
      return _showCreateDialog(context);
    }

    return showDialog<ClinicProfile>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SelectorDialog(profiles: profiles),
    );
  }

  static Future<ClinicProfile?> _showCreateDialog(BuildContext context) {
    return showDialog<ClinicProfile>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _CreateProfileDialog(),
    );
  }
}

class _SelectorDialog extends StatelessWidget {
  final List<ClinicProfile> profiles;
  const _SelectorDialog({required this.profiles});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '어떤 치과의 공고를 올리시나요?',
                style: GoogleFonts.notoSansKr(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ...profiles.map((p) => _profileTile(context, p)),
              const SizedBox(height: 8),
              const Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  final created = await ClinicSelector._showCreateDialog(context);
                  if (context.mounted && created != null) {
                    Navigator.pop(context, created);
                  }
                },
                icon: const Icon(Icons.add, size: 18, color: AppColors.accent),
                label: Text(
                  '새 치과 추가',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileTile(BuildContext context, ClinicProfile p) {
    return InkWell(
      onTap: () => Navigator.pop(context, p),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider.withOpacity(0.5))),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.local_hospital_outlined,
                  size: 18, color: AppColors.accent.withOpacity(0.7)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.effectiveName.isNotEmpty ? p.effectiveName : '(이름 없음)',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (p.address.isNotEmpty)
                    Text(
                      p.address,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (p.isBusinessVerified)
              Icon(Icons.verified, size: 16, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

class _CreateProfileDialog extends StatefulWidget {
  const _CreateProfileDialog();

  @override
  State<_CreateProfileDialog> createState() => _CreateProfileDialogState();
}

class _CreateProfileDialogState extends State<_CreateProfileDialog> {
  final _nameCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final profileId = await ClinicProfileService.createProfile(
        clinicName: name,
        displayName: name,
      );
      if (profileId != null && mounted) {
        final profile = await ClinicProfileService.getProfile(profileId);
        if (mounted) Navigator.pop(context, profile);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('생성 중 오류가 발생했어요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '새 치과 추가',
                style: GoogleFonts.notoSansKr(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '나중에 등록증을 올리면 정확한 정보로 자동 보완돼요',
                style: GoogleFonts.notoSansKr(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.notoSansKr(fontSize: 14),
                decoration: InputDecoration(
                  labelText: '치과명',
                  hintText: '예: 하이진치과의원',
                  border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppColors.accent, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          side: const BorderSide(color: AppColors.divider),
                        ),
                        child: Text('취소',
                            style: GoogleFonts.notoSansKr(
                                fontSize: 14, color: AppColors.textSecondary)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: (_nameCtrl.text.trim().isNotEmpty && !_isLoading)
                            ? _create
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.white))
                            : Text('추가',
                                style: GoogleFonts.notoSansKr(
                                    fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
