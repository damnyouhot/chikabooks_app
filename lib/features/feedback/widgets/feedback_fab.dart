import 'package:flutter/material.dart';
import '../feedback_list_page.dart';

/// 피드백 플로팅 버튼
///
/// HomeShell의 Stack 최상단에 위치.
/// 탭 이름(sourceScreenLabel)과 현재 route를 자동으로 목록 화면에 전달.
/// 목록 → 작성 → 등록 → 목록 흐름으로 연결됨.
class FeedbackFab extends StatefulWidget {
  final String sourceScreenLabel;
  final String sourceRoute;

  const FeedbackFab({
    super.key,
    required this.sourceScreenLabel,
    required this.sourceRoute,
  });

  @override
  State<FeedbackFab> createState() => _FeedbackFabState();
}

class _FeedbackFabState extends State<FeedbackFab>
    with SingleTickerProviderStateMixin {
  static const double _fabSize = 52;
  static const double _edgeMargin = 16;

  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  Offset? _position;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    // 진입 시 팝 애니메이션
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _open() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => FeedbackListPage(
              sourceScreenLabel: widget.sourceScreenLabel,
              sourceRoute: widget.sourceRoute,
            ),
      ),
    );
  }

  Offset _defaultPosition(BoxConstraints constraints, double bottom) {
    return Offset(
      constraints.maxWidth - _fabSize - _edgeMargin,
      constraints.maxHeight - bottom - _fabSize,
    );
  }

  Offset _clampPosition(
    BuildContext context,
    BoxConstraints constraints,
    Offset position,
    double bottom,
  ) {
    final topPadding = MediaQuery.of(context).padding.top;
    final maxX = constraints.maxWidth - _fabSize - _edgeMargin;
    final maxY = constraints.maxHeight - bottom - _fabSize;

    return Offset(
      position.dx.clamp(_edgeMargin, maxX),
      position.dy.clamp(topPadding + _edgeMargin, maxY),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom =
        MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 16;

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final position = _clampPosition(
            context,
            constraints,
            _position ?? _defaultPosition(constraints, bottom),
            bottom,
          );

          return Stack(
            children: [
              Positioned(
                left: position.dx,
                top: position.dy,
                child: ScaleTransition(
                  scale: _scale,
                  child: GestureDetector(
                    onTap: _open,
                    onPanUpdate: (details) {
                      setState(() {
                        _position = _clampPosition(
                          context,
                          constraints,
                          position + details.delta,
                          bottom,
                        );
                      });
                    },
                    child: Container(
                      width: _fabSize,
                      height: _fabSize,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF2E7D32,
                            ).withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.feedback_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
