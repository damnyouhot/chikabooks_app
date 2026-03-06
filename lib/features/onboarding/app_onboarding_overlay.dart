import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_onboarding_controller.dart';
import 'onboarding_popups.dart';
import '../../services/user_profile_service.dart';
import '../../services/onboarding_service.dart';

const _kText = Color(0xFF3D3535);

/// 대사 텍스트 맵
const Map<AppOnboardingStepId, String> kStepDialogue = {
  AppOnboardingStepId.step1a: '안녕 난 여기서 언제나 너와 함께할 저니라고 해.',
  AppOnboardingStepId.step1b: '넌 이름이 뭐야?',
  AppOnboardingStepId.step3:  '나는 멍멍 치과에서 1년차로 일하고 있어. 넌?',
  AppOnboardingStepId.step5:  '커리어 탭을 눌러봐!',
  AppOnboardingStepId.step6a: '여기서 너의 커리어를 관리할 수 있어. 겁먹지마 천천히 하나씩 해도 되고,',
  AppOnboardingStepId.step6b: '나중에 이력서를 사진찍어 올리면 AI가 자동으로 입력해줄거야.',
  AppOnboardingStepId.step6c: '그렇게 완성된 우리 이력서로 여기서 바로 치과에 지원할 수도 있어.',
  AppOnboardingStepId.step7a: '여기서 자기 계발도 할 수 있어',
  AppOnboardingStepId.step7b: '나랑 같이 퀴즈, 바뀌는 제도들, 책으로 공부 하면서 성장해 나가자!',
  AppOnboardingStepId.step8:  '이제 첫 번째 탭으로 가볼까?',
  AppOnboardingStepId.step9a: '난 항상 여기 있을건데 혹시 나 밥도 주고 관심도 줄 수 있어?',
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
      duration: const Duration(milliseconds: 350),
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

    // step5(spotlight)는 오버레이 자체가 탭 클릭 유도하므로 skip
    if (step == AppOnboardingStepId.step5) return;

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
      barrierColor: Colors.black.withOpacity(0.4),
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
      barrierColor: Colors.black.withOpacity(0.4),
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
      // 터치만 가로채서 advance 처리
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _onTap,
        child: const SizedBox.expand(),
      );
    }

    if (step == AppOnboardingStepId.step5) {
      return _buildSpotlightOverlay(context);
    }

    return _buildTextOverlay(context, step);
  }

  // ── 일반 텍스트 오버레이 ──────────────────────────────────
  Widget _buildTextOverlay(BuildContext context, AppOnboardingStepId step) {
    final dialogue = kStepDialogue[step];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: Stack(
        children: [
          // ── 반투명 배경 (타탭: 전체 어둡게) ── FadeTransition 제거, 즉시 표시
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.55),
            ),
          ),

          // ── 대사 버블 ──
          if (dialogue != null)
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: _DialogueBubble(
                  text: dialogue.replaceAll('{name}', _nickname ?? ''),
                  isTab0: false,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── 핀조명(spotlight) 오버레이 — 커리어 탭 강조 ──────────
  // 탭바는 Scaffold body 밖이므로 탭 터치는 HomeShell._onTap에서 처리
  // 오버레이는 배경 어둠 + 안내 대사만 담당
  Widget _buildSpotlightOverlay(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bottomNavHeight = 56.0 + MediaQuery.of(context).padding.bottom;

    final tabW = screenSize.width / 4;
    const careerTabIdx = 3;
    final careerTabLeft = tabW * careerTabIdx;

    return Stack(
      children: [
        // ── 전체 어두운 배경 + 커리어 탭 외 터치 차단 ──
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {}, // 커리어 탭 외 영역 터치 차단
            child: CustomPaint(
              painter: _SpotlightPainter(
                screenSize: screenSize,
                spotlightLeft: careerTabLeft,
                spotlightWidth: tabW,
                bottomNavHeight: bottomNavHeight,
              ),
            ),
          ),
        ),

        // ── 안내 대사 (탭바 바로 위) ──
        Positioned(
          bottom: bottomNavHeight + 16,
          left: 20,
          right: 20,
          child: IgnorePointer(
            child: _DialogueBubble(
              text: '커리어 탭을 눌러볼까?',
              isTab0: false,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 대사 말풍선 위젯 (타탭용 — 반투명 배경 위에 흰색 카드)
// ─────────────────────────────────────────────────────────────
class _DialogueBubble extends StatelessWidget {
  final String text;
  final bool isTab0; // 유지 (하위 호환) — 현재는 항상 false

  const _DialogueBubble({required this.text, this.isTab0 = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: GoogleFonts.notoSansKr(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _kText,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 10),
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
              Icon(
                Icons.touch_app_outlined,
                size: 13,
                color: _kText.withOpacity(0.35),
              ),
            ],
          ),
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
    final paint = Paint()..color = Colors.black.withOpacity(0.70);

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
          ..color = Colors.white.withOpacity(0.25)
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

