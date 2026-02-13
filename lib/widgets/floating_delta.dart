import 'package:flutter/material.dart';

/// 캐릭터 위로 떠오르는 수치 표시 (+1, +3 등)
/// 
/// 디자인 큐:
/// - 캐릭터 머리 위 20~40px 지점에서 시작
/// - 0.9~1.2초 동안 위로 18px 정도 떠오름
/// - opacity: 0.0 → 0.5 → 0.0 (처음부터 끝까지 흐릿하게)
/// - 애니메이션 완료 후 자동 제거
class FloatingDelta extends StatefulWidget {
  final int value;
  final Offset startPosition;
  
  const FloatingDelta({
    super.key,
    required this.value,
    required this.startPosition,
  });

  @override
  State<FloatingDelta> createState() => _FloatingDeltaState();
}

class _FloatingDeltaState extends State<FloatingDelta>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _offsetY;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // 위로 떠오름
    _offsetY = Tween<double>(begin: 0.0, end: -18.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // 흐릿하게 등장했다 사라짐 (peak opacity = 0.5)
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.5)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween(0.5),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.5, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: widget.startPosition.dx,
          top: widget.startPosition.dy + _offsetY.value,
          child: Opacity(
            opacity: _opacity.value,
            child: Text(
              '+${widget.value}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF7BA5A5), // 기존 팔레트 _colorAccent 사용
                shadows: [
                  Shadow(
                    color: Colors.white60,
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

