import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart' hide Animation;
import '../services/caring_state_service.dart';
import '../services/bond_score_service.dart';
import '../services/caring_action_service.dart';
import '../services/base_message_service.dart';
import '../services/job_service.dart';
import '../services/ebook_service.dart';
import '../data/base_message_data.dart';
import '../models/ebook.dart';
import '../widgets/speech_overlay.dart';
import '../widgets/diary_input_sheet.dart';
import '../widgets/user_goal_sheet.dart';
import '../pages/ebook/ebook_detail_page.dart';
import 'settings/settings_page.dart';
import '../core/theme/app_colors.dart';


/// 기본 메시지 상태 머신 상태
enum _LoopState { idle, showingBase, showingReaction }

/// 돌보기(1탭) — 4개 정보 카드 + 캐릭터 + 4버튼
class CaringPage extends StatefulWidget {
  final ValueChanged<int>? onTabRequested;
  final ValueChanged<int>? onGrowthSubTabRequested;

  /// 온보딩 진행 중이면 true — 캐릭터 기본 메시지 루프 차단
  final bool isOnboardingActive;

  /// 온보딩 중 캐릭터 위에 표시할 대사 (null이면 표시 안 함)
  final String? onboardingDialogue;

  const CaringPage({
    super.key,
    this.onTabRequested,
    this.onGrowthSubTabRequested,
    this.isOnboardingActive = false,
    this.onboardingDialogue,
  });

  @override
  State<CaringPage> createState() => _CaringPageState();
}

