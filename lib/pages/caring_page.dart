import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rive/rive.dart' hide Animation, PaintingStyle;
import '../services/caring_state_service.dart';
import '../services/caring_action_service.dart';
import '../services/funnel_onboarding_service.dart';
import '../services/base_message_service.dart';
import '../services/ebook_service.dart';
import '../services/hira_update_service.dart';
import '../services/quiz_content_config_service.dart';
import '../services/quiz_pool_service.dart';
import '../services/caring_treat_service.dart';
import '../data/base_message_data.dart';
import '../models/hira_update.dart';
import '../models/ebook.dart';
import '../widgets/speech_overlay.dart';
import '../pages/ebook/ebook_detail_page.dart';
import 'settings/settings_page.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_badge.dart';
import '../services/admin_activity_service.dart';
import '../data/caring_ments.dart';

enum _LoopState { idle, showingBase, showingReaction }

/// 돌보기(1탭) — 4개 정보 카드 + 원형 게이지 + 캐릭터 + 3버튼
class CaringPage extends StatefulWidget {
  final ValueChanged<int>? onTabRequested;
  /// [hiraInnerTab]: 보험정보 내 0=수가 조회, 1=제도 변경 (null이면 보험정보 기본 소탭 유지)
  final void Function(int subTab, {int? hiraInnerTab})? onGrowthSubTabRequested;
  final bool isOnboardingActive;
  final String? onboardingDialogue;

  /// 탭0(나) 온보딩 전체 구간 — `kStepDialogue`가 없는 step2·4 팝업에서도 캐릭터·말풍선 스케일 유지
  final bool onboardingTab0LayoutBoost;

  /// 온보딩 말풍선에서 굵게 표시할 단어 (예: step1a의 '저니')
  final String? onboardingBoldWord;
  final int currentTabIndex;

  const CaringPage({
    super.key,
    this.onTabRequested,
    this.onGrowthSubTabRequested,
    this.isOnboardingActive = false,
    this.onboardingDialogue,
    this.onboardingTab0LayoutBoost = false,
    this.onboardingBoldWord,
    this.currentTabIndex = 0,
  });

  @override
  State<CaringPage> createState() => _CaringPageState();
}

