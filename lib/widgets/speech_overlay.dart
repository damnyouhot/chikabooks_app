import 'package:flutter/material.dart';

/// 캐릭터 말풍선 — 배경 없는 텍스트 (페이드 인/아웃)
///
/// Stack 안에서 캐릭터 위에 겹쳐서 사용.
/// text=null 시 SizedBox.shrink() 반환 → 캐릭터 크기에 영향 없음.
class SpeechOverlay extends StatefulWidget {
  final String? text;
  final bool isDismissing;

  const SpeechOverlay({super.key, this.text, this.isDismissing = false});

  @override
  State<SpeechOverlay> createState() => _SpeechOverlayState();
}

class _SpeechOverlayState extends State<SpeechOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  /// fade-out 중에도 이전 텍스트를 유지하기 위한 별도 상태
  String? _displayText;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.text != null && widget.text!.isNotEmpty) {
      _displayText = widget.text;
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(SpeechOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isDismissing && !oldWidget.isDismissing) {
      // fade-out 완료 후 _displayText 제거 → SizedBox.shrink() 반환
      _controller.reverse().then((_) {
        if (mounted) setState(() => _displayText = null);
      });
    } else if (widget.text != null &&
        widget.text!.isNotEmpty &&
        widget.text != oldWidget.text &&
        !widget.isDismissing) {
      // 새 텍스트 → 즉시 교체 후 fade-in
      setState(() => _displayText = widget.text);
      _controller.forward(from: 0.0);
    } else if ((widget.text == null || widget.text!.isEmpty) &&
        oldWidget.text != null &&
        oldWidget.text!.isNotEmpty) {
      // text가 null로 바뀜 → fade-out 후 제거
      _controller.reverse().then((_) {
        if (mounted) setState(() => _displayText = null);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Text(
              _displayText!,
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
        ),
      ),
    );
  }
}
