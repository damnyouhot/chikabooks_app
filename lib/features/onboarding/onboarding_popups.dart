import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/onboarding_workplace_service.dart';

const _kBg = Color(0xFFFFFBF9);
const _kText = Color(0xFF3D3535);
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
            TextField(
              controller: _ctrl,
              autofocus: true,
              maxLength: 12,
              onChanged: (v) => setState(() => _canSubmit = v.trim().isNotEmpty),
              decoration: InputDecoration(
                hintText: '닉네임 입력',
                counterText: '',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _kAccent, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
              ),
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
                  foregroundColor: Colors.white,
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
      case WorkStatus.leave:
        return '근무 중인 치과 이름 (나만 보여요)';
      case WorkStatus.seeking:
        return '마지막 근무한 치과 (나만 보여요)';
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
                      backgroundColor: Colors.white,
                      labelStyle: GoogleFonts.notoSansKr(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : _kText.withOpacity(0.7),
                      ),
                      side: BorderSide(
                        color: selected ? _kAccent : const Color(0xFFDDDDDD),
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
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _kAccent, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
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
                  foregroundColor: Colors.white,
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
                              color: Colors.white,
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

