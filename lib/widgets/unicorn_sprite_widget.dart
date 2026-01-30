import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/unicorn.dart';

/// 유니콘 동작 타입
enum UnicornAction {
  idle1,   // 기본 대기 1
  idle2,   // 기본 대기 2 (긴 버전)
  eating,  // 밥 먹기
  happy,   // 행복
  jump,    // 점프
  no,      // 거부 (포만감 100일 때)
}

/// 동작별 애니메이션 정보
class ActionInfo {
  final String folder;
  final String prefix;
  final int startFrame;
  final int frameCount;
  final bool pingPong;  // 핑퐁 여부

  const ActionInfo({
    required this.folder,
    required this.prefix,
    required this.startFrame,
    required this.frameCount,
    this.pingPong = false,
  });
}

/// 유니콘 스프라이트 애니메이션 위젯
class UnicornSpriteWidget extends StatefulWidget {
  final Unicorn? unicorn;
  final double size;
  final int fps;
  final VoidCallback? onTap;
  final bool showDialogue;

  const UnicornSpriteWidget({
    super.key,
    this.unicorn,
    this.size = 200,
    this.fps = 12,
    this.onTap,
    this.showDialogue = true,
  });

  @override
  State<UnicornSpriteWidget> createState() => UnicornSpriteWidgetState();
}

class UnicornSpriteWidgetState extends State<UnicornSpriteWidget> {
  
  // 동작별 정보 매핑
  static const Map<UnicornAction, ActionInfo> _actionInfoMap = {
    UnicornAction.idle1: ActionInfo(
      folder: 'idle1',
      prefix: '028',
      startFrame: 1,
      frameCount: 24,
      pingPong: true,
    ),
    UnicornAction.idle2: ActionInfo(
      folder: 'idle2',
      prefix: '030',
      startFrame: 31,
      frameCount: 139,
      pingPong: false,
    ),
    UnicornAction.eating: ActionInfo(
      folder: 'eating',
      prefix: '044',
      startFrame: 541,
      frameCount: 20,
      pingPong: false,
    ),
    UnicornAction.happy: ActionInfo(
      folder: 'happy',
      prefix: '050',
      startFrame: 401,
      frameCount: 30,
      pingPong: false,
    ),
    UnicornAction.jump: ActionInfo(
      folder: 'jump',
      prefix: '048',
      startFrame: 651,
      frameCount: 15,
      pingPong: false,
    ),
    UnicornAction.no: ActionInfo(
      folder: 'no',
      prefix: '041',
      startFrame: 440,
      frameCount: 31,
      pingPong: false,
    ),
  };

  // 현재 상태
  UnicornAction _currentAction = UnicornAction.idle1;
  int _currentFrame = 0;
  bool _isReversing = false;
  int _idle1RepeatCount = 0;  // idle1 반복 횟수 추적
  bool _lastTouchWasHappy = false;  // 마지막 터치가 happy였는지 (번갈아 재생용)
  
  Timer? _animationTimer;
  String? _currentDialogue;
  Timer? _dialogueTimer;

  // 기본 대화 목록
  static const List<String> _idleDialogues = [
    '오늘 하루도 화이팅! ✨',
    '뭐 하고 있어요?',
    '저랑 같이 놀아요~',
    '오늘 기분이 어때요?',
    '힘내요! 응원할게요 💪',
    '잠깐 쉬어가도 괜찮아요~',
    '제가 옆에 있을게요 🦄',
    '오늘도 수고했어요!',
  ];

  // 조언 목록
  static const List<String> _adviceDialogues = [
    '물 한 잔 마셔요! 💧',
    '잠깐 스트레칭 어때요?',
    '눈 좀 쉬게 해주세요 👀',
    '깊게 숨 한번 쉬어봐요~',
    '오늘 점심은 드셨어요?',
    '자세 바르게! 허리 펴세요~',
    '작은 목표부터 시작해봐요!',
  ];

  @override
  void initState() {
    super.initState();
    _startIdleAnimation();
    _startRandomDialogue();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 주요 동작 이미지 프리캐싱 (깜빡임 방지)
    _precacheActionImages(UnicornAction.idle1);
    _precacheActionImages(UnicornAction.jump);
    _precacheActionImages(UnicornAction.happy);
  }

  /// 동작별 이미지 미리 로드
  void _precacheActionImages(UnicornAction action) {
    final actionInfo = _actionInfoMap[action]!;
    for (int i = 0; i < actionInfo.frameCount; i++) {
      final frameNumber = (actionInfo.startFrame + i).toString().padLeft(4, '0');
      final imagePath = 'assets/characters/unicorn1/${actionInfo.folder}/Image Sequence_${actionInfo.prefix}_$frameNumber.png';
      precacheImage(AssetImage(imagePath), context);
    }
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _dialogueTimer?.cancel();
    super.dispose();
  }

  /// 기본 Idle 애니메이션 시작 (idle1 3회 → idle2 1회 → 반복)
  void _startIdleAnimation() {
    _currentAction = UnicornAction.idle1;
    _currentFrame = 0;
    _isReversing = false;
    _idle1RepeatCount = 0;
    _startAnimationLoop();
  }

