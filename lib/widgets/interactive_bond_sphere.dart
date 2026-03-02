import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

/// 인터랙티브 Rive 구체 위젯
///
/// Idle 상태에서 루프 → 터치 시 Burst 트리거 → Idle 복귀
class InteractiveBondSphere extends StatefulWidget {
  final String message;
  final int bondScore;

  const InteractiveBondSphere({
    super.key,
    this.message = '숨 한 번.',
    this.bondScore = 35,
  });

  @override
  State<InteractiveBondSphere> createState() => _InteractiveBondSphereState();
}

class _InteractiveBondSphereState extends State<InteractiveBondSphere> {
  File? _riveFile;
  RiveWidgetController? _controller;
  TriggerInput? _tapTrigger;

  @override
  void initState() {
    super.initState();
    _loadRive();
  }

  Future<void> _loadRive() async {
    try {
      final file = await File.asset(
        'assets/perrito.riv',
        riveFactory: Factory.rive,
      );
      if (file == null || !mounted) return;

      late RiveWidgetController controller;
      try {
        controller = RiveWidgetController(file);
        for (final name in ['tap', 'burst', 'trigger', 'click']) {
          final t = controller.stateMachine.trigger(name);
          if (t != null) {
            _tapTrigger = t;
            debugPrint('✅ Sphere trigger found: $name');
            break;
          }
        }
      } catch (_) {
        // 상태 머신이 없으면 기본 재생만 (트리거 없음)
        controller = RiveWidgetController(
          file,
          stateMachineSelector: StateMachineAtIndex(0),
        );
      }

      if (mounted) {
        setState(() {
          _riveFile = file;
          _controller = controller;
        });
      }
    } catch (e) {
      debugPrint('Rive 로드 실패: $e');
    }
  }

  void _onTap() {
    _tapTrigger?.fire();
  }

  @override
  void dispose() {
    _tapTrigger?.dispose();
    _controller?.dispose();
    _riveFile?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6B4CE6).withValues(alpha: 0.2),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
        ),
        child: SizedBox(
          width: 200,
          height: 200,
          child: _controller != null
              ? RiveWidget(
                  controller: _controller!,
                  fit: Fit.contain,
                )
              : const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
