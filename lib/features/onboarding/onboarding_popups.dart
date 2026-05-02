import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_modal_scaffold.dart';
import '../../services/funnel_onboarding_service.dart';
import '../../services/onboarding_workplace_service.dart';

// ─────────────────────────────────────────────────────────────
// 팝업 1: 닉네임 입력 (Step2)
// ─────────────────────────────────────────────────────────────
class OnboardingNicknamePopup extends StatefulWidget {
  final void Function(String nickname) onDone;

  const OnboardingNicknamePopup({super.key, required this.onDone});

  @override
  State<OnboardingNicknamePopup> createState() =>
      _OnboardingNicknamePopupState();
}

class _OnboardingNicknamePopupState extends State<OnboardingNicknamePopup> {
  final _ctrl = TextEditingController();
  bool _canSubmit = false;

  // 설정 화면과 동일한 랜덤 닉네임 목록 (대표 20개)
  static const _suggestions = [
    '스케일링중독자',
    '치은여왕',
    '어금니의비밀',
    '멸균요정',
    '핸드피스마스터',
    '버티는치위생',
    '야근의전설',
    '인상채득러버',
    '치경거울요정',
    '소독실의숨결',
    '핀셋천재',
    '레진수호자',
    '기구정리장인',
    '체어위의철학자',
    '치은선지킴이',
    '석션장인',
    '물분사요정',
    '진료실탐험가',
    '멘탈마취전문',
    '스케일링왕자',
    '칫솔들고철학',
    '레진빛광채',
    '초음파의속삭임',
    '교합의운명',
    '기구트레이요정',
    '진료실생존자',
    '차트의그림자',
    '스케일링한숨',
    '치과의밤바람',
    '멘탈스케일링',
    '실습의추억',
    '소독실은나의것',
    '치은빛노을',
    '체어사이드고수',
    '석션한모금',
    '근무표전사',
    '점심은없다',
    '퇴근을꿈꾸는자',
    '치위생감성',
    '사랑니헌터',
  ];

  void _randomNickname() {
    final rng = Random();
    final pick = _suggestions[rng.nextInt(_suggestions.length)];
    _ctrl.text = pick;
    setState(() => _canSubmit = true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppModalDialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      cardPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '나의 닉네임은',
            style: GoogleFonts.notoSansKr(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '언제든 바꿀 수 있어',
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md + 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  maxLength: 12,
                  onChanged:
                      (v) => setState(() => _canSubmit = v.trim().isNotEmpty),
                  decoration: InputDecoration(
                    hintText: '닉네임 입력',
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.surfaceMuted,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md + 2,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(
                        color: AppColors.divider,
                        width: 0.8,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(
                        color: AppColors.accent,
                        width: 1.4,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(
                        color: AppColors.divider,
                        width: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: IconButton(
                  onPressed: _randomNickname,
                  icon: const Text('🎲', style: TextStyle(fontSize: 18)),
                  tooltip: '랜덤 닉네임',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _canSubmit ? () => widget.onDone(_ctrl.text.trim()) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                disabledBackgroundColor: AppColors.disabledBg,
                disabledForegroundColor: AppColors.disabledText,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
              child: Text(
                '확인',
                style: GoogleFonts.notoSansKr(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 커리어 카드 수정 시 `career_identity_section` 의 `_tagOptions` 와 동일 순서·문구 유지
const _onboardingCareerSpecialtyTags = <String>[
  '데스크 상담',
  '데스크 코디',
  '데스크 보험청구',
  '진료실 팀원',
  '진료실 팀장',
];

// ─────────────────────────────────────────────────────────────
// 팝업 2: 근무 상태 + 치과/학교 입력 (Step4)
// ─────────────────────────────────────────────────────────────
class OnboardingWorkplacePopup extends StatefulWidget {
  final void Function(WorkStatus status, String placeName) onDone;

  const OnboardingWorkplacePopup({super.key, required this.onDone});

  @override
  State<OnboardingWorkplacePopup> createState() =>
      _OnboardingWorkplacePopupState();
}

class _OnboardingWorkplacePopupState extends State<OnboardingWorkplacePopup> {
  WorkStatus? _selected;
  final _ctrl = TextEditingController();
  final Set<String> _selectedSpecialtyTags = {};
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _showSpecialtySection =>
      _selected != null && _selected != WorkStatus.student;

  String get _hintText {
    switch (_selected) {
      case WorkStatus.student:
        return '학교 이름 입력';
      case WorkStatus.working:
        return '근무 중인 치과 이름';
      case WorkStatus.leave:
        return '마지막 근무한 치과이름';
      case WorkStatus.seeking:
        return '마지막 근무한 치과 또는 학교 이름';
      default:
        return '이름 입력';
    }
  }

  bool get _canSubmit =>
      _selected != null && _ctrl.text.trim().isNotEmpty && !_saving;

  void _onPickStatus(WorkStatus s) {
    setState(() {
      _selected = s;
      _ctrl.clear();
      _selectedSpecialtyTags.clear();
    });
  }

  Widget _statusTile(WorkStatus s) {
    final sel = _selected == s;
    return Material(
      color: sel ? AppColors.accent.withOpacity(0.18) : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onPickStatus(s),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.md,
              ),
              child: Text(
                s.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansKr(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  color: sel ? AppColors.accent : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusGrid() {
    final v = WorkStatus.values;
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _statusTile(v[0])),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: _statusTile(v[1])),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _statusTile(v[2])),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: _statusTile(v[3])),
          ],
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final tagsForSave =
        _showSpecialtySection
            ? _onboardingCareerSpecialtyTags
                .where((t) => _selectedSpecialtyTags.contains(t))
                .toList()
            : const <String>[];
    try {
      await OnboardingWorkplaceService.saveWorkplaceInfo(
        status: _selected!,
        placeName: _ctrl.text.trim(),
        specialtyTags: tagsForSave,
      );
      if (tagsForSave.isNotEmpty) {
        unawaited(FunnelOnboardingService.tryLogFirstCareerSpecialty());
      }
      if (mounted) {
        widget.onDone(_selected!, _ctrl.text.trim());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxW = min(
      400.0,
      MediaQuery.sizeOf(context).width - AppSpacing.lg * 2,
    );

    return AppModalDialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      cardPadding: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '나는 지금',
                style: GoogleFonts.notoSansKr(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '너만 볼 수 있고 언제든 바꿀 수 있어',
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _statusGrid(),
              if (_selected != null) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  maxLength: 30,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: _hintText,
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.surfaceMuted,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md + 2,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(
                        color: AppColors.divider,
                        width: 0.8,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(
                        color: AppColors.accent,
                        width: 1.4,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(
                        color: AppColors.divider,
                        width: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
              if (_showSpecialtySection) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  '전문 분야(선택)',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final t in _onboardingCareerSpecialtyTags)
                      FilterChip(
                        label: Text(t),
                        selected: _selectedSpecialtyTags.contains(t),
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              _selectedSpecialtyTags.add(t);
                            } else {
                              _selectedSpecialtyTags.remove(t);
                            }
                          });
                        },
                        selectedColor: AppColors.accent.withOpacity(0.2),
                        checkmarkColor: AppColors.accent,
                        side: const BorderSide(
                          color: AppColors.divider,
                          width: 0.8,
                        ),
                        labelStyle: TextStyle(
                          color: AppColors.textPrimary.withOpacity(0.85),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    disabledBackgroundColor: AppColors.disabledBg,
                    disabledForegroundColor: AppColors.disabledText,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                  child:
                      _saving
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.onAccent,
                            ),
                          )
                          : Text(
                            '확인',
                            style: GoogleFonts.notoSansKr(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
