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
  late Animation<double> _opacity;
  late Animation<Offset> _position;
  late Animation<double> _rotation;
  late Animation<double> _blur;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    if (widget.useWindEffect) {
      // 바람 효과: 투명도 + 이동 + 회전 + 블러
      _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _position = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(14, -6), // 오른쪽 위로 살짝
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
      _rotation = Tween<double>(begin: 0.0, end: 0.05).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      ); // 약 3도
      _blur = Tween<double>(begin: 0.0, end: 3.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
    } else {
      // 단순 페이드
      _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _position = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
          .animate(_controller);
      _rotation = Tween<double>(begin: 0.0, end: 0.0).animate(_controller);
      _blur = Tween<double>(begin: 0.0, end: 0.0).animate(_controller);
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
      // 사라질 때
      _controller.reverse();
    } else if (widget.text != null && widget.text != oldWidget.text) {
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

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: widget.useWindEffect && widget.isDismissing 
              ? _position.value 
              : Offset.zero,
          child: Transform.rotate(
            angle: widget.useWindEffect && widget.isDismissing 
                ? _rotation.value 
                : 0.0,
            child: Opacity(
              opacity: widget.isDismissing 
                  ? 1.0 - _opacity.value 
                  : _opacity.value,
              child: ImageFiltered(
                imageFilter: widget.useWindEffect && widget.isDismissing
                    ? ImageFilter.blur(
                        sigmaX: _blur.value,
                        sigmaY: _blur.value,
                      )
                    : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: child,
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
      ),
    );
  }
}