class _CaringPageState extends State<CaringPage>
    with TickerProviderStateMixin {
  bool _bookLoading = true;

  late AnimationController _revealCtrl;
  late List<Animation<double>> _cardAnims;
  late List<Animation<double>> _btnAnims;

  List<Map<String, String>> _upcomingPolicies = [];
  int _policyIndex = 0;
  /// 정책·퀴즈 카드 공통 롤링 (3초) — [_startCardRolling]
  Timer? _policyTimer;
  Ebook? _weeklyBook;
  /// 오늘 일정에서 최대 2문항 — 2개일 때 [_quizRollIndex]로 롤링
  List<String> _quizRollQuestions = [];
  int _quizRollIndex = 0;
  /// 문항 없음·로딩·오류 시 카드 오른쪽 큰 글씨
  String _quizFallbackText = '오늘의 퀴즈 확인 중...';

  CaringState _caringState = CaringState.initial();

  /// `dailySettle` + 초기 `caringState` 로드 완료 후에만 밥·쓰다듬기 허용
  bool _caringReady = false;

  /// 밥·쓰다듬기 저장(FIFO) 중 중복 액션 방지
  bool _caringPersistBusy = false;

  // 수면 페이드 애니메이션
  late AnimationController _sleepFadeCtrl;
  late Animation<double> _sleepFadeAnim;

  _LoopState _loopState = _LoopState.idle;
  Timer? _msgLoopTimer;
  /// 기본 멘트(랜덤 풀·이벤트 줄) — `BaseMessageService` / `BaseMessageData.eventMessages`
  String? _baseMsgText;
  bool _isBaseMsgDismissing = false;
  /// 리액션 멘트(밥·쓰다듬기·수면 등 액션) — `CaringMents`·폴백 문자열
  String? _reactionMsgText;
  bool _isReactionMsgDismissing = false;
  final Queue<String> _reactionQueue = Queue<String>();
  final Queue<String> _eventQueue = Queue<String>();
  final Set<String> _shownEventIds = <String>{};
  bool _baseFromEventQueue = false;

  static const Duration _eventBaseDisplay = Duration(seconds: 4);
  static const Duration _reactionDisplay = Duration(seconds: 2);
  static const Duration _randomBaseInterval = Duration(seconds: 5);

  /// 캐릭터 위 말풍선 — 일반 모드 한 줄 높이(16×0.85×1.5)의 0.75배만큼 아래
  /// (직전에 1.5줄 분 내렸다가, 그중 절반만큼 다시 올린 위치)
  static const double _kSpeechOverlayExtraTop =
      0.75 * (16.0 * 0.85 * 1.5);

  /// 온보딩 말풍선: 아이들과 동일 기준에서 [SpeechOverlay] 온보딩 한 줄 높이만큼 추가 상향
  static const int _kOnboardingSpeechLiftLines = 3;

  File? _riveFile;
  RiveWidgetController? _dogController;
  TriggerInput? _tapTrigger;
  final GlobalKey _characterAreaKey = GlobalKey();

  static const List<String> _neutralPhrases = [
    '오늘도 여기.', '천천히 해도 괜찮아.', '숨 한 번.',
    '있는 그대로.', '조용한 하루도 괜찮아.', '여기 있어도 돼.',
    '오늘은 오늘만큼.', '작은 것도 충분해.',
  ];

  @override
  void initState() {
    super.initState();

    _revealCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    );
    _cardAnims = List.generate(4, (i) {
      final start = (i * 200) / 1200;
      final end = (i * 200 + 300) / 1200;
      return CurvedAnimation(
        parent: _revealCtrl,
        curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0),
            curve: Curves.easeOut),
      );
    });
    _btnAnims = List.generate(3, (i) {
      final start = (500 + i * 150) / 1200;
      final end = (500 + i * 150 + 300) / 1200;
      return CurvedAnimation(
        parent: _revealCtrl,
        curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0),
            curve: Curves.easeOut),
      );
    });
    if (!widget.isOnboardingActive) _revealCtrl.value = 1.0;

    _sleepFadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500),
    );
    _sleepFadeAnim = CurvedAnimation(
      parent: _sleepFadeCtrl, curve: Curves.easeInOut,
    );

    _loadRiveFile();
    Future.microtask(() => _bootstrapCaringTab());
    _loadBookCard();
    _loadPolicyCard();
    _loadQuizCard();
  }

  @override
  void didUpdateWidget(CaringPage old) {
    super.didUpdateWidget(old);
    if (old.isOnboardingActive && !widget.isOnboardingActive) {
      _revealCtrl.forward(from: 0.0);
      if (_loopState == _LoopState.idle &&
          _baseMsgText == null &&
          _reactionMsgText == null) {
        _startMsgLoop();
      }
    }
    // 다른 탭에서 「나」로 복귀 시 정책·주간책·퀴즈만 갱신
    if (!widget.isOnboardingActive &&
        widget.currentTabIndex == 0 &&
        old.currentTabIndex != 0) {
      _loadPolicyCard();
      _loadBookCard();
      _loadQuizCard();
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
    _sleepFadeCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════
  // 데이터 로드
  // ══════════════════════════════════════════════

  Future<void> _loadRiveFile() async {
    try {
      final file = await File.asset('assets/dog.riv', riveFactory: Factory.rive);
      if (file == null || !mounted) return;
      final controller = RiveWidgetController(file);
      _tapTrigger = controller.stateMachine.trigger('tap');
      if (mounted) setState(() { _riveFile = file; _dogController = controller; });
    } catch (e, st) {
      debugPrint('❌ dog.riv 로드 실패: $e\n$st');
    }
  }

  /// 나 탭 초기화: 정산 → 이벤트 → 상태 표시. [applyTimeDecay]는 직전에 정산된 경우 false.
  Future<void> _bootstrapCaringTab() async {
    try {
      await CaringActionService.dailySettle();
      if (!mounted) return;
      final events = await CaringActionService.detectOpenEvents();
      if (!mounted) return;
      for (final e in events) {
        _queueEventIfNew(e);
      }
      await _loadCaringState(applyTimeDecay: false);
    } catch (e, st) {
      debugPrint('❌ _bootstrapCaringTab: $e\n$st');
      if (mounted) await _loadCaringState(applyTimeDecay: true);
    }
    if (!mounted) return;
    setState(() => _caringReady = true);
    if (!widget.isOnboardingActive) _startMsgLoop();
    if (_caringState.isSleeping) _sleepFadeCtrl.value = 1.0;
  }

  Future<void> _loadCaringState({bool applyTimeDecay = true}) async {
    try {
      final state = await CaringStateService.loadState(applyTimeDecay: applyTimeDecay);
      if (!mounted) return;
      setState(() => _caringState = state);
    } catch (e) {
      debugPrint('❌ _loadCaringState 실패: $e');
    }
  }

  /// Policy 카드 — `content_hira_updates`와 동일 소스 (성장 탭 HIRA 목록과 정합)
  Map<String, String> _hiraToPolicyRow(HiraUpdate u) {
    final ref = u.effectiveDate ?? u.publishedAt;
    return {
      'title': u.title,
      'date': '${ref.month}월 ${ref.day}일',
      'dday': u.getBadgeText(),
    };
  }

  Future<void> _loadPolicyCard() async {
    try {
      final list = await HiraUpdateService.getAllUpdates();
      if (!mounted) return;
      list.sort((a, b) {
        final ae = a.effectiveDate;
        final be = b.effectiveDate;
        if (ae != null && be != null) return ae.compareTo(be);
        if (ae != null) return -1;
        if (be != null) return 1;
        return b.publishedAt.compareTo(a.publishedAt);
      });
      final policies =
          list.take(6).map(_hiraToPolicyRow).toList(growable: false);
      setState(() => _upcomingPolicies = policies);
      _startCardRolling();
    } catch (e, st) {
      debugPrint('❌ _loadPolicyCard: $e\n$st');
      if (mounted) setState(() => _upcomingPolicies = []);
      _startCardRolling();
    }
  }

  /// Daily Quiz 카드 — `quiz_schedule/{오늘}` 문항 최대 2개 (퀴즈 탭과 동일 출처)
  Future<void> _loadQuizCard() async {
    try {
      final cfg = await QuizContentConfigService.getConfig();
      final schedule = await QuizPoolService.getTodaySchedule(contentConfig: cfg);
      if (!mounted) return;
      final qs = <String>[];
      if (schedule != null && schedule.items.isNotEmpty) {
        for (final item in schedule.items) {
          if (qs.length >= 2) break;
          final q = item.question.trim();
          if (q.isNotEmpty) qs.add(q);
        }
      }
      setState(() {
        _quizRollQuestions = qs;
        _quizRollIndex = 0;
        if (qs.isEmpty) {
          _quizFallbackText = '오늘 배포된 퀴즈가 아직 없어요';
        }
      });
      _startCardRolling();
    } catch (e, st) {
      debugPrint('❌ _loadQuizCard: $e\n$st');
      if (mounted) {
        setState(() {
          _quizRollQuestions = [];
          _quizRollIndex = 0;
          _quizFallbackText = '퀴즈 정보를 불러오지 못했어요';
        });
        _startCardRolling();
      }
    }
  }

  /// Weekly Book — `publishedAt` 내림차순 목록에서 주(월요일 기준)마다 안정적으로 1권 선택
  Future<void> _loadBookCard() async {
    try {
      final ebooks = await EbookService().fetchAllEbooks().catchError((_) => <Ebook>[]);
      if (!mounted) return;
      Ebook? pick;
      if (ebooks.isNotEmpty) {
        final nowKst = DateTime.now().toUtc().add(const Duration(hours: 9));
        final monday = nowKst.subtract(Duration(days: nowKst.weekday - 1));
        final seed =
            '${monday.year}-${monday.month}-${monday.day}'.hashCode.abs();
        pick = ebooks[seed % ebooks.length];
      }
      setState(() {
        _weeklyBook = pick;
        _bookLoading = false;
      });
    } catch (e) {
      debugPrint('❌ _loadBookCard 실패: $e');
      if (mounted) setState(() => _bookLoading = false);
    }
  }

  static const Duration _kCardRollInterval = Duration(seconds: 3);

  /// 정책 카드·퀴즈 카드 롤링 타이밍 공유 (2번·4번 카드 동일 3초)
  void _startCardRolling() {
    _policyTimer?.cancel();
    final pLen = _upcomingPolicies.length;
    final qLen = _quizRollQuestions.length;
    if (pLen <= 1 && qLen <= 1) {
      _policyIndex = 0;
      _quizRollIndex = 0;
      return;
    }
    _policyIndex = 0;
    _quizRollIndex = 0;
    _policyTimer = Timer.periodic(_kCardRollInterval, (_) {
      if (!mounted) return;
      setState(() {
        if (pLen > 1) {
          _policyIndex = (_policyIndex + 1) % pLen;
        }
        if (qLen > 1) {
          _quizRollIndex = (_quizRollIndex + 1) % qLen;
        }
      });
    });
  }

  // ══════════════════════════════════════════════
  // 메시지 루프
  // ══════════════════════════════════════════════

  void _startMsgLoop() => _showNextBase();

  /// 이벤트 큐 우선. 비었으면 5초 뒤 랜덤 풀 첫 줄.
  void _showNextBase() {
    if (!mounted) return;
    _msgLoopTimer?.cancel();
    if (_eventQueue.isNotEmpty) {
      _loopState = _LoopState.showingBase;
      _baseFromEventQueue = true;
      final msg = _eventQueue.removeFirst();
      setState(() {
        _baseMsgText = msg;
        _isBaseMsgDismissing = false;
      });
      _msgLoopTimer = Timer(_eventBaseDisplay, _onBaseShowEnd);
      return;
    }
    _loopState = _LoopState.idle;
    _baseFromEventQueue = false;
    _msgLoopTimer = Timer(_randomBaseInterval, () {
      if (!mounted) return;
      if (_eventQueue.isNotEmpty) {
        _showNextBase();
        return;
      }
      _showRandomBaseTick();
    });
  }

  /// 랜덤 풀: 5초 공백 뒤에만 발현 → 잠시 표시 → 사라짐 → 다시 5초 공백 (`_scheduleRandomAfterGap`)
  void _showRandomBaseTick() {
    if (!mounted) return;
    if (_eventQueue.isNotEmpty) {
      _showNextBase();
      return;
    }
    _loopState = _LoopState.showingBase;
    _baseFromEventQueue = false;
    setState(() {
      _baseMsgText = BaseMessageService.generate();
      _isBaseMsgDismissing = false;
    });
    _msgLoopTimer?.cancel();
    _msgLoopTimer = Timer(_eventBaseDisplay, _onBaseShowEnd);
  }

  /// 이벤트·랜덤 공통: 표시 시간 종료 후
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
      } else if (_eventQueue.isNotEmpty) {
        _showNextBase();
      } else {
        _scheduleRandomAfterGap();
      }
    });
  }

  /// 반응/이벤트 없을 때 랜덤까지 5초 대기
  void _scheduleRandomAfterGap() {
    _loopState = _LoopState.idle;
    _msgLoopTimer?.cancel();
    _msgLoopTimer = Timer(_randomBaseInterval, () {
      if (!mounted) return;
      if (_eventQueue.isNotEmpty) {
        _showNextBase();
        return;
      }
      _showRandomBaseTick();
    });
  }

  void _showNextReaction() {
    if (!mounted) return;
    if (_reactionQueue.isEmpty) {
      _scheduleRandomAfterGap();
      return;
    }
    _loopState = _LoopState.showingReaction;
    final msg = _reactionQueue.removeFirst();
    setState(() {
      _reactionMsgText = msg;
      _isReactionMsgDismissing = false;
    });
    _msgLoopTimer?.cancel();
    _msgLoopTimer = Timer(_reactionDisplay, () {
      if (!mounted) return;
      setState(() => _isReactionMsgDismissing = true);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() {
          _reactionMsgText = null;
          _isReactionMsgDismissing = false;
        });
        _showNextReaction();
      });
    });
  }

  void _enqueueReaction(String msg) {
    _reactionQueue.add(msg);
    _msgLoopTimer?.cancel();
    // 어떤 상태든 즉시 기본 멘트를 끊고 리액션을 보여줌
    setState(() {
      _baseMsgText = null;
      _isBaseMsgDismissing = false;
    });
    _showNextReaction();
  }

  void _queueEventIfNew(String eventId) {
    if (_shownEventIds.contains(eventId)) return;
    _shownEventIds.add(eventId);
    final msg = BaseMessageData.eventMessages[eventId];
    if (msg == null) return;
    for (final line in msg.split('\n').where((l) => l.trim().isNotEmpty)) {
      _eventQueue.add(line.trim());
    }
    if (!mounted) return;
    // 랜덤 기본 멘트 표시 중이거나, 랜덤 대기(idle+타이머) 중이면 이벤트 우선
    if (_loopState == _LoopState.showingReaction) return;
    if (_loopState == _LoopState.showingBase && _baseFromEventQueue) return;
    _msgLoopTimer?.cancel();
    if (_loopState == _LoopState.showingBase && !_baseFromEventQueue) {
      setState(() {
        _baseMsgText = null;
        _isBaseMsgDismissing = false;
      });
      _showNextBase();
      return;
    }
    if (_loopState == _LoopState.idle &&
        _baseMsgText == null &&
        _reactionMsgText == null) {
      _showNextBase();
    }
  }

  // ══════════════════════════════════════════════
  // 액션 핸들러
  // ══════════════════════════════════════════════

  void _goBookDetail() {
    if (_weeklyBook == null) { widget.onTabRequested?.call(2); return; }
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EbookDetailPage(ebook: _weeklyBook!, hideActions: true)));
  }

  void _onCircleTap() async {
    if (_caringState.isSleeping || !_caringReady || _caringPersistBusy) return;
    _tapTrigger?.fire();
    final prev = _caringState;
    setState(() => _caringPersistBusy = true);
    try {
      final result =
          await CaringActionService.tryTouch(fromLocal: _caringState);
      if (!mounted) return;
      if (result.state != null) {
        setState(() => _caringState = result.state!);
        final phrase = result.ment.isNotEmpty
            ? result.ment
            : _neutralPhrases[Random().nextInt(_neutralPhrases.length)];
        _enqueueReaction(phrase);
        final ok =
            await CaringStateService.saveStateSequential(result.state!);
        if (!mounted) return;
        if (!ok) {
          setState(() => _caringState = prev);
          _enqueueReaction(
            '저장에 실패했어요. 연결을 확인하고 다시 시도해 주세요.',
          );
        } else {
          AdminActivityService.log(ActivityEventType.tapCharacter, page: 'home');
        }
      } else {
        final phrase = result.ment.isNotEmpty
            ? result.ment
            : _neutralPhrases[Random().nextInt(_neutralPhrases.length)];
        _enqueueReaction(phrase);
      }
    } finally {
      if (mounted) setState(() => _caringPersistBusy = false);
    }
  }

  void _onFeed() async {
    if (_caringState.isSleeping || !_caringReady || _caringPersistBusy) return;

    // energy<30 → 리액션 확률 50%
    final shouldAnimate = _caringState.energy >= 30 || Random().nextBool();
    if (shouldAnimate) _tapTrigger?.fire();

    final prev = _caringState;
    setState(() => _caringPersistBusy = true);
    try {
      final result = await CaringActionService.tryFeed(fromLocal: _caringState);
      if (!mounted) return;
      if (result.success && result.state != null) {
        setState(() => _caringState = result.state!);
        final msg = result.ment ?? '밥을 줬어요';
        _enqueueReaction(msg);
        final ok =
            await CaringStateService.saveStateSequential(result.state!);
        if (!mounted) return;
        if (!ok) {
          setState(() => _caringState = prev);
          _enqueueReaction(
            '저장에 실패했어요. 연결을 확인하고 다시 시도해 주세요.',
          );
        } else {
          AdminActivityService.log(
            ActivityEventType.caringFeedSuccess,
            page: 'home',
          );
          unawaited(FunnelOnboardingService.tryLogFirstFeed());
          unawaited(CaringTreatService.consumeOneTreatAfterSuccessfulFeed());
        }
      } else {
        final msg = result.rejectMent ?? '나중에 다시 시도하세요';
        _enqueueReaction(msg);
      }
    } finally {
      if (mounted) setState(() => _caringPersistBusy = false);
    }
  }

  void _onSleepToggle() async {
    if (!_caringReady || _caringPersistBusy) return;

    final prev = _caringState;
    setState(() => _caringPersistBusy = true);
    try {
      if (_caringState.isSleeping) {
        // 깨우기: 서버 선읽기 없이 로컬 스냅샷으로 벌점·회복 계산 후 순차 저장
        final result =
            await CaringActionService.wakeUp(fromLocal: _caringState);
        if (!mounted) return;
        setState(() => _caringState = result.state);
        _sleepFadeCtrl.reverse();
        _enqueueReaction(result.ment);

        final ok =
            await CaringStateService.saveStateSequential(result.state);
        if (!mounted) return;
        if (!ok) {
          setState(() => _caringState = prev);
          _sleepFadeCtrl.forward();
          _enqueueReaction(
            '저장에 실패했어요. 연결을 확인하고 다시 시도해 주세요.',
          );
        }
      } else {
        // 재우기: 저장 완료 전에는 _caringPersistBusy로 깨우기 포함 전 버튼 잠금
        final wasAwake = !_caringState.isSleeping;
        final sleeping =
            await CaringActionService.startSleep(fromLocal: _caringState);
        if (!mounted) return;

        if (wasAwake && sleeping.isSleeping) {
          setState(() => _caringState = sleeping);
          _sleepFadeCtrl.forward();
          final ment = CaringMents
              .sleepStart[Random().nextInt(CaringMents.sleepStart.length)];
          _enqueueReaction(ment);

          final ok =
              await CaringStateService.saveStateSequential(sleeping);
          if (!mounted) return;
          if (!ok) {
            setState(() => _caringState = prev);
            _sleepFadeCtrl.reverse();
            _enqueueReaction(
              '저장에 실패했어요. 연결을 확인하고 다시 시도해 주세요.',
            );
          }
        } else {
          // 이미 잠든 상태로 판정된 경우(동기화만)
          setState(() => _caringState = sleeping);
        }
      }
    } finally {
      if (mounted) setState(() => _caringPersistBusy = false);
    }
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
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  if (!isOnboarding) _buildTopBar(titleVisible: true),
                  Visibility(
                    visible: true, maintainSize: true,
                    maintainAnimation: true, maintainState: true,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: (MediaQuery.of(context).size.height * 0.38).clamp(240.0, 320.0),
                      ),
                      child: Container(
                        color: AppColors.appBg,
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTopBar(titleVisible: false),
                            FadeTransition(
                              opacity: isOnboarding ? const AlwaysStoppedAnimation(0.0) : _cardAnims[0],
                              child: _TapCard(
                                  title: 'Jobs',
                                  bigText: '채용 서비스 준비중',
                                  subtitle: '',
                                  onTap: () => widget.onTabRequested?.call(3),
                                  isLoading: false,
                                  showPrepBadge: true),
                            ),
                            FadeTransition(
                              opacity: isOnboarding ? const AlwaysStoppedAnimation(0.0) : _cardAnims[1],
                              child: _PolicyRollingCard(policies: _upcomingPolicies, index: _policyIndex,
                                  onTap: () {
                                    widget.onTabRequested?.call(2);
                                    widget.onGrowthSubTabRequested?.call(1, hiraInnerTab: 1);
                                  }),
                            ),
                            FadeTransition(
                              opacity: isOnboarding ? const AlwaysStoppedAnimation(0.0) : _cardAnims[2],
                              child: _TapCard(title: 'Weekly Book',
                                  bigText: _weeklyBook?.title ?? '이번 주 추천 책이 없어요',
                                  subtitle: (_weeklyBook != null && _weeklyBook!.author.isNotEmpty) ? '저자: ${_weeklyBook!.author}' : '',
                                  onTap: _goBookDetail, isLoading: _bookLoading),
                            ),
                            FadeTransition(
                              opacity: isOnboarding ? const AlwaysStoppedAnimation(0.0) : _cardAnims[3],
                              child: _QuizRollingCard(
                                questions: _quizRollQuestions,
                                index: _quizRollIndex,
                                fallbackBig: _quizFallbackText,
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

                  if (!isOnboarding) _buildGaugeRow(),

                  Expanded(
                    // ClipRect를 Padding 바깥에 둬야 padding이 줄인 availableH만큼
                    // ClipRect 여유 공간이 생겨 캐릭터 상단 잘림이 최소화됨
                    child: ClipRect(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _buildCharacterStack(
                            isOnboarding,
                            MediaQuery.of(context).size.height),
                      ),
                    ),
                  ),

                  Visibility(
                    visible: true, maintainSize: true,
                    maintainAnimation: true, maintainState: true,
                    child: Container(
                      color: AppColors.appBg,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: _buildBottomSection(isOnboarding: isOnboarding),
                    ),
                  ),
                ],
              ),
            ),
            // 기본·리액션 멘트는 캐릭터 위 SpeechOverlay (`_baseMsgText` / `_reactionMsgText`)
          ],
        ),
      ),
    );
  }

  // ── 게이지 행 (원형) ──
  Widget _buildGaugeRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CircleGauge(emoji: '🍖', value: _caringState.hungerInt, color: AppColors.lime),
          _CircleGauge(emoji: '😊', value: _caringState.moodInt, color: const Color(0xFFFFD54F)),
          _CircleGauge(emoji: '⚡', value: _caringState.energyInt, color: const Color(0xFF81C784)),
          _CircleGauge(emoji: '💕', value: _caringState.bondInt, color: const Color(0xFFF48FB1)),
        ],
      ),
    );
  }

  // ── 캐릭터 스택 (수면 페이드 애니메이션) ──
  //
  // [screenH]: MediaQuery 전체 화면 높이(dp).
  // 스케일 = screenH × kScreenRatio / availableH 로 계산해
  // 기기가 달라져도 캐릭터가 항상 화면 높이 대비 동일 비율로 보임.
  // (Pixel 7 Pro 892dp 기준 kScreenRatio = 0.38 → 캐릭터 ≈ 339dp)
  Widget _buildCharacterStack(bool isOnboarding, double screenH) {
    // 탭0 온보딩: 말풍선 글자만 확대 — 캐릭터 스케일은 아이들과 동일
    final tab0LayoutBoost =
        isOnboarding && widget.onboardingTab0LayoutBoost;

    return Stack(
      children: [
        Positioned.fill(
          key: _characterAreaKey,
          child: GestureDetector(
            onTap: isOnboarding || _caringState.isSleeping ? null : _onCircleTap,
            behavior: isOnboarding ? HitTestBehavior.translucent : HitTestBehavior.opaque,
            child: _dogController != null
                ? LayoutBuilder(builder: (ctx, constraints) {
                    // screenH 비율 기반 스케일 (Pixel 7 Pro 892dp 기준)
                    // scale = 목표 캐릭터 높이(screenH×0.38) / 실제 영역 높이
                    // → 기기가 달라져도 화면 대비 동일 비율로 표시
                    final availableH = constraints.maxHeight;
                    const kScreenRatio = 0.38;
                    final scale =
                        (screenH * kScreenRatio / availableH).clamp(0.85, 2.5);
                    final finalScale = scale;

                    // 캐릭터만 60dp 아래로 이동
                    // Transform.translate는 레이아웃·텍스트 위치에 영향 없음
                    Widget character = Transform.translate(
                      offset: const Offset(0, 60),
                      child: Transform.scale(
                        alignment: Alignment.bottomCenter,
                        scale: finalScale,
                        child: RiveWidget(controller: _dogController!, fit: Fit.contain),
                      ),
                    );

                    // 배고픔 낮을 때 채도 감소
                    if (!_caringState.isSleeping && _caringState.hunger < 30) {
                      character = ColorFiltered(
                        colorFilter: const ColorFilter.matrix(<double>[
                          0.7, 0.2, 0.1, 0, 0,
                          0.2, 0.7, 0.1, 0, 0,
                          0.2, 0.2, 0.6, 0, 0,
                          0,   0,   0,   1, 0,
                        ]),
                        child: character,
                      );
                    }

                    // 수면 페이드 효과 (AnimatedBuilder로 부드러운 전환)
                    return AnimatedBuilder(
                      animation: _sleepFadeAnim,
                      builder: (_, __) {
                        final t = _sleepFadeAnim.value;
                        if (t <= 0.01) return character;
                        return ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            Color.fromRGBO(0, 0, 0, 0.3 * t),
                            BlendMode.srcATop,
                          ),
                          child: Opacity(opacity: 1.0 - (0.3 * t), child: character),
                        );
                      },
                    );
                  })
                : Center(
                    child: Icon(Icons.pets_outlined, size: 80,
                        color: AppColors.textDisabled.withOpacity(0.3)),
                  ),
          ),
        ),

        // Zzz 페이드인/아웃
        if (!isOnboarding)
          Positioned(
            top: 16, right: 32,
            child: FadeTransition(
              opacity: _sleepFadeAnim,
              child: const _ZzzAnimation(),
            ),
          ),

        // 배고픔 아이콘
        if (!_caringState.isSleeping && !isOnboarding && _caringState.hunger < 30)
          Positioned(
            top: 16, left: 32,
            child: Icon(Icons.soup_kitchen_outlined, size: 28,
                color: AppColors.warning.withOpacity(0.8)),
          ),

        // 텍스트 오버레이
        Positioned.fill(
          child: IgnorePointer(
            child: LayoutBuilder(builder: (ctx, constraints) {
              // 기본·리액션: 같은 위치, 리액션 우선 (`_reactionMsgText ?? _baseMsgText`)
              final baseMsgTop = _kSpeechOverlayExtraTop;
              final displayText = isOnboarding
                  ? widget.onboardingDialogue
                  : (_reactionMsgText ?? _baseMsgText);
              final isDismissing = isOnboarding
                  ? false
                  : (_reactionMsgText != null
                      ? _isReactionMsgDismissing
                      : _isBaseMsgDismissing);
              final speechContentScale =
                  tab0LayoutBoost ? 1.5 * 0.85 * 0.9 : 1.0;
              final speechLiftDy = isOnboarding
                  ? -12.0 -
                      _kOnboardingSpeechLiftLines *
                          SpeechOverlay.lineHeightFor(
                            isOnboarding: true,
                            contentScale: speechContentScale,
                          )
                  : -12.0;
              return Stack(children: [
                Positioned(top: baseMsgTop, left: 0, right: 0,
                  child: Center(
                    child: Transform.translate(
                      offset: Offset(0, speechLiftDy),
                      child: SpeechOverlay(
                        text: displayText,
                        isDismissing: isDismissing,
                        isOnboarding: isOnboarding,
                        onboardingBoldWord:
                            isOnboarding ? widget.onboardingBoldWord : null,
                        contentScale: speechContentScale,
                      ),
                    ),
                  )),
              ]);
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar({bool titleVisible = true}) {
    if (!titleVisible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 4, bottom: 4),
      child: Row(
        children: [
          const Spacer(),
          StreamBuilder<int>(
            stream: CaringTreatService.watchTreatCount(),
            builder: (context, snap) {
              final n = snap.data ?? 0;
              return Tooltip(
                message: '받은 먹이 (공감·퀴즈로 모을 수 있어요)',
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: SizedBox(
                    height: 48,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🍖', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 2),
                          Text(
                            '$n',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.info_outline, color: AppColors.textSecondary, size: 18),
            onPressed: () => _showConceptDialog(context),
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: AppColors.textDisabled, size: 20),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection({bool isOnboarding = false}) {
    final isSleeping = _caringState.isSleeping;
    final blockCareActions =
        isSleeping || !_caringReady || _caringPersistBusy;
    final buttons = [
      _ActionBtn(
        icon: Icons.restaurant_outlined,
        label: '밥주기',
        onTap: _onFeed,
        disabled: blockCareActions,
        suppressInteractionFade: isOnboarding,
      ),
      _ActionBtn(
        icon: Icons.pets_outlined,
        label: '쓰다듬기',
        onTap: _onCircleTap,
        disabled: blockCareActions,
        suppressInteractionFade: isOnboarding,
      ),
      _ActionBtn(
        icon: isSleeping ? Icons.wb_sunny_outlined : Icons.bedtime_outlined,
        label: isSleeping ? '깨우기' : '재우기',
        onTap: _onSleepToggle,
        // 저장 FIFO 중 loadState→save가 끼어들면 밥 반영이 날아갈 수 있어 동일 잠금
        disabled: !_caringReady || _caringPersistBusy,
        suppressInteractionFade: isOnboarding,
      ),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(buttons.length, (i) {
        final anim = isOnboarding ? const AlwaysStoppedAnimation<double>(0.0) : _btnAnims[i];
        return FadeTransition(opacity: anim, child: buttons[i]);
      }),
    );
  }

  void _showConceptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("'나' 탭에 대해서", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text(
              '캐릭터의 배고픔·기분·에너지를 살피고 돌보며, 유대와 감정을 쌓는 공간이에요.',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              '공감 투표·퀴즈에서 받은 먹이는 캐릭터 점수에 잠깐 반영돼요.',
              style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              '위쪽 게이지로 상태를 볼 수 있어요. 시간이 지나면서도 변하고, 밥·쓰다듬기·잠에 따라 달라져요.',
              style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary),
            ),
            SizedBox(height: 16),
            Text('🍖 밥주기', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text(
              '배고픔을 채워줘요. 이미 배부른데 자주 주면 역효과가 날 수 있어요. 짧은 시간 안에 연속으로 주면 컨디션이 나빠질 수 있고, 너무 잦은 연속 시도 뒤에는 잠시 쉬어야 할 수 있어요.',
              style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary),
            ),
            SizedBox(height: 16),
            Text('🐾 쓰다듬기', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text(
              '쓰다듬기는 가까이 다가가는 느낌으로 기분이나 유대에 닿을 수 있어요. 한꺼번에 너무 잦으면 쉴 틈이 없어져서 오히려 컨디션이 나빠질 수 있어요. 최근 3시간 내 최대 6회까지만 긍정적으로 받아들여요.',
              style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary),
            ),
            SizedBox(height: 16),
            Text('🌙 재우기', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text(
              '충분히 재워야 에너지가 회복돼요. 너무 짧게 깨우면 오히려 기분이 나빠지고 힘들어해요.',
              style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary),
            ),
            SizedBox(height: 16),
            Text('💕 친밀도(유대)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text(
              '매일 만나고, 밥과 쓰다듬기로 유대가 올라갈 수 있어요. 기분이 낮으면 유대 상승이 줄어들 수 있어요. 오랫동안 들어오지 않으면 유대가 서서히 줄어들 수 있어요.',
              style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary),
            ),
            SizedBox(height: 16),
            Text('🔗 상태 연동', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text(
              '배고프면 기분이 더 빨리 떨어질 수 있고, 에너지가 낮으면 쓰다듬기 효과와 반응이 줄어들 수 있어요.',
              style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary),
            ),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기'))],
      ),
    );
  }
}

// ══════════════════════════════════════════════
// 원형 게이지 (RPM식 애니메이션)
// ══════════════════════════════════════════════

class _CircleGauge extends StatelessWidget {
  const _CircleGauge({
    required this.emoji,
    required this.value,
    required this.color,
  });

  final String emoji;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        final displayVal = animValue.round();
        final ratio = (animValue / 100).clamp(0.0, 1.0);

        return SizedBox(
          width: 52,
          height: 52,
          child: CustomPaint(
            painter: _CircleGaugePainter(ratio: ratio, color: color),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 14, height: 1.0)),
                  Text(
                    '$displayVal',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CircleGaugePainter extends CustomPainter {
  _CircleGaugePainter({required this.ratio, required this.color});

  final double ratio;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 3.5 * 2.5;
    final radius = size.width / 2 - strokeWidth / 2 - 1;

    // 트랙 (회색 원)
    final trackPaint = Paint()
      ..color = const Color(0x20000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // 채워진 arc
    if (ratio > 0) {
      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      const startAngle = -pi / 2; // 12시 방향 시작
      final sweepAngle = 2 * pi * ratio;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepAngle, false, fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CircleGaugePainter old) => old.ratio != ratio || old.color != color;
}

// ══════════════════════════════════════════════
// Zzz 수면 애니메이션
// ══════════════════════════════════════════════

class _ZzzAnimation extends StatefulWidget {
  const _ZzzAnimation();

  @override
  State<_ZzzAnimation> createState() => _ZzzAnimationState();
}

class _ZzzAnimationState extends State<_ZzzAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: const Text('💤', style: TextStyle(fontSize: 28)));
  }
}

// ══════════════════════════════════════════════
// 카드 위젯들
// ══════════════════════════════════════════════

class _TapCard extends StatelessWidget {
  const _TapCard({
    required this.title,
    required this.bigText,
    required this.subtitle,
    required this.onTap,
    this.isLoading = false,
    this.showPrepBadge = false,
  });
  final String title, bigText, subtitle;
  final VoidCallback onTap;
  final bool isLoading;
  final bool showPrepBadge;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Material(color: AppColors.cardPrimary, elevation: 0, borderRadius: radius,
        child: InkWell(borderRadius: radius, onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(borderRadius: radius),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Flexible(
                flex: 4,
                fit: FlexFit.tight,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onCardPrimary,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      if (showPrepBadge)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: const PrepInProgressBadge(),
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(flex: 5, fit: FlexFit.tight,
                child: isLoading
                    ? Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                        Container(height: 12, width: 100, decoration: BoxDecoration(color: AppColors.onCardPrimary.withOpacity(0.25), borderRadius: BorderRadius.circular(6))),
                        const SizedBox(height: 4),
                        Container(height: 9, width: 64, decoration: BoxDecoration(color: AppColors.onCardPrimary.withOpacity(0.15), borderRadius: BorderRadius.circular(5))),
                      ])
                    : Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                        Text(bigText, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onCardPrimary)),
                        if (subtitle.isNotEmpty)
                          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end,
                              style: TextStyle(fontSize: 10, color: AppColors.onCardPrimary.withOpacity(0.7))),
                      ]),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.onCardPrimary, size: 20),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PolicyRollingCard extends StatelessWidget {
  const _PolicyRollingCard({required this.policies, required this.index, required this.onTap});
  final List<Map<String, String>> policies;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    String big = '예정된 변경 없음', sub = '';
    if (policies.isNotEmpty) {
      final p = policies[index.clamp(0, policies.length - 1)];
      big = p['title'] ?? ''; sub = '시행일: ${p['date']} (${p['dday']})';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Material(color: AppColors.cardPrimary, elevation: 0, borderRadius: radius,
        child: InkWell(borderRadius: radius, onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(borderRadius: radius),
            child: LayoutBuilder(builder: (ctx, constraints) {
              final rightMaxW = (constraints.maxWidth * 0.55).clamp(0.0, 200.0);
              return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(child: Text('Policy Updates', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800,
                    color: AppColors.onCardPrimary, letterSpacing: -0.5, height: 1.1))),
                const SizedBox(width: 8),
                ClipRect(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: rightMaxW),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    layoutBuilder: (current, previous) => Stack(alignment: Alignment.centerRight,
                        children: [...previous, if (current != null) current]),
                    transitionBuilder: (child, animation) {
                      final leaving = animation.status == AnimationStatus.reverse || animation.status == AnimationStatus.dismissed;
                      return SlideTransition(
                        position: Tween<Offset>(begin: Offset(0, leaving ? -1.0 : 1.0), end: Offset.zero)
                            .animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
                        child: FadeTransition(opacity: animation, child: child));
                    },
                    child: SizedBox(key: ValueKey(big), width: rightMaxW,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                        Text(big, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onCardPrimary)),
                        if (sub.isNotEmpty)
                          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end,
                              style: TextStyle(fontSize: 10, color: AppColors.onCardPrimary.withOpacity(0.7))),
                      ])),
                  ),
                )),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.onCardPrimary, size: 20),
              ]);
            }),
          ),
        ),
      ),
    );
  }
}

