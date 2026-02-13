import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';
import '../services/caring_state_service.dart';
import '../services/user_action_service.dart';
import '../services/bond_score_service.dart';
import '../services/speech_engine_service.dart';
import '../widgets/speech_overlay.dart';
import '../widgets/floating_delta.dart';
import '../widgets/diary_input_sheet.dart';
import '../widgets/user_goal_sheet.dart';

/// 돌보기(1탭) — 아침 인사 리추얼 + 4 아이콘 + 재우기/깨우기
///
/// 상태 흐름:
///   새 날짜 + 자고있음 → 디밍 + [아침 인사] → 깨우기+인사+출석 → 4버튼
///   새 날짜 + 깨어있음 → [아침 인사] 버튼만 → 인사+출석 → 4버튼
///   같은 날 + 자고있음 → 디밍 + [깨우기] → 깨우기 → 4버튼
///   같은 날 + 인사완료 → 4버튼 정상
class CaringPage extends StatefulWidget {
  /// 성장(3탭)으로 이동하기 위한 콜백
  final VoidCallback? onNavigateToGrowth;

  const CaringPage({super.key, this.onNavigateToGrowth});

  @override
  State<CaringPage> createState() => _CaringPageState();
}

class _CaringPageState extends State<CaringPage>
    with SingleTickerProviderStateMixin {
  // ── 상태 ──
  bool _loading = true;
  bool _hasGreetedToday = false;

  // ── ✨ 새로운 말풍선 시스템 ──
  String? _currentSpeech; // 현재 말풍선 텍스트
  bool _isDismissingSpeech = false; // 말풍선 사라지는 중

  // ── ✨ 떠오르는 수치들 ──
  final List<Widget> _floatingDeltas = [];
  final GlobalKey _characterKey = GlobalKey(); // 캐릭터 위치 추적용

  // ── Rive 관련 ──
  Artboard? _dogArtboard;
  StateMachineController? _dogStateMachine;
  SMITrigger? _tapTrigger;

  // ── 정서 문장 풀 (죄책감 유발 멘트 금지) ──
  static const List<String> _neutralPhrases = [
    '오늘도 여기.',
    '천천히 해도 괜찮아.',
    '숨 한 번.',
    '있는 그대로.',
    '조용한 하루도 괜찮아.',
    '여기 있어도 돼.',
    '오늘은 오늘만큼.',
    '작은 것도 충분해.',
  ];

  @override
  void initState() {
    super.initState();
    _loadRiveFile();
    _loadState();
  }

  /// Rive 파일 로드 및 State Machine 연결
  Future<void> _loadRiveFile() async {
    try {
      final data = await rootBundle.load('assets/dog.riv');
      final file = RiveFile.import(data);
      final artboard = file.mainArtboard.instance();

      // State Machine 연결 (트리거 확인)
      final controller = StateMachineController.fromArtboard(
        artboard,
        'State Machine 1', // dog.riv의 State Machine 이름
      );

      if (controller != null) {
        artboard.addController(controller);
        _dogStateMachine = controller;

        // 'tap' 트리거 찾기
        _tapTrigger = controller.findInput<bool>('tap') as SMITrigger?;
        
        if (_tapTrigger != null) {
          debugPrint('✅ dog.riv tap 트리거 연결 성공');
        } else {
          debugPrint('⚠️ tap 트리거를 찾을 수 없습니다');
        }
      }

      if (mounted) {
        setState(() => _dogArtboard = artboard);
      }
    } catch (e) {
      debugPrint('❌ dog.riv 로드 실패: $e');
    }
  }

  @override
  void dispose() {
    _dogStateMachine?.dispose();
    super.dispose();
  }

  /// Firestore에서 상태 로드
  Future<void> _loadState() async {
    try {
      final state = await CaringStateService.loadState();
      await BondScoreService.applyCenterGravity();

      if (!mounted) return;

      final greeted = CaringStateService.hasGreetedToday(state);

        setState(() {
        _hasGreetedToday = greeted;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ═══════════════════════════════════════════════
  // 핸들러
  // ═══════════════════════════════════════════════

  /// 아침 인사 (출석 통합 + 깨우기 통합)
  Future<void> _onGreeting() async {
    final msg = await CaringStateService.completeGreeting();
    if (!mounted) return;

    setState(() {
      _hasGreetedToday = true;
    });
    _speak(msg); // ✨ 변경: _showFeedback → _speak
    }

  /// 밥주기
  void _onFeed() async {
    _tapTrigger?.fire(); // 🔥 Rive 트리거 발동
    final msg = await UserActionService.feed();
    if (mounted) {
      _speak(msg); // ✨ 변경: _showFeedback → _speak
      _showFloatingDelta(1); // ✨ 추가: 결 수치 상승 표시
    }
  }

  /// ✨ 소통하기 (기존 _onTalk 대체) - 유저 상태 기반 공감 멘트
  void _onEmpathize() async {
    final speech = await SpeechEngineService.pickSpeechForUser();
    _speak(speech, durationMs: 2500);
  }

  /// ✨ 대화하기 (새로운 기능) - 한 줄 기록 팝업
  void _onDiary() {
    DiaryInputSheet.show(context, (text) {
      // 저장 완료 후 캐릭터 응답
      _speak('들었어.', durationMs: 2200);
    });
  }

  /// ✨ 목표설정 (새로운 기능) - 목표 관리 팝업
  void _onGoalSetting() {
    UserGoalSheet.show(context);
  }

  /// 오라 원 탭
  void _onCircleTap() {
    _tapTrigger?.fire(); // 🔥 Rive 트리거 발동
    _speak(
      _neutralPhrases[Random().nextInt(_neutralPhrases.length)],
    ); // ✨ 변경: _showFeedback → _speak
    }

  // ═══════════════════════════════════════════════
  // ✨ 새로운 말풍선 시스템
  // ═══════════════════════════════════════════════

  /// 말하기 - 말풍선을 일정 시간 동안 표시
  void _speak(String text, {int durationMs = 2000}) {
    setState(() {
      _currentSpeech = text;
      _isDismissingSpeech = false;
    });

    // 일정 시간 후 사라지기 시작
    Future.delayed(Duration(milliseconds: durationMs), () {
      if (mounted && _currentSpeech == text) {
        setState(() => _isDismissingSpeech = true);
        
        // 바람 효과 애니메이션 후 완전 제거
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _currentSpeech = null;
              _isDismissingSpeech = false;
            });
          }
        });
      }
    });
  }

  /// 떠오르는 수치 표시 (+1, +3 등)
  void _showFloatingDelta(int value) {
    // 화면 크기 가져오기
    final size = MediaQuery.of(context).size;
    
    // 화면 중앙 상단 (캐릭터 머리 예상 위치)
    final centerX = size.width / 2 - 10; // 중앙에서 살짝 왼쪽
    final topY = size.height * 0.35; // 상단 35% 지점

    final deltaWidget = FloatingDelta(
      key: ValueKey('delta_${DateTime.now().millisecondsSinceEpoch}'),
      value: value,
      startPosition: Offset(centerX, topY),
    );

    setState(() => _floatingDeltas.add(deltaWidget));

    // 1초 후 제거
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) {
        setState(() => _floatingDeltas.remove(deltaWidget));
      }
    });
  }

  // ═══════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F7F7), // 메인 배경
      body: Stack(
        children: [
          // ── 메인 콘텐츠 (dog.riv 전체화면 + 버튼들) ──
          _buildMainContent(),
        ],
      ),
    );
  }

  // ── 디자인 컬러 팔레트 ──
  static const _colorAccent = Color(0xFFF7CBCA);    // 미술적 포인트
  static const _colorText = Color(0xFF5D6B6B);       // 텍스트/메시지
  static const _colorBg = Color(0xFFF1F7F7);         // 메인 배경
  static const _colorShadow1 = Color(0xFFDDD3D8);    // 흐린 명암1
  static const _colorShadow2 = Color(0xFFD5E5E5);    // 흐린 명암2

  Widget _buildMainContent() {
    return Stack(
      children: [
        // ── 1. dog.riv 전체 화면 (캐릭터 영역) ──
        Positioned.fill(
          key: _characterKey, // ✨ 추가: 위치 추적용
          child: GestureDetector(
            onTap: _onCircleTap,
            child: _dogArtboard != null
                ? Rive(
                    artboard: _dogArtboard!,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  )
                : Container(
                    color: _colorBg,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: _colorAccent,
                        strokeWidth: 1.5, // 가느다란 라인
                      ),
                    ),
          ),
        ),
        ),

        // ── 2. 상단 바 (설정) ──
        Positioned(
          top: 0,
          left: 0,
          right: 0,
        child: SafeArea(
            bottom: false,
            child: _buildTopBar(),
          ),
        ),

        // ── 3. ✨ 캐릭터 아래 말풍선 (말할 때만 표시) ──
        Positioned(
          bottom: 140,
          left: 0,
          right: 0,
          child: Center(
            child: SpeechOverlay(
              text: _currentSpeech,
              isDismissing: _isDismissingSpeech,
            ),
          ),
        ),

        // ── 3-1. ✨ 떠오르는 수치들 ──
        ..._floatingDeltas,

        // ── 4. 하단 버튼들 ──
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: _buildBottomSection(),
            ),
          ),
        ),
      ],
    );
  }

  /// 상단 바
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
              children: [
          IconButton(
            icon: Icon(Icons.settings_outlined,
                color: _colorText.withOpacity(0.4), size: 20),
            onPressed: () {
              // 설정 화면은 기존 유지 (프로필 등)
            },
                ),
              ],
            ),
    );
  }

  /// 하단 섹션: (목표 섹션) + 아침 인사 or 4 아이콘
  Widget _buildBottomSection() {
    // 아직 오늘 인사 안 했으면 → 아침 인사 버튼만
    if (!_hasGreetedToday) {
      return _buildGreetingButton();
    }

    // 인사 완료 → 4 아이콘만
    return _buildFourActions();
  }

  /// 아침 인사 버튼 (단독)
  Widget _buildGreetingButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60),
      child: GestureDetector(
        onTap: _onGreeting,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _colorShadow2.withOpacity(0.4),
              width: 0.5, // 가느다란 라인
            ),
            boxShadow: [
                    BoxShadow(
                color: _colorShadow1.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 4),
                    ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('👋', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text(
                '아침 인사',
            style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _colorText,
                ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  /// 4개 아이콘 버튼 (✨ 수정: 소통하기, 대화하기, 목표설정 추가)
  Widget _buildFourActions() {
    return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
          _buildIconAction(Icons.restaurant_outlined, _onFeed),              // 밥먹기
          _buildIconAction(Icons.volunteer_activism, _onEmpathize),         // ✨ 소통하기
          _buildIconAction(Icons.edit_note_outlined, _onDiary),             // ✨ 대화하기 (한 줄 기록)
          _buildIconAction(Icons.flag_outlined, _onGoalSetting),            // ✨ 목표설정
            ],
          ),
    );
  }

  /// 아이콘 전용 버튼 (가느다란 라인 + 팔레트 적용)
  Widget _buildIconAction(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
              shape: BoxShape.circle,
          border: Border.all(
            color: _colorShadow2.withOpacity(0.5),
            width: 0.5, // 가느다란 라인
          ),
          boxShadow: [
            BoxShadow(
              color: _colorShadow1.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
            ),
        child: Icon(icon, color: _colorText.withOpacity(0.6), size: 22),
      ),
    );
  }
}
