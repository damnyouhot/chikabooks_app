import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';
import '../services/caring_state_service.dart';
import '../services/user_action_service.dart';
import '../services/bond_score_service.dart';
import '../services/speech_engine_service.dart';
import '../services/weekly_goal_service.dart';
import '../models/weekly_goal.dart';
import '../data/goal_suggestions.dart';
import '../widgets/speech_overlay.dart';
import '../widgets/floating_delta.dart';
import '../widgets/diary_input_sheet.dart';

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
  bool _isSleeping = false;
  bool _hasGreetedToday = false;

  // ── ✨ 새로운 말풍선 시스템 ──
  String? _currentSpeech; // 현재 말풍선 텍스트
  bool _isDismissingSpeech = false; // 말풍선 사라지는 중

  // ── ✨ 떠오르는 수치들 ──
  final List<Widget> _floatingDeltas = [];
  final GlobalKey _characterKey = GlobalKey(); // 캐릭터 위치 추적용

  // ── 디밍 애니메이션 ──
  late AnimationController _dimController;
  late Animation<double> _dimAnimation;

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

    _dimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _dimAnimation = CurvedAnimation(
      parent: _dimController,
      curve: Curves.easeInOut,
    );

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
    _dimController.dispose();
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
        _isSleeping = state.isSleeping;
        _hasGreetedToday = greeted;
        _loading = false;
      });

      // 디밍 상태 반영
      if (_isSleeping) {
        _dimController.value = 1.0;
      }
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

    // 디밍 해제 (자고있었으면)
    if (_isSleeping) {
      _dimController.reverse();
    }

    setState(() {
      _isSleeping = false;
      _hasGreetedToday = true;
    });
    _speak(msg); // ✨ 변경: _showFeedback → _speak
  }

  /// 깨우기 (같은 날, 아침 인사 이미 완료)
  Future<void> _onWake() async {
    await CaringStateService.wake();
    if (!mounted) return;

    _dimController.reverse();
    setState(() => _isSleeping = false);
    _speak('좋은 아침.'); // ✨ 변경: _showFeedback → _speak
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
      final response = DiaryResponseService.getRandomResponse(text);
      _speak(response, durationMs: 2200);
    });
  }

  /// 재우기
  Future<void> _onSleep() async {
    await CaringStateService.sleep();
    if (!mounted) return;

    _dimController.forward();
    setState(() => _isSleeping = true);
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

          // ── 디밍 오버레이 (재우기 시) ──
          _buildDimOverlay(),
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

    // 인사 완료 → 목표 섹션 + 4 아이콘
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 목표 섹션
        _buildWeeklyGoalSection(),
        const SizedBox(height: 12),
        // 4 아이콘
        _buildFourActions(),
      ],
    );
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

  /// 4개 아이콘 버튼 (✨ 수정: 소통하기, 대화하기 추가)
  Widget _buildFourActions() {
    return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
          _buildIconAction(Icons.restaurant_outlined, _onFeed),              // 밥먹기
          _buildIconAction(Icons.volunteer_activism, _onEmpathize),         // ✨ 소통하기
          _buildIconAction(Icons.edit_note_outlined, _onDiary),             // ✨ 대화하기 (한 줄 기록)
          _buildIconAction(Icons.nights_stay_outlined, _onSleep),           // 잠자기
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

  // ═══════════════════════════════════════════════
  // 디밍 오버레이 (재우기 상태)
  // ═══════════════════════════════════════════════

  Widget _buildDimOverlay() {
    return AnimatedBuilder(
      animation: _dimAnimation,
      builder: (context, _) {
        if (_dimAnimation.value <= 0.01) {
          return const SizedBox.shrink();
        }

        return Container(
          color: Color.fromRGBO(40, 50, 50, 0.85 * _dimAnimation.value),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 캐릭터 위: 달 + 쉬고 있어요
                  Opacity(
                    opacity: _dimAnimation.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🌙', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 16),
                        const Text(
                          '쉬고 있어요.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                            color: Colors.white70,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 120),
                  
                  // 캐릭터 아래: 깨우기 버튼
                  Opacity(
                    opacity: _dimAnimation.value,
                    child: _buildWakeButton(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 깨우기/아침 인사 버튼 (디밍 위 표시)
  Widget _buildWakeButton() {
    final isNewDay = !_hasGreetedToday;
    final label = isNewDay ? '아침 인사' : '깨우기';
    final icon = isNewDay ? '👋' : '☀️';

    return GestureDetector(
      onTap: isNewDay ? _onGreeting : _onWake,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 0.5, // 가느다란 라인
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // 주간 목표 섹션 (bond_page에서 이동)
  // ═══════════════════════════════════════════════

  Widget _buildWeeklyGoalSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _colorShadow2.withOpacity(0.4),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _colorShadow1.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _buildWeeklyGoalMini(),
      ),
    );
  }

  Widget _buildWeeklyGoalMini() {
    return StreamBuilder<WeeklyGoals?>(
      stream: WeeklyGoalService.watchThisWeek(),
      builder: (context, snap) {
        final goals = snap.data?.goals ?? [];
        if (goals.isEmpty) {
          return Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '이번 주 목표를 설정해보세요',
                  style: TextStyle(
                    fontSize: 12,
                    color: _colorText.withOpacity(0.4),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showAddGoalDialog(),
                child: Text(
                  '+ 추가',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _colorAccent.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          children: goals.map((g) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      g.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF5D6B6B),
                      ),
                    ),
                  ),
                  Text(
                    '${g.progress}/${g.target}',
                    style: TextStyle(
                      fontSize: 11,
                      color: _colorText.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showAddGoalDialog() {
    final ctrl = TextEditingController();
    final suggestions = GoalSuggestions.getRandomThree();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '이번 주 목표 추가',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5D6B6B),
                  ),
                ),
                const SizedBox(height: 16),

                // 추천 3개
                const Text(
                  '💡 이런 건 어떠세요?',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5D6B6B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: suggestions.map((s) {
                    return ActionChip(
                      label: Text(
                        s.length > 30 ? '${s.substring(0, 30)}...' : s,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => ctrl.text = s,
                      backgroundColor: _colorAccent.withOpacity(0.2),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // 직접 입력
                TextField(
                  controller: ctrl,
                  maxLength: 50,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: '목표를 입력하세요',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _colorAccent, width: 2),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 저장 버튼
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final title = ctrl.text.trim();
                      if (title.isEmpty) return;
                      Navigator.pop(ctx);
                      final msg = await WeeklyGoalService.addGoal(title);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _colorAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '추가하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
