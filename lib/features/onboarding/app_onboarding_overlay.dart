import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_onboarding_controller.dart';
import 'onboarding_popups.dart';
import '../../services/user_profile_service.dart';
import '../../services/onboarding_service.dart';
import '../../core/theme/app_colors.dart';

// _kText: 온보딩 다이얼로그 전용 따뜻한 텍스트 — 의도적 유지
const _kText = Color(0xFF3D3535);

/// 대사 텍스트 맵
const Map<AppOnboardingStepId, String> kStepDialogue = {
  AppOnboardingStepId.step1a: '안녕!\n난 여기서 언제나 너와 함께할 저니라고 해.',
  AppOnboardingStepId.step1b: '넌 이름이 뭐야?',
  AppOnboardingStepId.step3:  '나는 멍멍 치과에서\n1년차로 일하고 있어.\n넌?',
  AppOnboardingStepId.step5:  '아래 커리어 탭을 눌러봐!',
  AppOnboardingStepId.step6a: '여기서 너의 커리어를 관리할 수 있어.\n겁먹지마 천천히 하나씩 해도 되고,',
  AppOnboardingStepId.step6b: '나중에 이력서를 사진찍어 올리면\nAI가 자동으로 입력해줄거야.',
  AppOnboardingStepId.step6c: '그렇게 완성된 우리 이력서로\n여기서 바로 치과에 지원할 수도 있어.',
  AppOnboardingStepId.step5b: '아래 성장하기 탭도 눌러봐!',
  AppOnboardingStepId.step7a: '여기서 자기 계발도 할 수 있어',
  AppOnboardingStepId.step7b: '나랑 같이 퀴즈, 제도들,\n책으로 공부 하면서 성장해 나가자!',
  AppOnboardingStepId.step8:  '아래 첫 번째 탭으로 가볼까?',
  AppOnboardingStepId.step9a: '난 항상 여기 있을건데\n혹시 나 밥도 주고 사랑도 줄 수 있어?',
  AppOnboardingStepId.step9b: '하루 몇번이면 충분해.',
  AppOnboardingStepId.step9c: '앞으로 잘 지내자.',
};

/// 온보딩 오버레이 위젯
///
/// HomeShell의 Scaffold body 위에 Stack으로 올려서 사용
class AppOnboardingOverlay extends StatefulWidget {
  final AppOnboardingController controller;

  /// 탭 이동 요청 콜백 (HomeShell이 처리)
  final void Function(int tabIndex) onTabChangeRequest;

  /// 온보딩 완료 콜백
  final VoidCallback onComplete;

  const AppOnboardingOverlay({
    super.key,
    required this.controller,
    required this.onTabChangeRequest,
    required this.onComplete,
  });

  @override
  State<AppOnboardingOverlay> createState() => _AppOnboardingOverlayState();
}

