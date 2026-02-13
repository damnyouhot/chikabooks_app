import 'package:flutter/material.dart';
import 'dart:ui';

/// 캐릭터 말풍선 - 말할 때만 페이드 인/아웃
/// 
/// 디자인 큐:
/// - 말 이벤트 발생 시에만 표시
/// - 페이드 인: 250ms
/// - 유지: 1800~2500ms (가변)
/// - 페이드 아웃: 250ms
/// - 사라질 때 "바람에 휘날림" 효과 (translate + rotate + blur + opacity)
class SpeechOverlay extends StatefulWidget {
  final String? text;
  final bool isDismissing;
  final bool useWindEffect;
  
  const SpeechOverlay({
    super.key,
    this.text,
    this.isDismissing = false,
    this.useWindEffect = true,
  });

  @override
  State<SpeechOverlay> createState() => _SpeechOverlayState();
}

class _SpeechOverlayState extends State<SpeechOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _fadeOut;
  late Animation<Offset> _windPosition;
  late Animation<double> _windRotation;
  late Animation<double> _windBlur;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // 페이드 인 애니메이션 (0.0 → 1.0)
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // 페이드 아웃 애니메이션 (1.0 → 0.0)
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    if (widget.useWindEffect) {
      // 바람 효과: 0에서 시작해서 움직임
      _windPosition = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(14, -6), // 오른쪽 위로 살짝
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
      
      _windRotation = Tween<double>(begin: 0.0, end: 0.05).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      ); // 약 3도
      
      _windBlur = Tween<double>(begin: 0.0, end: 3.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
    } else {
      _windPosition = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
          .animate(_controller);
      _windRotation = Tween<double>(begin: 0.0, end: 0.0).animate(_controller);
      _windBlur = Tween<double>(begin: 0.0, end: 0.0).animate(_controller);
    }

    // 나타날 때
    if (widget.text != null && widget.text!.isNotEmpty) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(SpeechOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isDismissing && !oldWidget.isDismissing) {
      // 사라질 때: forward로 진행 (바람 효과 적용)
      _controller.forward(from: 0.0);
    } else if (widget.text != null && widget.text != oldWidget.text && !widget.isDismissing) {
      // 새 텍스트 등장
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text == null || widget.text!.isEmpty) {
      return const SizedBox.shrink();
    }

    // 화면 너비의 2/3로 제한
    final maxWidth = MediaQuery.of(context).size.width * 2 / 3;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // 사라질 때와 나타날 때 구분
        final opacity = widget.isDismissing ? _fadeOut.value : _fadeIn.value;
        final offset = widget.isDismissing && widget.useWindEffect 
            ? _windPosition.value 
            : Offset.zero;
        final rotation = widget.isDismissing && widget.useWindEffect 
            ? _windRotation.value 
            : 0.0;
        final blur = widget.isDismissing && widget.useWindEffect 
            ? _windBlur.value 
            : 0.0;

        return Transform.translate(
          offset: offset,
          child: Transform.rotate(
            angle: rotation,
            child: Opacity(
              opacity: opacity,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: blur,
                  sigmaY: blur,
                ),
                child: Container(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: Text(
        widget.text!,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Color(0xFF5D6B6B), // 기존 팔레트 _colorText 사용
          letterSpacing: 0.3,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
        maxLines: null, // 자동 줄바꿈 허용
        softWrap: true, // 자연스러운 줄바꿈
      ),
    );
  }
}

