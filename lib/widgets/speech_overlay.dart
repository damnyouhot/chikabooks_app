import 'package:flutter/material.dart';

/// 캐릭터 말풍선 - 말할 때만 페이드 인/아웃
/// 
/// 디자인 큐:
/// - 말 이벤트 발생 시에만 표시
/// - 페이드 인: 300ms
/// - 유지: 1800~2500ms (가변)
/// - 페이드 아웃: 300ms
class SpeechOverlay extends StatefulWidget {
  final String? text;
  final bool isDismissing;
  
  const SpeechOverlay({
    super.key,
    this.text,
    this.isDismissing = false,
  });

  @override
  State<SpeechOverlay> createState() => _SpeechOverlayState();
}

class _SpeechOverlayState extends State<SpeechOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // 단순 페이드 애니메이션 (0.0 ↔ 1.0)
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // 나타날 때
    if (widget.text != null && widget.text!.isNotEmpty) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(SpeechOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isDismissing && !oldWidget.isDismissing) {
      // 사라질 때: 페이드 아웃
      _controller.reverse();
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
        return Opacity(
          opacity: _opacity.value,
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
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