/// Daily Quiz 카드 — 오른쪽 레이아웃·롤링은 [_PolicyRollingCard]와 동일 (`LayoutBuilder`·`rightMaxW`·`ClipRect`)
class _QuizRollingCard extends StatelessWidget {
  const _QuizRollingCard({
    required this.questions,
    required this.index,
    required this.fallbackBig,
    required this.onTap,
  });

  final List<String> questions;
  final int index;
  final String fallbackBig;
  final VoidCallback onTap;

  static const String _subtitle = '터치해서 풀기';

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    final hasRoll = questions.length > 1;
    final big = questions.isEmpty
        ? fallbackBig
        : questions[index.clamp(0, questions.length - 1)];

    Widget rightColumn(String line) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.onCardPrimary,
            ),
          ),
          Text(
            _subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.onCardPrimary.withOpacity(0.7),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Material(
        color: AppColors.cardPrimary,
        elevation: 0,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(borderRadius: radius),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final rightMaxW =
                    (constraints.maxWidth * 0.55).clamp(0.0, 200.0);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Daily Quiz',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onCardPrimary,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ClipRect(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: rightMaxW),
                        child: hasRoll
                            ? AnimatedSwitcher(
                                duration: const Duration(milliseconds: 350),
                                layoutBuilder: (current, previous) => Stack(
                                  alignment: Alignment.centerRight,
                                  children: [
                                    ...previous,
                                    if (current != null) current,
                                  ],
                                ),
                                transitionBuilder: (child, animation) {
                                  final leaving =
                                      animation.status ==
                                              AnimationStatus.reverse ||
                                          animation.status ==
                                              AnimationStatus.dismissed;
                                  return SlideTransition(
                                    position: Tween<Offset>(
                                      begin: Offset(0, leaving ? -1.0 : 1.0),
                                      end: Offset.zero,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeInOut,
                                      ),
                                    ),
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  );
                                },
                                child: SizedBox(
                                  key: ValueKey<String>(big),
                                  width: rightMaxW,
                                  child: rightColumn(big),
                                ),
                              )
                            : SizedBox(
                                width: rightMaxW,
                                child: rightColumn(big),
                              ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.onCardPrimary,
                      size: 20,
                    ),
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

// ══════════════════════════════════════════════
// 액션 버튼 (바운스 터치 반응)
// ══════════════════════════════════════════════

/// 비활성 시 시각 불투명도 (활성 1.0과 보간)
const double _kActionBtnDisabledOpacity = 0.5;

class _ActionBtn extends StatefulWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.disabled = false,
    /// true면 활성/비활성 페이드 없음(즉시). 온보딩 시 바깥 [FadeTransition]과 곱연산 이중 페이드 완화.
    this.suppressInteractionFade = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool disabled;
  final bool suppressInteractionFade;

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _scaleCtrl.dispose(); super.dispose(); }

  void _onTapDown(TapDownDetails _) {
    if (!widget.disabled) _scaleCtrl.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _scaleCtrl.reverse();
    if (!widget.disabled) widget.onTap();
  }

  void _onTapCancel() => _scaleCtrl.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: LayoutBuilder(builder: (ctx, _) {
          final screenW = MediaQuery.of(ctx).size.width;
          final btnSize = (screenW * 0.13).clamp(44.0, 64.0);
          final iconSize = (btnSize * 0.43).clamp(20.0, 28.0);
          final bgColor = widget.disabled ? AppColors.disabledBg : AppColors.accent;
          final fgColor = widget.disabled ? AppColors.disabledText : AppColors.onAccent;
          final labelColor = widget.disabled ? AppColors.textDisabled : AppColors.textPrimary;

          final targetOpacity =
              widget.disabled ? _kActionBtnDisabledOpacity : 1.0;
          final fadeDuration = widget.suppressInteractionFade
              ? Duration.zero
              : const Duration(milliseconds: 220);

          return AnimatedOpacity(
            opacity: targetOpacity,
            duration: fadeDuration,
            curve: Curves.easeInOut,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: btnSize,
                  height: btnSize,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, color: fgColor, size: iconSize),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: labelColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
