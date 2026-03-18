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
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

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
        builder: (_) => FeedbackListPage(
          sourceScreenLabel: widget.sourceScreenLabel,
          sourceRoute: widget.sourceRoute,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom +
        kBottomNavigationBarHeight +
        16;

    return Positioned(
      right: 16,
      bottom: bottom,
      child: ScaleTransition(
        scale: _scale,
        child: GestureDetector(
          onTap: _open,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withOpacity(0.4),
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
    );
  }
}
