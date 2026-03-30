import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// 캐릭터 말풍선 — 배경 없는 텍스트 (페이드 인/아웃)
///
/// Stack 안에서 캐릭터 위에 겹쳐서 사용.
/// text=null 시 SizedBox.shrink() 반환 → 캐릭터 크기에 영향 없음.
/// isOnboarding=true 이면 온보딩 전용, false 이면 일반 — 기준 17/16pt의 85% 스케일
///
/// [onboardingBoldWord]가 텍스트에 포함되면 해당 구간만 볼드 처리 (온보딩 1a 등)
class SpeechOverlay extends StatefulWidget {
  final String? text;
  final bool isDismissing;
  final bool isOnboarding;

  /// 온보딩 말풍선에서 이 문자열이 등장하면 해당 부분만 굵게 (예: '저니')
  final String? onboardingBoldWord;

  const SpeechOverlay({
    super.key,
    this.text,
    this.isDismissing = false,
    this.isOnboarding = false,
    this.onboardingBoldWord,
  });

  @override
  State<SpeechOverlay> createState() => _SpeechOverlayState();
}

class _SpeechOverlayState extends State<SpeechOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  /// fade-out 중에도 이전 텍스트를 유지하기 위한 별도 상태
  String? _displayText;
  String? _displayBoldWord;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500), // 페이드인 0.5초
    );

    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.text != null && widget.text!.isNotEmpty) {
      _displayText = widget.text;
      _displayBoldWord = widget.onboardingBoldWord;
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(SpeechOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isDismissing && !oldWidget.isDismissing) {
      // 사라질 때: 즉시 제거 (애니메이션 없음)
      _controller.value = 0.0;
      if (mounted) {
        setState(() {
          _displayText = null;
          _displayBoldWord = null;
        });
      }
    } else if (widget.text != null &&
        widget.text!.isNotEmpty &&
        !widget.isDismissing) {
      final textChanged = widget.text != oldWidget.text;
      final boldChanged =
          widget.onboardingBoldWord != oldWidget.onboardingBoldWord;
      // `isDismissing` true였을 때 위 분기에서 _displayText를 비운 뒤,
      // 새 텍스트가 이전과 동일하면 textChanged가 false라 복구되지 않음 → 리액션 미표시.
      final needsResyncAfterDismiss =
          (_displayText == null || _displayText!.isEmpty);
      if (textChanged || boldChanged || needsResyncAfterDismiss) {
        setState(() {
          _displayText = widget.text;
          _displayBoldWord = widget.onboardingBoldWord;
        });
        if (textChanged || needsResyncAfterDismiss) {
          _controller.forward(from: 0.0);
        }
      }
    } else if ((widget.text == null || widget.text!.isEmpty) &&
        oldWidget.text != null &&
        oldWidget.text!.isNotEmpty) {
      // text가 null로 바뀜 → 즉시 제거
      _controller.value = 0.0;
      if (mounted) {
        setState(() {
          _displayText = null;
          _displayBoldWord = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TextStyle _baseStyle() {
    const baseOnboarding = 17.0;
    const baseNormal = 16.0;
    const scale = 0.85;
    return TextStyle(
      fontSize: (widget.isOnboarding ? baseOnboarding : baseNormal) * scale,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
      letterSpacing: 0.2 * scale,
      height: 1.5,
    );
  }

  /// 한 줄 높이 — 두 줄 분 `minHeight`·아래 정렬 기준
  double _lineHeight() {
    final s = _baseStyle();
    return s.fontSize! * (s.height ?? 1.0);
  }

  Widget _buildMessageText() {
    final t = _displayText!;
    final base = _baseStyle();
    final bold = _displayBoldWord;
    if (bold == null || bold.isEmpty || !t.contains(bold)) {
      return Text(
        t,
        style: base,
        textAlign: TextAlign.center,
        softWrap: true,
      );
    }

    final spans = <InlineSpan>[];
    var start = 0;
    while (true) {
      final i = t.indexOf(bold, start);
      if (i < 0) {
        spans.add(TextSpan(text: t.substring(start), style: base));
        break;
      }
      if (i > start) {
        spans.add(TextSpan(text: t.substring(start, i), style: base));
      }
      spans.add(
        TextSpan(
          text: bold,
          style: base.copyWith(fontWeight: FontWeight.w700),
        ),
      );
      start = i + bold.length;
    }
    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.center,
    );
  }

  @override
  Widget build(BuildContext context) {
    // _displayText 없으면 완전히 0크기 → Stack 내 캐릭터에 영향 없음
    if (_displayText == null || _displayText!.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxWidth = MediaQuery.of(context).size.width * 0.75;

    return FadeTransition(
      opacity: _opacity,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: 8 * 0.85,
          horizontal: 16 * 0.85,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              minHeight: 2 * _lineHeight(),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _buildMessageText(),
            ),
          ),
        ),
      ),
    );
  }
}
