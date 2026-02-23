import 'package:flutter/material.dart';

/// 캐릭터 말풍선 — 배경 없는 텍스트 (페이드+슬라이드 인/아웃)
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
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.text != null && widget.text!.isNotEmpty) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(SpeechOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isDismissing && !oldWidget.isDismissing) {
      _controller.reverse();
    } else if (widget.text != null &&
        widget.text != oldWidget.text &&
        !widget.isDismissing) {
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

    final maxWidth = MediaQuery.of(context).size.width * 0.65;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: SlideTransition(position: _slide, child: child),
        );
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Text(
          widget.text!,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Color(0xFF5D6B6B),
            letterSpacing: 0.2,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
          softWrap: true,
        ),
      ),
    );
  }
}
