import 'package:flutter/material.dart';
import '../models/user_public_profile.dart';
import '../services/user_profile_service.dart';

/// Step B 게이트: 주 고민(최대 2개) + 근무 유형(선택)
///
/// [onComplete] — 저장 성공 후 호출 (매칭 진행 등)
class PartnerGateSheet extends StatefulWidget {
  final VoidCallback? onComplete;

  const PartnerGateSheet({super.key, this.onComplete});

  @override
  State<PartnerGateSheet> createState() => _PartnerGateSheetState();
}

class _PartnerGateSheetState extends State<PartnerGateSheet> {
  final Set<String> _selectedConcerns = {};
  String? _selectedWorkplace;
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
        _selectedConcerns.addAll(profile.mainConcerns);
        _selectedWorkplace = profile.workplaceType;
      });
    }
  }

  bool get _canSave =>
      _selectedConcerns.isNotEmpty &&
      _selectedConcerns.length <= 2 &&
      !_saving;

  void _toggleConcern(String concern) {
    setState(() {
      if (_selectedConcerns.contains(concern)) {
        _selectedConcerns.remove(concern);
      } else if (_selectedConcerns.length < 2) {
        _selectedConcerns.add(concern);
      }
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await UserProfileService.updatePartnerProfile(
        mainConcerns: _selectedConcerns.toList(),
        workplaceType: _selectedWorkplace,
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
        color: Colors.white,
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
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 제목
            const Center(
              child: Text(
                '주로 하는 고민',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6A5ACD),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                '비슷한 고민을 가진 사람과 연결돼요.\n1~2개만 골라주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ),
            const SizedBox(height: 24),

            // ── 고민 선택 (체크박스, 최대 2개) ──
            _label('고민 (최대 2개)'),
            const SizedBox(height: 8),
            ...UserPublicProfile.concernOptions.map((concern) {
              final selected = _selectedConcerns.contains(concern);
              final disabled =
                  !selected && _selectedConcerns.length >= 2;
              return CheckboxListTile(
                value: selected,
                title: Text(
                  concern,
                  style: TextStyle(
                    fontSize: 14,
                    color: disabled ? Colors.grey[400] : Colors.black87,
                  ),
                ),
                activeColor: const Color(0xFF6A5ACD),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: disabled && !selected
                    ? null
                    : (_) => _toggleConcern(concern),
              );
            }),

            const SizedBox(height: 20),

            // ── 근무 유형 (선택) ──
            _label('근무 유형 (선택)'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedWorkplace,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              hint: const Text('선택 안 함'),
              items: UserPublicProfile.workplaceTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedWorkplace = v),
            ),
            const SizedBox(height: 28),

            // 에러
            if (_error != null) ...[
              Text(_error!,
                  style:
                      const TextStyle(color: Colors.redAccent, fontSize: 12)),
              const SizedBox(height: 8),
            ],

            // ── 저장 버튼 ──
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _canSave ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A5ACD),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('저장하고 매칭',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),

            // 나중에 버튼
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('나중에',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14)),
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
        color: Color(0xFF424242),
      ),
    );
  }
}

