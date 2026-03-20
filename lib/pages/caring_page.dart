import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rive/rive.dart' hide Animation;
import '../services/caring_state_service.dart';
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
import '../services/admin_activity_service.dart';


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

  /// 현재 선택된 하단 탭 인덱스 (0=돌보기). Overlay 애니메이션을 현재 탭에서만 표시하기 위해 사용.
  final int currentTabIndex;

  const CaringPage({
    super.key,
    this.onTabRequested,
    this.onGrowthSubTabRequested,
    this.isOnboardingActive = false,
    this.onboardingDialogue,
    this.currentTabIndex = 0,
  });

  @override
  State<CaringPage> createState() => _CaringPageState();
}

class _CaringPageState extends State<CaringPage>
    with TickerProviderStateMixin {
  // ── 카드별 독립 로딩 (전체 스피너 없이 스켈레톤 표시) ──
  bool _jobLoading  = true;   // Jobs 카드
  bool _bookLoading = true;   // Weekly Book 카드

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

  // GlobalKey로 캐릭터 영역 좌표를 정확하게 추적
  final GlobalKey _characterAreaKey = GlobalKey();

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
    // ① CaringState(캐릭터 데이터) → 완료 즉시 메시지 루프 시작
    _loadCaringState().then((_) {
      if (mounted && !widget.isOnboardingActive) _startMsgLoop();
    });
    // ② Jobs 카드: 독립 비동기 (가장 느린 항목 → 먼저 분리)
    _loadJobCard();
    // ③ Weekly Book 카드: 독립 비동기
    _loadBookCard();
    // ④ dailySettle + detectOpenEvents: UI 렌더링과 무관하므로 백그라운드 실행
    Future.microtask(() async {
      await CaringActionService.dailySettle();
      // 이벤트 감지 (Firestore) → 큐에 적재 (루프가 다음 사이클에 자동 소비)
      final detectedEvents = await CaringActionService.detectOpenEvents();
      for (final eventId in detectedEvents) {
        _queueEventIfNew(eventId);
      }
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
      debugPrint('🐶 dog.riv 로드 시작...');
      final file = await File.asset(
        'assets/dog.riv',
        riveFactory: Factory.rive,
      );
      debugPrint('🐶 dog.riv 로드 결과: file=${file != null}');
      if (file == null || !mounted) return;
      final controller = RiveWidgetController(file);
      _tapTrigger = controller.stateMachine.trigger('tap');
      debugPrint('🐶 RiveWidgetController 생성 완료, tapTrigger=${_tapTrigger != null}');
      if (mounted) {
        setState(() {
          _riveFile = file;
          _dogController = controller;
        });
      }
    } catch (e, st) {
      // 실기기(갤럭시 S26 등)에서 Rive 로드 실패 시 상세 로그 출력
      debugPrint('❌ dog.riv 로드 실패: $e');
      debugPrint('❌ StackTrace: $st');
    }
  }

  // ── ① CaringState (캐릭터 동작에 필요한 최소 데이터) ──
  Future<void> _loadCaringState() async {
    try {
      await CaringStateService.loadState();
      // Policy / Quiz 카드는 정적 데이터 → CaringState 완료 직후 세팅
      final policies = [
        {'title': '2026 스케일링 급여 개정',       'dday': 'D-12', 'date': '3월 1일'},
        {'title': '치주질환 급여 인정 기준 변경',   'dday': 'D-21', 'date': '3월 10일'},
        {'title': '근관치료 행위 산정 지침 개정',   'dday': 'D-26', 'date': '3월 15일'},
      ];
      if (!mounted) return;
      setState(() {
        _upcomingPolicies = policies;
        _quizSummary = '치주낭 측정 시 올바른 탐침 방향은?';
      });
      _startPolicyRolling();
    } catch (e) {
      debugPrint('❌ _loadCaringState 실패: $e');
    }
  }

  // ── ② Jobs 카드 (네트워크 최다 소요 → 독립) ──
  Future<void> _loadJobCard() async {
    try {
      final jobData = await JobService().getRecentJobsSummary();
      final count      = (jobData['count']      as int?)    ?? 0;
      final hasMore    = (jobData['hasMore']     as bool?)   ?? false;
      final clinicName = (jobData['clinicName']  as String?) ?? '';

      if (!mounted) return;
      setState(() {
        if (count == 0) {
          _jobsSummary = '새로운 구인 공고가 없어요';
          _jobsSub     = '';
        } else if (hasMore) {
          _jobsSummary = '최근 구인 $count건+';
          _jobsSub     = clinicName.isNotEmpty ? clinicName : '';
        } else {
          _jobsSummary = '최근 구인 $count건';
          _jobsSub     = clinicName.isNotEmpty ? clinicName : '';
        }
        _jobLoading = false;
      });
    } catch (e) {
      debugPrint('❌ _loadJobCard 실패: $e');
      if (mounted) setState(() { _jobsSummary = '구인 정보를 불러오지 못했어요'; _jobLoading = false; });
    }
  }

  // ── ③ Weekly Book 카드 ──
  Future<void> _loadBookCard() async {
    try {
      final ebooks = await EbookService().fetchAllEbooks().catchError((_) => <Ebook>[]);
      if (!mounted) return;
      setState(() {
        _weeklyBook  = ebooks.isNotEmpty ? ebooks.first : null;
        _bookLoading = false;
      });
    } catch (e) {
      debugPrint('❌ _loadBookCard 실패: $e');
      if (mounted) setState(() => _bookLoading = false);
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

    AdminActivityService.log(ActivityEventType.tapCharacter, page: 'home');
  }

  void _onFeed() async {
    _tapTrigger?.fire();

    final result = await CaringActionService.tryFeed();
    if (!mounted) return;

    final msg = result.success
        ? (result.ment ?? '밥을 줬어요')
        : (result.rejectMent ?? '나중에 다시 시도하세요');

    _enqueueReaction(msg);
    if (result.success) _loadCaringState();
  }

  void _onLove() => _onCircleTap();

  void _onDiary() {
    AdminActivityService.log(ActivityEventType.tapEmotionStart, page: 'home');
    DiaryInputSheet.show(context, (text) async {
      _loadCaringState();
    });
  }

  void _onGoal() {
    UserGoalSheet.show(context);
  }

  // ══════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.only(bottom: 12),
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
                        title: 'Jobs',
                        bigText: _jobsSummary,
                        subtitle: _jobsSub,
                        onTap: () => widget.onTabRequested?.call(3),
                        isLoading: _jobLoading,
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
                        title: 'Weekly Book',
                        bigText: _weeklyBook?.title ?? '이번 주 추천 책이 없어요',
                        subtitle: (_weeklyBook != null &&
                                _weeklyBook!.author.isNotEmpty)
                            ? '저자: ${_weeklyBook!.author}'
                            : '',
                        onTap: _goBookDetail,
                        isLoading: _bookLoading,
                      ),
                    ),
                    FadeTransition(
                      opacity: isOnboarding
                          ? const AlwaysStoppedAnimation(0.0)
                          : _cardAnims[3],
                      child: _TapCard(
                        title: 'Daily Quiz',
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
          key: _characterAreaKey,
          child: GestureDetector(
            // 온보딩 중: 터치를 소비하되 실제 액션은 실행 안 함
            // → 아래 overlay(GestureDetector)로 이벤트가 전달될 수 있도록
            //   behavior를 translucent로 설정해 상위 overlay가 함께 감지
            onTap: isOnboarding ? null : _onCircleTap,
            behavior: isOnboarding
                ? HitTestBehavior.translucent
                : HitTestBehavior.opaque,
            child: _dogController != null
                ? LayoutBuilder(
                    builder: (ctx, constraints) {
                      // ── 캐릭터 크기: 전체 화면 높이 기준으로 고정 ──
                      // constraints.maxHeight(남은 공간) 대신 screenH를 기준으로 사용
                      // → 카드/버튼 높이 변동에 무관하게 일관된 크기 유지
                      // clamp를 좁혀(±10%) 폰마다 편차 최소화
                      final screenH = MediaQuery.of(ctx).size.height;
                      final baseH = 284.0;           // 기준 캐릭터 영역 높이 (dp)
                      final targetH = screenH * 0.32; // 화면 높이의 32%를 캐릭터 크기 기준으로 고정
                      final rawScale = (targetH / baseH).clamp(0.90, 1.10);
                      // 일반 모드: 0.81 * 1.5 * 0.9 = 1.09 (이전 대비 10% 축소)
                      // 온보딩 중: 일반 크기의 90% = 1.09 * 0.9 ≈ 0.98
                      final scale = isOnboarding ? rawScale * 0.98 : rawScale * 1.09;

                      // OverflowBox 대신 Transform.scale 사용
                      // → BoxConstraints non-normalized 에러 방지
                      return Transform.scale(
                        scale: scale,
                        child: RiveWidget(
                          controller: _dogController!,
                          fit: Fit.contain,
                        ),
                      );
                    },
                  )
                : Center(
                    // Rive 로드 실패 시 fallback (실기기 디버그용)
                    child: Icon(
                      Icons.pets_outlined,
                      size: 80,
                      color: AppColors.textDisabled.withOpacity(0.3),
                    ),
                  ),
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
          const SizedBox(height: 10),
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
      _ActionBtn(icon: Icons.favorite_outline, label: '사랑하기', onTap: _onLove),
      _ActionBtn(icon: Icons.edit_outlined, label: '기록하기', onTap: _onDiary),
      _ActionBtn(icon: Icons.flag_outlined, label: '목표', onTap: _onGoal),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('나와 함께하는 캐릭터를 돌보며 결을 쌓는 공간이에요.', style: TextStyle(fontSize: 13, height: 1.5)),
                  SizedBox(height: 16),
                  Text('💕 사랑하기', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text('캐릭터를 터치하면 작은 교감이 쌓여요. 하루 3번까지 가능해요.', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
                  SizedBox(height: 16),
                  Text('🍚 밥먹기', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text('아침·점심·저녁·밤 시간대마다 한 번씩, 하루 4번 밥을 줄 수 있어요.', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
                  SizedBox(height: 16),
                  Text('📝 기록하기', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text('오늘 하루를 한 줄로 기록해요.', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
                  SizedBox(height: 16),
                  Text('🎯 목표달성', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text('주간 목표를 세우고 체크해요.', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
                ],
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
    this.isLoading = false,
  });

  final String title;
  final String bigText;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Material(
        color: AppColors.cardPrimary,  // Primary 카드 배경 (Green)
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
                    style: GoogleFonts.poppins(
                      fontSize: 14,          // 18 * 0.8 = 14.4 → 14 (-20%)
                      fontWeight: FontWeight.w800,
                      color: AppColors.onCardPrimary,
                      letterSpacing: -0.5,   // tracking 좁게
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 오른쪽 텍스트: 화면 너비 비례 (flex 5), 넘치면 말줄임
                Flexible(
                  flex: 5,
                  fit: FlexFit.tight,
                  child: isLoading
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 스켈레톤 — 굵은 텍스트 자리
                            Container(
                              height: 12,
                              width: 100,
                              decoration: BoxDecoration(
                                color: AppColors.onCardPrimary.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // 스켈레톤 — 서브 텍스트 자리
                            Container(
                              height: 9,
                              width: 64,
                              decoration: BoxDecoration(
                                color: AppColors.onCardPrimary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ],
                        )
                      : Column(
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
                          color: AppColors.onCardPrimary,  // White
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.onCardPrimary.withOpacity(0.7),
                        ),
                      ),
                  ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.onCardPrimary, size: 20),
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
    final radius = BorderRadius.circular(12);

    String big = '예정된 변경 없음';
    String sub = '';

    if (policies.isNotEmpty) {
      final p = policies[index.clamp(0, policies.length - 1)];
      big = p['title'] ?? '';
      sub = '시행일: ${p['date']} (${p['dday']})';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Material(
        color: AppColors.cardPrimary,  // Primary 카드 배경 (Green)
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
                    'Policy Updates',
                        style: GoogleFonts.poppins(
                      fontSize: 14,          // 18 * 0.8 = 14 (-20%)
                          fontWeight: FontWeight.w800,
                          color: AppColors.onCardPrimary,
                          letterSpacing: -0.5,
                          height: 1.1,
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
                                    color: AppColors.onCardPrimary,  // White
                            ),
                          ),
                          if (sub.isNotEmpty)
                            Text(
                              sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 10,
                                      color: AppColors.onCardPrimary.withOpacity(0.7),
                              ),
                            ),
                        ],
                            ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: AppColors.onCardPrimary, size: 20),
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