  void _startAnimationLoop() {
    _animationTimer?.cancel();
    final frameDuration = Duration(milliseconds: (1000 / widget.fps).round());
    
    _animationTimer = Timer.periodic(frameDuration, (_) {
      if (!mounted) return;
      
      final actionInfo = _actionInfoMap[_currentAction]!;
      
      setState(() {
        if (actionInfo.pingPong) {
          // 핑퐁 방식 (idle1)
          if (_isReversing) {
            _currentFrame--;
            if (_currentFrame <= 0) {
              _currentFrame = 0;
              _isReversing = false;
              _idle1RepeatCount++;
              
              // idle1이 3회 반복되면 idle2로 전환
              if (_currentAction == UnicornAction.idle1 && _idle1RepeatCount >= 3) {
                _switchToIdle2();
              }
            }
          } else {
            _currentFrame++;
            if (_currentFrame >= actionInfo.frameCount - 1) {
              _currentFrame = actionInfo.frameCount - 1;
              _isReversing = true;
            }
          }
        } else if (_currentAction == UnicornAction.idle2) {
          // idle2 재생
          if (_currentFrame < actionInfo.frameCount - 1) {
            _currentFrame++;
          } else {
            // idle2 완료 → idle1로 돌아감
            _currentAction = UnicornAction.idle1;
            _currentFrame = 0;
            _isReversing = false;
            _idle1RepeatCount = 0;
          }
        }
        // eating, happy, jump, no는 _playActionAnimation()에서 처리
      });
    });
  }

  /// idle2로 전환
  void _switchToIdle2() {
    _currentAction = UnicornAction.idle2;
    _currentFrame = 0;
    _isReversing = false;
  }

  /// 외부에서 호출: 밥 먹기 동작
  void playEating() {
    _animationTimer?.cancel();
    final actionInfo = _actionInfoMap[UnicornAction.eating]!;
    debugPrint('🦄 Starting: eating animation (frames: ${actionInfo.frameCount})');
    setState(() {
      _currentAction = UnicornAction.eating;
      _currentFrame = 0;
      _isReversing = false;
    });
    _playActionAnimation(UnicornAction.eating, actionInfo);
  }

  /// 외부에서 호출: 거부 동작 (포만감 100일 때)
  void playNo() {
    _animationTimer?.cancel();
    final actionInfo = _actionInfoMap[UnicornAction.no]!;
    debugPrint('🦄 Starting: no animation (frames: ${actionInfo.frameCount})');
    setState(() {
      _currentAction = UnicornAction.no;
      _currentFrame = 0;
      _isReversing = false;
    });
    _playActionAnimation(UnicornAction.no, actionInfo);
  }

  /// 외부에서 호출: 터치 반응 (happy/jump 번갈아 재생)
  void playTouchReaction() {
    _animationTimer?.cancel();
    
    // 첫 터치: happy, 두 번째 터치: jump, 번갈아 재생
    final nextAction = _lastTouchWasHappy ? UnicornAction.jump : UnicornAction.happy;
    final actionInfo = _actionInfoMap[nextAction]!;
    
    debugPrint('🦄 Starting: ${nextAction.name} animation (frames: ${actionInfo.frameCount})');
    
    setState(() {
      _currentAction = nextAction;
      _currentFrame = 0;
      _isReversing = false;
      _lastTouchWasHappy = !_lastTouchWasHappy;
    });
    
    // 전용 타이머로 애니메이션 재생 (idle 로직과 분리)
    _playActionAnimation(nextAction, actionInfo);
  }
  
  /// 특정 액션 애니메이션 재생 (idle과 분리된 전용 로직)
  void _playActionAnimation(UnicornAction action, ActionInfo actionInfo) {
    _animationTimer?.cancel();
    final frameDuration = Duration(milliseconds: (1000 / widget.fps).round());
    int frame = 0;
    
    _animationTimer = Timer.periodic(frameDuration, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      // 도중에 다른 액션으로 바뀌면 중단
      if (_currentAction != action) {
        debugPrint('🦄 Action changed during animation, stopping');
        timer.cancel();
        return;
      }
      
      frame++;
      if (frame >= actionInfo.frameCount) {
        // 애니메이션 완료
        debugPrint('🦄 ${action.name} animation complete');
        timer.cancel();
        _startIdleAnimation();
      } else {
        setState(() {
          _currentFrame = frame;
        });
      }
    });
  }

  void _startRandomDialogue() {
    _scheduleNextDialogue();
  }

  void _scheduleNextDialogue() {
    final random = Random();
    final delay = Duration(seconds: 15 + random.nextInt(16));
    
    _dialogueTimer?.cancel();
    _dialogueTimer = Timer(delay, () {
      if (mounted) {
        _showRandomDialogue();
        _scheduleNextDialogue();
      }
    });
  }

  void _showRandomDialogue() {
    final random = Random();
    final allDialogues = [..._idleDialogues, ..._adviceDialogues];
    
    setState(() {
      _currentDialogue = allDialogues[random.nextInt(allDialogues.length)];
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _currentDialogue = null;
        });
      }
    });
  }

  void _onTap() {
    // 터치 반응 동작 (jump/happy 번갈아) - 바운스 효과 제거하고 애니메이션만
    playTouchReaction();
    
    // 대화 표시
    _showRandomDialogue();
    
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final actionInfo = _actionInfoMap[_currentAction]!;
    final frameNumber = (actionInfo.startFrame + _currentFrame).toString().padLeft(4, '0');
    final imagePath = 'assets/characters/unicorn1/${actionInfo.folder}/Image Sequence_${actionInfo.prefix}_$frameNumber.png';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 대화 말풍선
        if (widget.showDialogue && _currentDialogue != null)
          _buildDialogueBubble(),
        
        // 유니콘 스프라이트 (gaplessPlayback으로 깜빡임 방지)
        GestureDetector(
          onTap: _onTap,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
              gaplessPlayback: true,  // 이전 이미지 유지 (깜빡임 방지)
              errorBuilder: (context, error, stackTrace) {
                debugPrint('이미지 로드 실패: $imagePath');
                return Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.pets, size: 60, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogueBubble() {
    return AnimatedOpacity(
      opacity: _currentDialogue != null ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          _currentDialogue ?? '',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
