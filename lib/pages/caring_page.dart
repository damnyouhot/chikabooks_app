import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';
import '../services/caring_state_service.dart';
import '../services/bond_score_service.dart';
import '../services/caring_action_service.dart';
import '../widgets/speech_overlay.dart';
import '../widgets/diary_input_sheet.dart';
import '../widgets/user_goal_sheet.dart';
import '../widgets/caring/jobs_info_card.dart';
import '../widgets/caring/salary_update_card.dart';
import '../widgets/caring/weekly_book_card.dart';
import '../widgets/caring/daily_quiz_card.dart';
import 'settings/settings_page.dart';

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
    // ✨ 앱 시작 시 하루 정산
    CaringActionService.dailySettle();
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

    final result = await CaringActionService.tryFeed();

    if (result.success) {
      // 성공: 멘트 + 결 팝업
      _speak(result.ment ?? '잘 먹었어.', durationMs: 2500);
      if (result.bondDelta > 0) {
        _showBondFloatingDelta(result.bondDelta);
      }
    } else {
      // 거절: 시간대 중복
      _speak(result.rejectMent ?? '지금은 방금 지나간 자리라서.', durationMs: 2200);
    }
  }

  /// ✨ 교감하기 (개선)
  void _onEmpathize() async {
    final result = await CaringActionService.tryTouch();

    _speak(result.ment, durationMs: 2500);
    if (result.bondDelta > 0) {
      _showBondFloatingDelta(result.bondDelta);
    }
  }

  /// ✨ 대화하기 (글쓰기 - 개선)
  void _onDiary() {
    DiaryInputSheet.show(context, (text) async {
      // 저장 완료 후 멘트 + 결
      final result = await CaringActionService.completeDiary();
      _speak(result.ment, durationMs: 2500);
      if (result.bondDelta > 0) {
        _showBondFloatingDelta(result.bondDelta);
      }
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

  /// ✨ 떠오르는 결 수치 표시 (+결 0.1, +결 0.05 등)
  void _showBondFloatingDelta(double value) {
    // 화면 크기 가져오기
    final size = MediaQuery.of(context).size;

    // 화면 중앙 상단 (캐릭터 머리 예상 위치)
    final centerX = size.width / 2 - 20; // 중앙에서 살짝 왼쪽
    final topY = size.height * 0.35; // 상단 35% 지점

    final deltaWidget = Positioned(
      key: ValueKey('delta_${DateTime.now().millisecondsSinceEpoch}'),
      left: centerX,
      top: topY,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 2400), // 1200ms → 2400ms (2배)
        tween: Tween(begin: 0.0, end: -40.0), // 위로 40 이동
        builder: (context, offset, child) {
          return Transform.translate(
            offset: Offset(0, offset),
            child: Opacity(
              opacity: 1.0 - (offset.abs() / 40.0),
              child: Text(
                '+결 ${value.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _colorAccent,
                  shadows: [
                    Shadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    setState(() => _floatingDeltas.add(deltaWidget));

    // 2.4초 후 제거 (1.2초 → 2.4초)
    Future.delayed(const Duration(milliseconds: 2400), () {
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
  static const _colorAccent = Color(0xFFF7CBCA); // 미술적 포인트
  static const _colorText = Color(0xFF5D6B6B); // 텍스트/메시지
  static const _colorBg = Color(0xFFF1F7F7); // 메인 배경
  static const _colorShadow1 = Color(0xFFDDD3D8); // 흐린 명암1
  static const _colorShadow2 = Color(0xFFD5E5E5); // 흐린 명암2

  Widget _buildMainContent() {
    return Stack(
      children: [
        // ── 0. 기존 배경 전체 유지 ──
        Positioned.fill(
          child: Container(
            color: _colorBg, // 기존 배경색
          ),
        ),

        // ── 1. dog.riv 캐릭터 영역 (배경 위에, 카드 아래) ──
        Positioned(
          top: MediaQuery.of(context).size.height * 0.35, // 상단 35% 공간 확보
          left: 0,
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: _onCircleTap,
            child:
                _dogArtboard != null
                    ? Rive(
                      artboard: _dogArtboard!,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    )
                    : Center(
                      child: CircularProgressIndicator(
                        color: _colorAccent,
                        strokeWidth: 1.5,
                      ),
                    ),
          ),
        ),

        // ── 2. 상단 정보 카드 영역 (고정, 스크롤 제거) ──
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.of(context).size.height * 0.35,
          child: Container(
            color: _colorBg.withOpacity(0.95), // 반투명 배경
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // 상단 바 (설정)
                  _buildTopBar(),
                  // 카드 영역 (스크롤 제거, Column으로 고정)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // ① 구인 카드
                        JobsInfoCard(
                          onTap: () {
                            // TODO: 4번째 탭(도전하기)으로 이동
                            debugPrint('구인 카드 탭');
                          },
                        ),
                        // ② 실무(급여 변경) 카드
                        const SalaryUpdateCard(),
                        // ③ 이주의 책 카드
                        WeeklyBookCard(
                          onPreview: () {
                            // TODO: 책 미리보기
                            debugPrint('1분 미리보기 탭');
                          },
                        ),
                        // ④ 퀴즈 카드
                        DailyQuizCard(
                          onStart: () {
                            // TODO: 퀴즈 풀기
                            debugPrint('바로 풀기 탭');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── 3. ✨ 말풍선 (4개 버튼 바로 위) ──
        Positioned(
          bottom: 100, // 버튼 영역(약 80px) + 여유(20px)
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // 좌측 설명 버튼
          IconButton(
            icon: Icon(
              Icons.info_outline,
              color: _colorText.withOpacity(0.5),
              size: 18,
            ),
            onPressed: () => _showConceptDialog(context),
          ),
          const Spacer(),
          // 우측 설정 버튼
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: _colorText.withOpacity(0.4),
              size: 20,
            ),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
            },
          ),
        ],
      ),
    );
  }

  /// 설명 다이얼로그
  void _showConceptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text(
              '나 탭에 대해서',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '나와 캐릭터가 머무는 공간',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _colorText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '이곳은 나를 방치하지 않기 위한 자리입니다.\n감정을 나누고, 하루를 정리하고,\n작은 목표를 세우는 공간입니다.',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '🐣 캐릭터',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '캐릭터는 당신의 감정을 비추는 존재입니다.\n조언보다 곁에 머무는 역할을 합니다.\n자주 올수록 조금씩 더 반응합니다.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: _colorText.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '🍚 밥먹기',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '시간대별로 캐릭터에게 밥을 줍니다.\n아침, 점심, 저녁, 밤 각 한 번씩 가능합니다.\n하루를 4번 다 채우면 다음 날 보너스가 있어요.\n건너뛴 날이 쌓이면 조금씩 멀어집니다.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: _colorText.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '💗 사랑하기',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '캐릭터에게 사랑을 주는 것은 터치면 충분합니다.\n하루 3번까지 가능합니다.\n상황에 따라 다른 반응을 보여줍니다.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: _colorText.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '📝 기록하기',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '오늘 있었던 일을 짧게 적습니다.\n길게 쓰지 않아도 괜찮습니다.\n하루에 두 번까지 기록할 수 있어요.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: _colorText.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '🎯 목표달성하기',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '이번 주 작은 다짐을 세우고 체크합니다.\n완수하지 못해도 감점은 없습니다.\n시도하는 것만으로도 의미가 있어요.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: _colorText.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '루틴 목표: 주 7일 동안 반복하는 작은 습관\n프로젝트 목표: 한 주 동안 달성할 구체적인 목표',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: _colorText.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '💛 결 점수',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '나를 방치하지 않은 시간의 축적입니다.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: _colorText.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '높을수록 좋은 게 아니라,\n꾸준히 돌보는 것이 중요합니다.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: _colorText.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
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
          _buildIconAction(Icons.restaurant_outlined, _onFeed), // 밥먹기
          _buildIconAction(Icons.volunteer_activism, _onEmpathize), // ✨ 소통하기
          _buildIconAction(
            Icons.edit_note_outlined,
            _onDiary,
          ), // ✨ 대화하기 (한 줄 기록)
          _buildIconAction(Icons.flag_outlined, _onGoalSetting), // ✨ 목표설정
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