class _AppOnboardingOverlayState extends State<AppOnboardingOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  String? _nickname;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500), // 페이드인 0.5초
    );
    _fadeCtrl.forward();

    widget.controller.addListener(_onStepChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleCurrentStep());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStepChanged);
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onStepChanged() {
    if (!mounted) return;
    _fadeCtrl.reset();
    _fadeCtrl.forward();
    setState(() {});
    _handleCurrentStep();
  }

  /// 팝업 or 탭 이동이 필요한 step 처리
  Future<void> _handleCurrentStep() async {
    final step = widget.controller.current;

    if (step == AppOnboardingStepId.step2) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      _showNicknamePopup();
      return;
    }
    if (step == AppOnboardingStepId.step4) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      _showWorkplacePopup();
      return;
    }

    // spotlight step은 탭 터치로 진행 → 탭 자동이동 skip
    if (step == AppOnboardingStepId.step5) return;
    if (step == AppOnboardingStepId.step5b) return;
    if (step == AppOnboardingStepId.step8) return; // 탭1 유도 spotlight

    // 탭 이동이 필요한 step: 현재 탭 != 이전 탭이면 전환
    final tabIndex = kStepTabIndex[step] ?? 0;
    final prev = _prevStep(step);
    final prevTabIndex = prev != null ? (kStepTabIndex[prev] ?? 0) : -1;
    if (tabIndex != prevTabIndex) {
      widget.onTabChangeRequest(tabIndex);
    }
  }

  AppOnboardingStepId? _prevStep(AppOnboardingStepId step) {
    final values = AppOnboardingStepId.values;
    final idx = values.indexOf(step);
    if (idx <= 0) return null;
    return values[idx - 1];
  }

  void _showNicknamePopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.black.withOpacity(0.4),
      builder:
          (_) => OnboardingNicknamePopup(
            onDone: (nickname) async {
              Navigator.of(context).pop();
              _nickname = nickname;

              // users/{uid} 닉네임 저장
              try {
                await UserProfileService.updateBasicProfile(
                  nickname: nickname,
                  region: '',
                  careerBucket: '',
                );
              } catch (_) {
                // 온보딩 중 실패해도 계속 진행
              }
              widget.controller.advance();
            },
          ),
    );
  }

  void _showWorkplacePopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.black.withOpacity(0.4),
      builder:
          (_) => OnboardingWorkplacePopup(
            onDone: (status, placeName) {
              Navigator.of(context).pop();
              widget.controller.advance();
            },
          ),
    );
  }

  /// 화면 터치 시 → 다음 step 진행
  void _onTap() {
    if (!widget.controller.canTouchAdvance) return;

    final step = widget.controller.current;

    // 마지막 step → 온보딩 완료
    if (step == AppOnboardingStepId.step9c) {
      _complete();
      return;
    }

    widget.controller.advance();
  }

  Future<void> _complete() async {
    await _fadeCtrl.reverse();
    await OnboardingService.completeOnboarding();
    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.controller.current;

    // 팝업 step은 오버레이를 투명하게 (팝업이 위에 표시됨)
    if (step == AppOnboardingStepId.step2 || step == AppOnboardingStepId.step4) {
      return const SizedBox.shrink();
    }

    // 1번 탭 step은 오버레이 완전 투명 (CaringPage가 캐릭터 위에 대사 표시)
    if (widget.controller.isTab0Step) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _onTap,
        child: const SizedBox.expand(),
      );
    }

    // spotlight steps
    if (step == AppOnboardingStepId.step5) {
      return _buildSpotlightOverlay(context, targetTabIdx: 3, hint: '아래 커리어 탭을 눌러볼까?');
    }
    if (step == AppOnboardingStepId.step5b) {
      return _buildSpotlightOverlay(context, targetTabIdx: 2, hint: '아래 성장하기 탭도 눌러볼까?');
    }
    if (step == AppOnboardingStepId.step8) {
      return _buildSpotlightOverlay(context, targetTabIdx: 0, hint: '아래 첫 번째 탭으로 가볼까?');
    }

    return _buildTextOverlay(context, step);
  }

  // ── 타탭 텍스트 오버레이: 앱 화면이 보이면서 상단에 말풍선만 표시 ──────
  Widget _buildTextOverlay(BuildContext context, AppOnboardingStepId step) {
    final dialogue = kStepDialogue[step];
    if (dialogue == null) {
      // 대사 없는 step은 터치만 감지
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _onTap,
        child: const SizedBox.expand(),
      );
    }

    final topPad = MediaQuery.of(context).padding.top + 8;

    return Stack(
      children: [
        // ── 화면 전체 터치 감지 (앱 화면은 그대로 보임) ──
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _onTap,
            child: const SizedBox.expand(),
          ),
        ),

        // ── 상단 말풍선 (앱 화면 위에 float) — 0.5초 페이드인 ──
        Positioned(
          top: topPad,
          left: 16,
          right: 16,
          child: FadeTransition(
            opacity: _fadeCtrl,
            child: _DialogueBubble(
              text: dialogue.replaceAll('{name}', _nickname ?? ''),
            ),
          ),
        ),
      ],
    );
  }

  // ── 핀조명(spotlight) 오버레이 — 지정 탭 강조 ──────────────
  // 탭바는 Scaffold body 밖이므로 탭 터치는 HomeShell._onTap에서 advance() 처리
  Widget _buildSpotlightOverlay(
    BuildContext context, {
    required int targetTabIdx,
    required String hint,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final bottomNavHeight = 56.0 + MediaQuery.of(context).padding.bottom;
    final tabW = screenSize.width / 4;
    final spotlightLeft = tabW * targetTabIdx;

    return Stack(
      children: [
        // 전체 어두운 배경 (타 탭 터치 차단, 지정 탭만 밝게)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: CustomPaint(
              painter: _SpotlightPainter(
                screenSize: screenSize,
                spotlightLeft: spotlightLeft,
                spotlightWidth: tabW,
                bottomNavHeight: bottomNavHeight,
              ),
            ),
          ),
        ),

        // 안내 대사 (탭바 바로 위) — 페이드인
        Positioned(
          bottom: bottomNavHeight + 16,
          left: 20,
          right: 20,
          child: FadeTransition(
            opacity: _fadeCtrl,
            child: IgnorePointer(
              child: _DialogueBubble(text: hint, showTouchHint: false),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 대사 말풍선 위젯
// ─────────────────────────────────────────────────────────────
class _DialogueBubble extends StatelessWidget {
  final String text;
  final bool showTouchHint;

  const _DialogueBubble({required this.text, this.showTouchHint = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: GoogleFonts.notoSansKr(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _kText,
              height: 1.6,
            ),
          ),
          if (showTouchHint) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '화면을 터치하면 다음으로 넘어가요',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 11,
                    color: _kText.withOpacity(0.4),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.touch_app_outlined, size: 13, color: _kText.withOpacity(0.35)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Spotlight CustomPainter — 커리어 탭 이외 어둡게
// ─────────────────────────────────────────────────────────────
class _SpotlightPainter extends CustomPainter {
  final Size screenSize;
  final double spotlightLeft;
  final double spotlightWidth;
  final double bottomNavHeight;

  _SpotlightPainter({
    required this.screenSize,
    required this.spotlightLeft,
    required this.spotlightWidth,
    required this.bottomNavHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.black.withOpacity(0.70);

    // 커리어 탭 영역을 제외한 나머지 전체를 어둡게 처리
    final path =
        Path()
          ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
          ..addRect(
            Rect.fromLTWH(
              spotlightLeft,
              size.height - bottomNavHeight,
              spotlightWidth,
              bottomNavHeight,
            ),
          )
          ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // 커리어 탭 주변에 밝은 테두리(glow)
    final glowPaint =
        Paint()
          ..color = AppColors.white.withOpacity(0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    canvas.drawRect(
      Rect.fromLTWH(
        spotlightLeft + 2,
        size.height - bottomNavHeight + 2,
        spotlightWidth - 4,
        bottomNavHeight - 4,
      ),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => false;
}

