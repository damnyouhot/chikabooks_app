import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';

/// 인터랙티브 Rive 구체 위젯
/// 
/// Idle 상태에서 루프 → 터치 시 Burst 애니메이션 → Idle 복귀
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
  Artboard? _artboard;
  
  // State Machine 방식 (케이스 A)
  StateMachineController? _stateMachineController;
  SMITrigger? _tapTrigger;
  
  // Simple Animation 방식 (케이스 B)
  SimpleAnimation? _currentController;
  bool _isBursting = false;
  
  // 분석 결과에 따라 사용할 방식
  String _mode = 'unknown'; // 'stateMachine', 'twoAnimations', 'oneAnimation'

  @override
  void initState() {
    super.initState();
    _loadRive();
  }

  Future<void> _loadRive() async {
    try {
      final data = await rootBundle.load('assets/perrito.riv');
      final file = RiveFile.import(data);
      final artboard = file.mainArtboard.instance();

      // 분석: State Machine이 있는지 확인
      if (artboard.stateMachines.isNotEmpty) {
        _mode = 'stateMachine';
        _setupStateMachine(artboard);
      } else if (artboard.animations.length >= 2) {
        _mode = 'twoAnimations';
        _setupTwoAnimations(artboard);
      } else {
        _mode = 'oneAnimation';
        _setupOneAnimation(artboard);
      }

      setState(() => _artboard = artboard);
    } catch (e) {
      debugPrint('Rive 로드 실패: $e');
    }
  }

  /// 케이스 A: State Machine + Trigger
  void _setupStateMachine(Artboard artboard) {
    // 첫 번째 State Machine 사용
    final smName = artboard.stateMachines.first.name;
    _stateMachineController = StateMachineController.fromArtboard(
      artboard,
      smName,
    );

    if (_stateMachineController != null) {
      artboard.addController(_stateMachineController!);

      // Trigger Input 찾기 (일반적인 이름들 시도)
      for (final inputName in ['tap', 'burst', 'trigger', 'click']) {
        final input = _stateMachineController!.findInput<bool>(inputName);
        if (input is SMITrigger) {
          _tapTrigger = input;
          debugPrint('✅ Trigger found: $inputName');
          break;
        }
      }
    }
  }

  /// 케이스 B: 2개의 Animation (idle, burst)
  void _setupTwoAnimations(Artboard artboard) {
    // 첫 번째 애니메이션을 idle로 가정
    final idleName = artboard.animations.first.name;
    _currentController = SimpleAnimation(idleName);
    _currentController!.isActive = true;
    artboard.addController(_currentController!);
    debugPrint('✅ Idle animation: $idleName');
  }

  /// 케이스 C: 1개의 Animation (구간 제어)
  void _setupOneAnimation(Artboard artboard) {
    // 전체 애니메이션 루프
    final animName = artboard.animations.first.name;
    _currentController = SimpleAnimation(animName);
    _currentController!.isActive = true;
    artboard.addController(_currentController!);
    debugPrint('⚠️ Single animation mode: $animName');
  }

  void _onTap() {
    if (_artboard == null) return;

    switch (_mode) {
      case 'stateMachine':
        _tapTrigger?.fire();
        break;

      case 'twoAnimations':
        _playBurst();
        break;

      case 'oneAnimation':
        // 단순히 전체 애니메이션 재생
        debugPrint('Single animation tap (no burst separation)');
        break;
    }
  }

  /// 케이스 B: Burst 애니메이션 재생
  void _playBurst() async {
    if (_isBursting || _artboard == null) return;

    setState(() => _isBursting = true);

    // 기존 컨트롤러 제거
    _artboard!.removeController(_currentController!);
    _currentController?.dispose();

    // Burst 애니메이션 (두 번째 애니메이션으로 가정)
    final burstName = _artboard!.animations.length > 1
        ? _artboard!.animations[1].name
        : _artboard!.animations.first.name;
    
    final burstController = SimpleAnimation(burstName);
    burstController.isActive = true;
    _artboard!.addController(burstController);

    // Burst 애니메이션 길이만큼 대기 (기본 1.5초)
    const burstDuration = 1.5;
    await Future.delayed(Duration(milliseconds: (burstDuration * 1000).toInt()));

    if (mounted) {
      _artboard!.removeController(burstController);
      burstController.dispose();

      // Idle 복귀
      final idleName = _artboard!.animations.first.name;
      _currentController = SimpleAnimation(idleName);
      _currentController!.isActive = true;
      _artboard!.addController(_currentController!);

      setState(() => _isBursting = false);
    }
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
              color: const Color(0xFF6B4CE6).withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Rive 애니메이션
            if (_artboard != null)
              SizedBox(
                width: 200,
                height: 200,
                child: Rive(artboard: _artboard!),
              )
            else
              const CircularProgressIndicator(),

            // 텍스트 오버레이 (선택사항)
            // Positioned(
            //   bottom: 20,
            //   child: Column(
            //     children: [
            //       Text(
            //         widget.message,
            //         style: const TextStyle(
            //           fontSize: 16,
            //           fontWeight: FontWeight.w500,
            //           color: Colors.white,
            //         ),
            //       ),
            //       const SizedBox(height: 4),
            //       Text(
            //         '결 ${widget.bondScore}',
            //         style: TextStyle(
            //           fontSize: 12,
            //           color: Colors.white.withOpacity(0.8),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stateMachineController?.dispose();
    _currentController?.dispose();
    super.dispose();
  }
}