class _CaringPageState extends State<CaringPage>
    with TickerProviderStateMixin {
  // ── 로딩 ──
  bool _loading = true;

  // ── 온보딩 완료 후 카드/버튼 순차 페이드인 ──
  // 카드 4개(0~400ms) + 버튼 4개(500~900ms), 전체 1200ms 컨트롤러
  late AnimationController _revealCtrl;
  // 각 항목 animation (Interval 기반): card0~3, btn0~3
  late List<Animation<double>> _cardAnims;   // 카드 4개
  late List<Animation<double>> _btnAnims;    // 버튼 4개

  // ── 카드 데이터 ──
  String _jobsSummary = '근처 신규 구인 확인 중...';
  String _jobsSub = '';
  List<Map<String, String>> _upcomingPolicies = [];
  int _policyIndex = 0;
  Timer? _policyTimer;
  Ebook? _weeklyBook;
  String _quizSummary = '오늘의 퀴즈 확인 중...';

  // ── 상태 머신 ──
  _LoopState _loopState = _LoopState.idle;
  Timer? _msgLoopTimer;
  DateTime? _baseShowStart; // 현재 기본 메시지 노출 시작 시각

  // ── 기본 메시지 (캐릭터 위) ──
  String? _baseMsgText;
  bool _isBaseMsgDismissing = false;

  // ── 리액션 메시지 (캐릭터 아래, 기존 위치 유지) ──
  String? _currentSpeech;
  bool _isDismissingSpeech = false;

  // ── 큐 / 이벤트 (세션 내 인메모리) ──
  final Queue<String> _reactionQueue = Queue<String>();
  final Queue<String> _eventQueue = Queue<String>();
  final Set<String> _shownEventIds = <String>{};

  // ── Rive (0.14.x) ──
  File? _riveFile;
  RiveWidgetController? _dogController;
  TriggerInput? _tapTrigger;

  // 터치 리액션 fallback 문구
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

    // 카드/버튼 순차 페이드인 컨트롤러 (전체 1200ms)
    // 카드: 0→800ms 구간에서 200ms 간격
    // 버튼: 500→1200ms 구간에서 150ms 간격
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // 카드 4개: 각 200ms 간격으로 순차 등장
    _cardAnims = List.generate(4, (i) {
      final start = (i * 200) / 1200;
      final end = (i * 200 + 300) / 1200;
      return CurvedAnimation(
        parent: _revealCtrl,
        curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0),
            curve: Curves.easeOut),
      );
    });

    // 버튼 4개: 카드 후 150ms 간격으로 순차 등장
    _btnAnims = List.generate(4, (i) {
      final start = (500 + i * 150) / 1200;
      final end = (500 + i * 150 + 300) / 1200;
      return CurvedAnimation(
        parent: _revealCtrl,
        curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0),
            curve: Curves.easeOut),
      );
    });

    // 온보딩이 없으면 처음부터 완전히 표시
    if (!widget.isOnboardingActive) {
      _revealCtrl.value = 1.0;
    }    _loadRiveFile();
    _bootstrap();
    Future.microtask(() async {
      await CaringActionService.dailySettle();
      // 이벤트 감지 (Firestore) → 큐에 적재 → 루프 시작
      final detectedEvents = await CaringActionService.detectOpenEvents();
      for (final eventId in detectedEvents) {
        _queueEventIfNew(eventId);
      }
      // 온보딩 중이면 메시지 루프 시작 안 함
      if (mounted && !widget.isOnboardingActive) _startMsgLoop();
    });
  }

  @override
  void didUpdateWidget(CaringPage old) {
    super.didUpdateWidget(old);
    // 온보딩이 완료됐을 때(true→false) 카드/버튼 페이드인 + 메시지 루프 시작
    if (old.isOnboardingActive && !widget.isOnboardingActive) {
      _revealCtrl.forward(from: 0.0);
      if (_loopState == _LoopState.idle && _baseMsgText == null) {
        _startMsgLoop();
      }
    }
  }

  @override
  void dispose() {
    _policyTimer?.cancel();
    _msgLoopTimer?.cancel();
    _tapTrigger?.dispose();
    _dogController?.dispose();
    _riveFile?.dispose();
    _revealCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════
  // 데이터 로드
  // ══════════════════════════════════════════════

  Future<void> _loadRiveFile() async {
    try {
      final file = await File.asset(
        'assets/dog.riv',
        riveFactory: Factory.rive,
      );
      if (file == null || !mounted) return;
      final controller = RiveWidgetController(file);
      _tapTrigger = controller.stateMachine.trigger('tap');
      if (mounted) {
        setState(() {
          _riveFile = file;
          _dogController = controller;
        });
      }
    } catch (e) {
      debugPrint('❌ dog.riv 로드 실패: $e');
    }
  }

  Future<void> _bootstrap({bool showLoader = true}) async {
    if (showLoader) setState(() => _loading = true);

    try {
      // ── 병렬 로드: CaringState / BondScore / 구인 / 전자책 동시 요청 ──
      final futures = await Future.wait<dynamic>([
        CaringStateService.loadState(),                                        // [0] CaringState
        BondScoreService.applyCenterGravity(),                                 // [1] void → null
        JobService().getRecentJobsSummary(),                                   // [2] Map
        EbookService().watchEbooks().first.catchError((_) => <Ebook>[]),       // [3] List<Ebook>
      ]);

      final jobData = futures[2] as Map<String, dynamic>;
      final jobCount = (jobData['count'] as int?) ?? 0;
      final clinicName = (jobData['clinicName'] as String?) ?? '';

      final ebooks = futures[3] as List<Ebook>;
      final featuredBook = ebooks.isNotEmpty ? ebooks.first : null;

      final policies = [
        {'title': '2026 스케일링 급여 개정', 'dday': 'D-12', 'date': '3월 1일'},
        {'title': '치주질환 급여 인정 기준 변경', 'dday': 'D-21', 'date': '3월 10일'},
        {'title': '근관치료 행위 산정 지침 개정', 'dday': 'D-26', 'date': '3월 15일'},
      ];

      if (!mounted) return;
      setState(() {
        _jobsSummary = jobCount > 0 ? '오늘 새로 올라온 $jobCount건' : '새로운 구인 공고가 없어요';
        _jobsSub = jobCount > 0 && clinicName.isNotEmpty ? clinicName : '';
        _upcomingPolicies = policies;
        _weeklyBook = featuredBook;
        _quizSummary = '치주낭 측정 시 올바른 탐침 방향은?';
        _loading = false;
      });

      _startPolicyRolling();
    } catch (e) {
      debugPrint('❌ 데이터 로드 실패: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startPolicyRolling() {
    _policyTimer?.cancel();
    if (_upcomingPolicies.isEmpty) return;
    _policyIndex = 0;
    _policyTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() {
        _policyIndex = (_policyIndex + 1) % _upcomingPolicies.length;
      });
    });
  }

  // ══════════════════════════════════════════════
  // 기본 메시지 상태 머신
  // ══════════════════════════════════════════════

  void _startMsgLoop() {
    // 첫 탭 진입 시 즉시 첫 메시지 노출 (공백 없이)
    _showNextBase();
  }

  void _showNextBase() {
    if (!mounted) return;
    _loopState = _LoopState.showingBase;
    _baseShowStart = DateTime.now();

    // 이벤트 메시지 우선, 없으면 기본 메시지 생성
    final msg = _eventQueue.isNotEmpty
        ? _eventQueue.removeFirst()
        : BaseMessageService.generate();

    debugPrint('[MsgLoop] state=ShowingBaseOrEvent start');

    setState(() {
      _baseMsgText = msg;
      _isBaseMsgDismissing = false;
    });

    _msgLoopTimer?.cancel();
    _msgLoopTimer = Timer(const Duration(seconds: 4), _onBaseShowEnd);
  }

  void _onBaseShowEnd() {
    if (!mounted) return;
    setState(() => _isBaseMsgDismissing = true);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _baseMsgText = null;
        _isBaseMsgDismissing = false;
      });
      if (_reactionQueue.isNotEmpty) {
        _showNextReaction();
      } else {
        _startIdleGap();
      }
    });
  }

  void _startIdleGap() {
    _loopState = _LoopState.idle;
    debugPrint('[MsgLoop] state=IdleGap start');
    _msgLoopTimer?.cancel();
    _msgLoopTimer = Timer(const Duration(seconds: 3), _showNextBase);
  }

  void _showNextReaction() {
    if (!mounted) return;
    if (_reactionQueue.isEmpty) {
      _startIdleGap();
      return;
    }

    _loopState = _LoopState.showingReaction;
    final msg = _reactionQueue.removeFirst();
    debugPrint('[Reaction] show start, queueLen=${_reactionQueue.length}');

    setState(() {
      _currentSpeech = msg;
      _isDismissingSpeech = false;
    });

    _msgLoopTimer?.cancel();
    // 리액션 메시지 지속시간: 2초 (밥/사랑 리액션 텍스트가 충분히 읽히도록)
    _msgLoopTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _isDismissingSpeech = true);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() {
          _currentSpeech = null;
          _isDismissingSpeech = false;
        });
        debugPrint('[Reaction] show end, dequeued');
        _showNextReaction();
      });
    });
  }

  /// 리액션(밥/사랑) 발생 시 큐에 추가 + 전환 로직
  void _enqueueReaction(String msg) {
    _reactionQueue.add(msg);
    debugPrint('[Reaction] queued, queueLen=${_reactionQueue.length}');

    switch (_loopState) {
      case _LoopState.showingBase:
        final elapsed = _baseShowStart != null
            ? DateTime.now().difference(_baseShowStart!).inMilliseconds
            : 2001;
        debugPrint('[MsgLoop] openShownElapsed=${elapsed}ms');
        _msgLoopTimer?.cancel();
        if (elapsed >= 2000) {
          // 이미 2초 경과 → 즉시 전환
          _onBaseShowEnd();
        } else {
          // 2초 채울 때까지 대기 후 전환
          final remainMs = 2000 - elapsed;
          _msgLoopTimer = Timer(
            Duration(milliseconds: remainMs),
            _onBaseShowEnd,
          );
        }
        break;
      case _LoopState.idle:
        // 공백 중 → 즉시 리액션 표시
        _msgLoopTimer?.cancel();
        _showNextReaction();
        break;
      case _LoopState.showingReaction:
        // 이미 리액션 처리 중 → 큐에서 자동 순차 처리
        break;
    }
  }

  /// 이벤트 ID를 세션 내 1회만 큐에 삽입
  /// \n으로 구분된 여러 줄은 각각 별도 메시지로 순차 큐잉
  void _queueEventIfNew(String eventId) {
    if (_shownEventIds.contains(eventId)) return;
    _shownEventIds.add(eventId);
    final msg = BaseMessageData.eventMessages[eventId];
    if (msg != null) {
      // 여러 줄은 각각 별도 메시지로 분리하여 순차 표시
      final lines = msg.split('\n').where((l) => l.trim().isNotEmpty).toList();
      for (final line in lines) {
        _eventQueue.add(line.trim());
      }
      debugPrint('[MsgLoop] queued event: $eventId (${lines.length} lines)');
    }
  }

  // ══════════════════════════════════════════════
  // 액션 핸들러
  // ══════════════════════════════════════════════

  void _goBookDetail() {
    if (_weeklyBook == null) {
      widget.onTabRequested?.call(2);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EbookDetailPage(ebook: _weeklyBook!)),
    );
  }

  /// 캐릭터 터치 (사랑하기)
  void _onCircleTap() async {
    _tapTrigger?.fire();
    final result = await CaringActionService.tryTouch();
    if (!mounted) return;

    final phrase = result.ment.isNotEmpty
            ? result.ment
            : _neutralPhrases[Random().nextInt(_neutralPhrases.length)];

    _enqueueReaction(phrase);
    if (result.bondDelta > 0) _showFloatingDelta(result.bondDelta);
    }

  void _onFeed() async {
    _tapTrigger?.fire(); // 밥먹기 애니메이션 재생
    final result = await CaringActionService.tryFeed();
    if (!mounted) return;

    final msg = result.success
        ? (result.ment ?? '밥을 줬어요')
        : (result.rejectMent ?? '나중에 다시 시도하세요');

    _enqueueReaction(msg);
    if (result.success && result.bondDelta > 0) _showFloatingDelta(result.bondDelta);
    if (result.success) _bootstrap(showLoader: false);
  }

  void _onLove() => _onCircleTap();

  void _onDiary() {
    DiaryInputSheet.show(context, (text) async {
      _bootstrap();
        });
      }

  void _onGoal() {
    UserGoalSheet.show(context);
  }

  void _showFloatingDelta(double delta) {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offsetX = (size.width / 2) + 30 + (Random().nextDouble() * 40 - 20);
    final offsetY = (size.height * 0.52) + (Random().nextDouble() * 20 - 10);
    final label = '결+${delta.toStringAsFixed(2)}';

    final entry = OverlayEntry(
      builder: (ctx) => Positioned(
            left: offsetX,
            top: offsetY,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1500),
              builder: (_, value, child) {
                return Transform.translate(
                  offset: Offset(0, -value * 50),
                  child: Opacity(
                    opacity: 1.0 - value,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent.withOpacity(1.0 - value),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 1500), () => entry.remove());
  }

  // ══════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.appBg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isOnboarding = widget.isOnboardingActive;

    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: SafeArea(
        // ── 핵심 구조 ──
        // Column으로 카드/캐릭터/버튼을 수직 배치
        // 카드와 버튼은 Stack 완전 밖 → z-order 충돌 없음, 절대 가려지지 않음
        // 캐릭터는 Expanded > ClipRect > Stack 안 → 남은 공간만 사용 (이전과 동일한 크기)
        // 텍스트는 캐릭터 Stack 안에서 Positioned으로 겹침
        child: Column(
          children: [
            // ── [타이틀] 온보딩 중에는 숨김, 일반 상태에서만 표시 ──
            if (!isOnboarding) _buildTopBar(titleVisible: true),

            // ── [위] 카드 영역: 온보딩 중 invisible (공간 유지 → 캐릭터 크기 정규와 동일) ──
            Visibility(
              visible: true, // maintainSize 역할: 항상 공간 유지
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: ConstrainedBox(
                // 큰 화면에서 카드 영역이 지나치게 높아지지 않도록 최대 높이 제한
                // (화면 높이의 38%, 최소 240 · 최대 320dp)
                constraints: BoxConstraints(
                  maxHeight: (MediaQuery.of(context).size.height * 0.38)
                      .clamp(240.0, 320.0),
                ),
              child: Container(
                color: AppColors.appBg,
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTopBar(titleVisible: false),
                    // 카드 4개 — 순차 페이드인 (온보딩 완료 후)
                    FadeTransition(
                      opacity: isOnboarding
                          ? const AlwaysStoppedAnimation(0.0)
                          : _cardAnims[0],
                      child: _TapCard(
                        title: '📍 내 주변 구인 치과',
                        bigText: _jobsSummary,
                        subtitle: _jobsSub,
                        onTap: () => widget.onTabRequested?.call(3),
                      ),
                    ),
                    FadeTransition(
                      opacity: isOnboarding
                          ? const AlwaysStoppedAnimation(0.0)
                          : _cardAnims[1],
                      child: _PolicyRollingCard(
                        policies: _upcomingPolicies,
                        index: _policyIndex,
                        onTap: () {
                          widget.onTabRequested?.call(2);
                          widget.onGrowthSubTabRequested?.call(1);
                        },
                      ),
                    ),
                    FadeTransition(
                      opacity: isOnboarding
                          ? const AlwaysStoppedAnimation(0.0)
                          : _cardAnims[2],
                      child: _TapCard(
                        title: '📖 이주의 책',
                        bigText: _weeklyBook?.title ?? '이번 주 추천 책이 없어요',
                        subtitle: (_weeklyBook != null &&
                                _weeklyBook!.author.isNotEmpty)
                            ? '저자: ${_weeklyBook!.author}'
                            : '',
                        onTap: _goBookDetail,
                      ),
                    ),
                    FadeTransition(
                      opacity: isOnboarding
                          ? const AlwaysStoppedAnimation(0.0)
                          : _cardAnims[3],
                      child: _TapCard(
                        title: '🧠 오늘의 1문제',
                        bigText: _quizSummary,
                        subtitle: '터치해서 풀기',
                        onTap: () {
                          widget.onTabRequested?.call(2);
                          widget.onGrowthSubTabRequested?.call(0);
                        },
                      ),
                    ),
                  ],
                ),
                ),
              ),
            ),

            // ── [중간] 캐릭터 + 텍스트: Expanded (온보딩/정규 모두 동일한 크기) ──
            Expanded(
              child: ClipRect(child: _buildCharacterStack(isOnboarding)),
            ),

            // ── [아래] 버튼: 온보딩 중 invisible (공간 유지), 완료 후 순차 페이드인 ──
            Visibility(
              visible: true, // 항상 공간 유지
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Container(
                color: AppColors.appBg,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: _buildBottomSection(isOnboarding: isOnboarding),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 캐릭터 + 텍스트 오버레이 Stack (공통) ──
  Widget _buildCharacterStack(bool isOnboarding) {
    return Stack(
      children: [
        // 캐릭터
        Positioned.fill(
          child: GestureDetector(
            onTap: isOnboarding ? null : _onCircleTap,
            child: _dogController != null
                ? LayoutBuilder(
                    builder: (ctx, constraints) {
                      // 기준 화면 높이(Pixel Pro 캐릭터 영역 ≈ 284dp) 대비
                      // 현재 캐릭터 영역 높이로 scale을 동적 계산
                      // → 작은 폰/큰 폰 모두 동일한 시각 비율 유지
                      // clamp: 최소 1.7(너무 작아지지 않게) · 최대 2.5(너무 커지지 않게)
                      final baseH = 284.0;
                      final scale = (constraints.maxHeight / baseH * 2.112)
                          .clamp(1.7, 2.5);

                      return OverflowBox(
                        maxWidth: constraints.maxWidth * scale,
                        maxHeight: constraints.maxHeight * scale,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: constraints.maxWidth * scale,
                          height: constraints.maxHeight * scale,
                          child: RiveWidget(
                            controller: _dogController!,
                            fit: Fit.contain,
                          ),
                        ),
                      );
                    },
                  )
                : const SizedBox.shrink(),
          ),
        ),

        // 텍스트 오버레이 (캐릭터 위에 겹침)
        Positioned.fill(
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final h = constraints.maxHeight;
                // 온보딩 중: 더 위에 표시 (2줄 위), 일반: 캐릭터 상단 18%
                final baseMsgTop = isOnboarding ? h * 0.06 : h * 0.18;
                // 리액션 메시지: 캐릭터 영역 하단 86% 지점
                final reactionTop = h * 0.86;

                // 온보딩 중: 온보딩 대사를 기본메시지 자리에 표시
                final displayText = isOnboarding
                    ? widget.onboardingDialogue
                    : _baseMsgText;
                final isDismissing =
                    isOnboarding ? false : _isBaseMsgDismissing;

                return Stack(
                  children: [
                    Positioned(
                      top: baseMsgTop,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: SpeechOverlay(
                          text: displayText,
                          isDismissing: isDismissing,
                          isOnboarding: isOnboarding,
                        ),
                      ),
                    ),
                    // 리액션 메시지: 온보딩 중에는 표시 안 함
                    if (!isOnboarding)
                      Positioned(
                        top: reactionTop,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: SpeechOverlay(
                            text: _currentSpeech,
                            isDismissing: _isDismissingSpeech,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// [titleVisible=true]  : 아이콘 행 숨김, 타이틀+서브텍스트만 표시 (온보딩 중 상단)
  /// [titleVisible=false] : 아이콘 행 표시, 타이틀+서브텍스트 숨김 (카드영역 내부)
  Widget _buildTopBar({bool titleVisible = true}) {
    if (titleVisible) {
      // 온보딩 중 상단에 항상 표시되는 타이틀 행
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 타이틀 + 아이콘 (한 행으로 통합) ──
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '나',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.info_outline,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  onPressed: () => _showConceptDialog(context),
                ),
                IconButton(
                  icon: Icon(
                    Icons.settings_outlined,
                    color: AppColors.textDisabled,
                    size: 20,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    );
                  },
                ),
              ],
            ),
          ),
          // ── 서브타이틀 ──
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              '오늘 하루도 잘 버텼어요.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 8),
        ],
      );
    } else {
      // 카드 영역 내부 — 타이틀/서브텍스트를 0높이로 유지 (공간 확보용)
      return const SizedBox.shrink();
    }
  }

  Widget _buildBottomSection({bool isOnboarding = false}) {
    // 버튼 정의 목록
    final buttons = [
      _ActionBtn(icon: Icons.restaurant_outlined, label: '밥먹기', onTap: _onFeed),
      _ActionBtn(icon: Icons.favorite_outline,    label: '사랑하기', onTap: _onLove),
      _ActionBtn(icon: Icons.edit_outlined,        label: '기록하기', onTap: _onDiary),
      _ActionBtn(icon: Icons.flag_outlined,        label: '목표',    onTap: _onGoal),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(buttons.length, (i) {
        final anim = isOnboarding
            ? const AlwaysStoppedAnimation<double>(0.0)
            : _btnAnims[i];
        return FadeTransition(opacity: anim, child: buttons[i]);
      }),
    );
  }

  void _showConceptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
            title: const Text(
              "'나' 탭에 대해서",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            content: const SingleChildScrollView(
              child: Text(
                "📱 캐릭터\n"
                "• 터치하면 작은 교감이 쌓입니다.\n\n"
                "🍚 밥먹기\n"
                "• 하루 한 번, 캐릭터에게 밥을 줄 수 있습니다.\n\n"
                "💕 사랑하기\n"
                "• 캐릭터에게 사랑을 주는 것은 터치면 충분합니다.\n\n"
                "📝 기록하기\n"
                "• 오늘 하루를 한 줄로 기록합니다.\n\n"
                "🎯 목표달성하기\n"
                "• 주간 목표를 설정하고 체크합니다.\n\n"
                "💖 결 점수\n"
                "• 결은 당신과 앱(또는 파트너)과의 깊이를 나타냅니다.\n"
                "• 교감이 쌓일수록 결이 깊어져요.",
                style: TextStyle(fontSize: 13, height: 1.6),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('닫기'),
              ),
            ],
          ),
    );
  }
}

// ══════════════════════════════════════════════
// 위젯 클래스들
// ══════════════════════════════════════════════

class _TapCard extends StatelessWidget {
  const _TapCard({
    required this.title,
    required this.bigText,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String bigText;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Material(
        color: AppColors.surfaceMuted,  // muted surface 카드 배경
        elevation: 0,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: radius,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 왼쪽 타이틀: 최소 공간만 차지 (flex 4)
                Flexible(
                  flex: 4,
                  fit: FlexFit.tight,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,  // Blue 타이틀 (대비↑)
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 오른쪽 텍스트: 화면 너비 비례 (flex 5), 넘치면 말줄임
                Flexible(
                  flex: 5,
                  fit: FlexFit.tight,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      Text(
                        bigText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.accent, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PolicyRollingCard extends StatelessWidget {
  const _PolicyRollingCard({
    required this.policies,
    required this.index,
    required this.onTap,
  });

  final List<Map<String, String>> policies;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);

    String big = '예정된 변경 없음';
    String sub = '';

    if (policies.isNotEmpty) {
      final p = policies[index.clamp(0, policies.length - 1)];
      big = p['title'] ?? '';
      sub = '시행일: ${p['date']} (${p['dday']})';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Material(
        color: AppColors.surfaceMuted,  // muted surface 카드 배경
        elevation: 0,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: radius,
            ),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                // 오른쪽 롤링 텍스트 영역: 전체 카드 너비의 55% 이하, 최대 200
                final rightMaxW = (constraints.maxWidth * 0.55).clamp(0.0, 200.0);

                return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                    // 왼쪽 타이틀: 남은 공간 차지
                    Expanded(
                  child: Text(
                    '🏥 임박 제도 변경',
                        style: const TextStyle(
                      fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,  // Blue (대비↑)
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                    // 오른쪽 롤링 영역: 화면 비율 기반 최대 너비 제한
                ClipRect(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: rightMaxW),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    layoutBuilder: (current, previous) => Stack(
                          alignment: Alignment.centerRight,
                          children: [...previous, if (current != null) current],
                        ),
                    transitionBuilder: (child, animation) {
                      final isLeaving =
                          animation.status == AnimationStatus.reverse ||
                          animation.status == AnimationStatus.dismissed;
                      final offsetTween = Tween<Offset>(
                        begin: isLeaving
                                ? const Offset(0, -1.0)
                                : const Offset(0, 1.0),
                        end: Offset.zero,
                      );
                      return SlideTransition(
                        position: offsetTween.animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: SizedBox(
                      key: ValueKey(big),
                            width: rightMaxW,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            big,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                            ),
                          ),
                          if (sub.isNotEmpty)
                            Text(
                              sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontSize: 10,
                                      color: AppColors.textSecondary,  // 진한 회색
                              ),
                            ),
                        ],
                            ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: AppColors.accent, size: 20),
              ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          // 화면 너비의 13%를 기준으로 버튼 크기 결정, 최소 44·최대 64 clamp
          final screenW = MediaQuery.of(ctx).size.width;
          final btnSize = (screenW * 0.13).clamp(44.0, 64.0);
          final iconSize = (btnSize * 0.43).clamp(20.0, 28.0);

          return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: btnSize,
            height: btnSize,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.onAccent, size: iconSize),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
            ),
          ),
        ],
          );
        },
      ),
    );
  }
}
