import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/onboarding_workplace_service.dart';
import '../../core/theme/app_colors.dart';

// _kBg: 따뜻한 크림 배경 — 온보딩 다이얼로그 전용, 의도적 유지
const _kBg = Color(0xFFFFFBF9);
// _kText: 온보딩 다이얼로그 전용 텍스트 톤 — AppColors.textPrimary 대신 약간 따뜻한 느낌
const _kText = Color(0xFF3D3535);
// _kAccent: 온보딩 민트/그린 액센트 — 앱 메인 accent와 별개 의도적 유지
const _kAccent = Color(0xFF6BBFA0);
const _kRadius = 20.0;

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
    '스케일링중독자', '치은여왕', '어금니의비밀', '멸균요정', '핸드피스마스터',
    '버티는치위생', '야근의전설', '인상채득러버', '치경거울요정', '소독실의숨결',
    '핀셋천재', '레진수호자', '기구정리장인', '체어위의철학자', '치은선지킴이',
    '석션장인', '물분사요정', '진료실탐험가', '멘탈마취전문', '스케일링왕자',
    '칫솔들고철학', '레진빛광채', '초음파의속삭임', '교합의운명', '기구트레이요정',
    '진료실생존자', '차트의그림자', '스케일링한숨', '치과의밤바람', '멘탈스케일링',
    '실습의추억', '소독실은나의것', '치은빛노을', '체어사이드고수', '석션한모금',
    '근무표전사', '점심은없다', '퇴근을꿈꾸는자', '치위생감성', '사랑니헌터',
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
    return Dialog(
      backgroundColor: _kBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '나의 닉네임은',
              style: GoogleFonts.notoSansKr(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _kText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '언제든 바꿀 수 있어',
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                color: _kText.withOpacity(0.55),
              ),
            ),
            const SizedBox(height: 20),
            // ── TextField + 주사위 버튼 Row ──
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    maxLength: 12,
                    onChanged: (v) =>
                        setState(() => _canSubmit = v.trim().isNotEmpty),
                    decoration: InputDecoration(
                      hintText: '닉네임 입력',
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: _kAccent, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 🎲 랜덤 닉네임 주사위 버튼
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    onPressed: _randomNickname,
                    icon: const Text('🎲', style: TextStyle(fontSize: 18)),
                    tooltip: '랜덤 닉네임',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _canSubmit
                        ? () => widget.onDone(_ctrl.text.trim())
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor: _kAccent.withOpacity(0.35),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '확인',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _kBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '나는 지금',
              style: GoogleFonts.notoSansKr(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _kText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '너만 볼 수 있고 언제든 바꿀 수 있어',
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                color: _kText.withOpacity(0.55),
              ),
            ),
            const SizedBox(height: 20),

            // ── 상태 선택 칩 ──
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  WorkStatus.values.map((s) {
                    final selected = _selected == s;
                    return ChoiceChip(
                      label: Text(s.label),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        _selected = s;
                        _ctrl.clear();
                      }),
                      selectedColor: _kAccent,
                      backgroundColor: AppColors.white,
                      labelStyle: GoogleFonts.notoSansKr(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? AppColors.white : AppColors.textSecondary,
                      ),
                      side: BorderSide(
                        color: selected ? _kAccent : AppColors.divider,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      showCheckmark: false,
                    );
                  }).toList(),
            ),

            if (_selected != null) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _ctrl,
                autofocus: true,
                maxLength: 30,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _hintText,
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: _kAccent, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _canSubmit
                        ? () async {
                            setState(() => _saving = true);
                            await OnboardingWorkplaceService.saveWorkplaceInfo(
                              status: _selected!,
                              placeName: _ctrl.text.trim(),
                            );
                            if (mounted) {
                              widget.onDone(_selected!, _ctrl.text.trim());
                            }
                          }
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor: _kAccent.withOpacity(0.35),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : Text(
                            '확인',
                            style: GoogleFonts.notoSansKr(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
