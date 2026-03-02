import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';
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

// ── 디자인 컬러 팔레트 ──
const _colorAccent = Color(0xFFF7CBCA);
const _colorText = Color(0xFF5D6B6B);
const _colorBg = Color(0xFFF1F7F7);

/// 기본 메시지 상태 머신 상태
enum _LoopState { idle, showingBase, showingReaction }

/// 돌보기(1탭) — 4개 정보 카드 + 캐릭터 + 4버튼
class CaringPage extends StatefulWidget {
  final ValueChanged<int>? onTabRequested;
  final ValueChanged<int>? onGrowthSubTabRequested;

  const CaringPage({
    super.key,
    this.onTabRequested,
    this.onGrowthSubTabRequested,
  });

  @override
  State<CaringPage> createState() => _CaringPageState();
}

class _CaringPageState extends State<CaringPage>
    with SingleTickerProviderStateMixin {
  // ── 로딩 ──
  bool _loading = true;

  // ── 카드 데이터 ──
  String _jobsSummary = '근처 신규 구인 확인 중...';
  String _jobsSub = '';
  List<Map<String, String>> _upcomingPolicies = [];
  int _policyIndex = 0;
  Timer? _policyTimer;
  Ebook? _weeklyBook;
  String _quizSummary = '오늘의 퀴즈 확인 중...';

  // ── 높이 측정 (캐릭터 자동 배치) ──
  final GlobalKey _topKey = GlobalKey();
  final GlobalKey _bottomKey = GlobalKey();
  double _topH = 270;
  double _bottomH = 100;

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

  // ── Rive ──
  Artboard? _dogArtboard;
  StateMachineController? _dogStateMachine;
  SMITrigger? _tapTrigger;

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
    _loadRiveFile();
    _bootstrap();
    Future.microtask(() async {
      await CaringActionService.dailySettle();
      // 이벤트 감지 (Firestore) → 큐에 적재 → 루프 시작
      final detectedEvents = await CaringActionService.detectOpenEvents();
      for (final eventId in detectedEvents) {
        _queueEventIfNew(eventId);
      }
      if (mounted) _startMsgLoop();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _policyTimer?.cancel();
    _msgLoopTimer?.cancel();
    _dogStateMachine?.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════
  // Rive / 데이터 로드
  // ══════════════════════════════════════════════

  Future<void> _loadRiveFile() async {
    try {
      final data = await rootBundle.load('assets/dog.riv');
      final file = RiveFile.import(data);
      final artboard = file.mainArtboard.instance();

      final controller = StateMachineController.fromArtboard(
        artboard,
        'State Machine 1',
      );

      if (controller != null) {
        artboard.addController(controller);
        _tapTrigger = controller.findInput<bool>('tap') as SMITrigger?;
      }

      setState(() {
        _dogArtboard = artboard;
        _dogStateMachine = controller;
      });
    } catch (e) {
      debugPrint('❌ dog.riv 로드 실패: $e');
    }
  }

  Future<void> _bootstrap({bool showLoader = true}) async {
    if (showLoader) setState(() => _loading = true);

    try {
      await CaringStateService.loadState();
      await BondScoreService.applyCenterGravity();

      final jobService = JobService();
      final jobData = await jobService.getRecentJobsSummary();
      final jobCount = jobData['count'] ?? 0;
      final clinicName = jobData['clinicName'] ?? '';

      final policies = [
        {'title': '2026 스케일링 급여 개정', 'dday': 'D-12', 'date': '3월 1일'},
        {'title': '치주질환 급여 인정 기준 변경', 'dday': 'D-21', 'date': '3월 10일'},
        {'title': '근관치료 행위 산정 지침 개정', 'dday': 'D-26', 'date': '3월 15일'},
      ];

      Ebook? featuredBook;
      try {
        final ebookService = EbookService();
        final ebooks = await ebookService.watchEbooks().first;
        if (ebooks.isNotEmpty) featuredBook = ebooks.first;
      } catch (e) {
        debugPrint('⚠️ 이주의 책 로드 실패: $e');
      }

      setState(() {
        _jobsSummary = jobCount > 0 ? '오늘 새로 올라온 $jobCount건' : '새로운 구인 공고가 없어요';
        _jobsSub = jobCount > 0 && clinicName.isNotEmpty ? clinicName : '';
        _upcomingPolicies = policies;
        _weeklyBook = featuredBook;
        _quizSummary = '치주낭 측정 시 올바른 탐침 방향은?';
        _loading = false;
      });

      _startPolicyRolling();
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    } catch (e) {
      debugPrint('❌ 데이터 로드 실패: $e');
      setState(() => _loading = false);
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

  void _measure() {
    final topBox = _topKey.currentContext?.findRenderObject() as RenderBox?;
    final bottomBox =
        _bottomKey.currentContext?.findRenderObject() as RenderBox?;

    if (topBox != null && bottomBox != null) {
      final newTop = topBox.size.height;
      final newBottom = bottomBox.size.height;
      if ((newTop - _topH).abs() > 2 || (newBottom - _bottomH).abs() > 2) {
        setState(() {
          _topH = newTop;
          _bottomH = newBottom;
        });
      }
    }
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
  void _queueEventIfNew(String eventId) {
    if (_shownEventIds.contains(eventId)) return;
    _shownEventIds.add(eventId);
    final msg = BaseMessageData.eventMessages[eventId];
    if (msg != null) {
      _eventQueue.add(msg);
      debugPrint('[MsgLoop] queued event: $eventId');
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
                          color: _colorAccent.withOpacity(1.0 - value),
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
      return const Scaffold(
        backgroundColor: _colorBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final safeBottom = _bottomH + 8;

    return Scaffold(
      backgroundColor: _colorBg,
      body: Stack(
        children: [
          // 배경
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: Container(color: _colorBg),
            ),
          ),

          // ── 캐릭터 ──
          Positioned(
            top: _topH,
            left: 0,
            right: 0,
            bottom: safeBottom,
            child: GestureDetector(
              onTap: _onCircleTap,
              child: _dogArtboard != null
                      ? LayoutBuilder(
                        builder: (ctx, constraints) {
                          const scale = 2.112;
                          return OverflowBox(
                            maxWidth: constraints.maxWidth * scale,
                            maxHeight: constraints.maxHeight * scale,
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: constraints.maxWidth * scale,
                              height: constraints.maxHeight * scale,
                              child: Rive(
                                artboard: _dogArtboard!,
                                fit: BoxFit.contain,
                                alignment: Alignment.center,
                              ),
                            ),
                          );
                        },
                      )
                      : const SizedBox.shrink(),
            ),
          ),

          // ── 기본 메시지 (오늘의 1문제 카드와 캐릭터 사이) ──
          Positioned(
            top: _topH + 110,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: true,
              child: Center(
                child: SpeechOverlay(
                  text: _baseMsgText,
                  isDismissing: _isBaseMsgDismissing,
                ),
              ),
            ),
          ),

          // ── 리액션 말풍선 (캐릭터 아래) ──
          Positioned(
            bottom: safeBottom + 10,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: true,
              child: Center(
                child: SpeechOverlay(
                  text: _currentSpeech,
                  isDismissing: _isDismissingSpeech,
                ),
              ),
            ),
          ),

          // 하단 버튼
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                key: _bottomKey,
                color: _colorBg,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: _buildBottomSection(),
              ),
            ),
          ),

          // 상단 카드 4개
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                key: _topKey,
                color: _colorBg,
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTopBar(),
                    _TapCard(
                      title: '📍 내 주변 구인 치과',
                      bigText: _jobsSummary,
                      subtitle: _jobsSub,
                      onTap: () => widget.onTabRequested?.call(3),
                    ),
                    _PolicyRollingCard(
                      policies: _upcomingPolicies,
                      index: _policyIndex,
                      onTap: () {
                        widget.onTabRequested?.call(2);
                        widget.onGrowthSubTabRequested?.call(1);
                      },
                    ),
                    _TapCard(
                      title: '📖 이주의 책',
                      bigText: _weeklyBook?.title ?? '이번 주 추천 책이 없어요',
                      subtitle: '',
                      onTap: _goBookDetail,
                    ),
                    _TapCard(
                      title: '🧠 오늘의 1문제',
                      bigText: _quizSummary,
                      subtitle: '터치해서 풀기',
                      onTap: () {
                        widget.onTabRequested?.call(2);
                        widget.onGrowthSubTabRequested?.call(0);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.info_outline,
                  color: _colorText.withOpacity(0.5),
                  size: 18,
                ),
                onPressed: () => _showConceptDialog(context),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  color: _colorText.withOpacity(0.4),
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
        const Padding(
          padding: EdgeInsets.only(left: 20),
          child: Text(
            '나',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _colorText,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(
            '오늘 하루도 잘 버텼어요.',
            style: TextStyle(fontSize: 12, color: _colorText.withOpacity(0.55)),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBottomSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionBtn(
          icon: Icons.restaurant_outlined,
          label: '밥먹기',
          onTap: _onFeed,
        ),
        _ActionBtn(icon: Icons.favorite_outline, label: '사랑하기', onTap: _onLove),
        _ActionBtn(icon: Icons.edit_outlined, label: '기록하기', onTap: _onDiary),
        _ActionBtn(icon: Icons.flag_outlined, label: '목표', onTap: _onGoal),
      ],
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
        color: Colors.white,
        elevation: 1,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        bigText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black45,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.black45, size: 20),
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
        color: Colors.white,
        elevation: 1,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Text(
                    '🏥 임박 제도 변경',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ClipRect(
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
                      width: 140,
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
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
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
                                color: Colors.black45,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.black45, size: 20),
              ],
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: _colorText, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: _colorText.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
