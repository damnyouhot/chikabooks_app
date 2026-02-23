import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';
import '../services/caring_state_service.dart';
import '../services/bond_score_service.dart';
import '../services/caring_action_service.dart';
import '../services/job_service.dart';
import '../services/ebook_service.dart';
import '../models/ebook.dart';
import '../widgets/speech_overlay.dart';
import '../widgets/diary_input_sheet.dart';
import '../widgets/user_goal_sheet.dart';
import 'settings/settings_page.dart';

/// 돌보기(1탭) — 4개 정보 카드 + 캐릭터 + 4버튼
class CaringPage extends StatefulWidget {
  final ValueChanged<int>? onTabRequested;

  const CaringPage({super.key, this.onTabRequested});

  @override
  State<CaringPage> createState() => _CaringPageState();
}

class _CaringPageState extends State<CaringPage>
    with SingleTickerProviderStateMixin {
  // ── 상태 ──
  bool _loading = true;
  bool _hasGreetedToday = false;

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
  double _topH = 260;
  double _bottomH = 140;

  // ── 말풍선 ──
  String? _currentSpeech;
  bool _isDismissingSpeech = false;
  final List<Widget> _floatingDeltas = [];

  // ── Rive ──
  Artboard? _dogArtboard;
  StateMachineController? _dogStateMachine;
  SMITrigger? _tapTrigger;

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
    CaringActionService.dailySettle();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _policyTimer?.cancel();
    _dogStateMachine?.dispose();
    super.dispose();
  }

  /// Rive 파일 로드
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

  /// 데이터 로드
  Future<void> _bootstrap() async {
    setState(() => _loading = true);

    try {
      // 1. 기존 상태 로드
      final state = await CaringStateService.loadState();
      await BondScoreService.applyCenterGravity();
      final greeted = CaringStateService.hasGreetedToday(state);

      // 2. 구인 요약 (JobService 재사용)
      final jobService = JobService();
      final jobData = await jobService.getRecentJobsSummary();
      final jobCount = jobData['count'] ?? 0;
      final clinicName = jobData['clinicName'] ?? '';

      // 3. 임박 제도 변경 (더미 데이터 - HiraUpdateService 연동 필요)
      final policies = [
        {'title': '2026 스케일링 급여 개정', 'dday': 'D-12', 'date': '3월 1일'},
        {'title': '치주질환 급여 인정 기준 변경', 'dday': 'D-21', 'date': '3월 10일'},
        {'title': '근관치료 행위 산정 지침 개정', 'dday': 'D-26', 'date': '3월 15일'},
      ];

      // 4. 이주의 책 (EbookService 재사용)
      final ebookService = EbookService();
      Ebook? featuredBook;
      try {
        final ebooks = await ebookService.watchEbooks().first;
        if (ebooks.isNotEmpty) {
          featuredBook = ebooks.first; // 첫 번째 책을 featured로
        }
      } catch (e) {
        debugPrint('⚠️ 이주의 책 로드 실패: $e');
      }

      // 5. 오늘의 퀴즈 (더미 - QuizTodayPage 데이터 연동 필요)
      final quizText = '치주낭 측정 시 올바른 탐침 방향은?';

      setState(() {
        _hasGreetedToday = greeted;
        _jobsSummary = jobCount > 0 ? '오늘 새로 올라온 $jobCount건' : '새로운 구인 공고가 없어요';
        _jobsSub = jobCount > 0 && clinicName.isNotEmpty ? clinicName : '';
        _upcomingPolicies = policies;
        _weeklyBook = featuredBook;
        _quizSummary = quizText;
        _loading = false;
      });

      _startPolicyRolling();
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    } catch (e) {
      debugPrint('❌ 데이터 로드 실패: $e');
      setState(() => _loading = false);
    }
  }

  /// 제도 변경 3초 롤링
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

  /// 높이 측정
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

  /// Route 이동
  void _go(String route) {
    Navigator.of(context).pushNamed(route);
  }

  /// 캐릭터 터치
  void _onCircleTap() {
    _tapTrigger?.fire();

    final score = Random().nextInt(3) + 1;
    final phrase = _neutralPhrases[Random().nextInt(_neutralPhrases.length)];

    setState(() {
      _currentSpeech = phrase;
      _isDismissingSpeech = false;
    });

    _showFloatingDelta(score);

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isDismissingSpeech = true;
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 2300), () {
      if (mounted) {
        setState(() {
          _currentSpeech = null;
          _isDismissingSpeech = false;
        });
      }
    });
  }

  void _showFloatingDelta(int delta) {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offsetX = (size.width / 2) + (Random().nextDouble() * 60 - 30);
    final offsetY = (size.height * 0.5) + (Random().nextDouble() * 40 - 20);

    final entry = OverlayEntry(
      builder:
          (ctx) => Positioned(
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
                    child: Text(
                      '+$delta',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF7CBCA).withOpacity(1.0 - value),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 1500), () {
      entry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screenH = MediaQuery.of(context).size.height;
    final top = _topH;
    final bottom = _bottomH;

    final available = screenH - top - bottom;
    final minSpace = 180.0;
    final safeBottom =
        available < minSpace
            ? (screenH - top - minSpace).clamp(0.0, screenH)
            : bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F7F7),
      body: Stack(
        children: [
          // 배경
          IgnorePointer(
            ignoring: true,
            child: Positioned.fill(
              child: Container(color: const Color(0xFFF1F7F7)),
            ),
          ),

          // 캐릭터 (contain으로 잘림 방지)
          Positioned.fill(
            top: top,
            bottom: safeBottom,
            child: Center(
              child: GestureDetector(
                onTap: _onCircleTap,
                child:
                    _dogArtboard != null
                        ? Rive(
                          artboard: _dogArtboard!,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                        )
                        : const CircularProgressIndicator(),
              ),
            ),
          ),

          // 말풍선
          Positioned(
            bottom: _bottomH + 10,
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

          // 떠오르는 수치들
          ..._floatingDeltas,

          // 상단 카드 4개
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                key: _topKey,
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 상단 바
                    _buildTopBar(),

                    const SizedBox(height: 4),

                    // ① 구인 카드
                    _TapCard(
                      title: '📍 내 주변 신규 구인',
                      bigText: _jobsSummary,
                      subtitle: _jobsSub,
                      onTap: () => _go('/jobs'),
                    ),

                    // ② 임박 제도 변경 (롤링)
                    _PolicyRollingCard(
                      policies: _upcomingPolicies,
                      index: _policyIndex,
                      onTap: () => _go('/policy'),
                    ),

                    // ③ 이주의 책
                    _TapCard(
                      title: '📖 이주의 책',
                      bigText: _weeklyBook?.title ?? '이번 주 추천 책이 없어요',
                      subtitle: _weeklyBook?.author ?? '',
                      onTap: () => _go('/books'),
                    ),

                    // ④ 오늘의 1문제
                    _TapCard(
                      title: '🧠 오늘의 1문제',
                      bigText: _quizSummary,
                      subtitle: '터치해서 풀기',
                      onTap: () => _go('/quiz'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 하단 버튼들
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                key: _bottomKey,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _buildBottomSection(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 상단 바
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.info_outline,
              color: const Color(0xFF5D6B6B).withOpacity(0.5),
              size: 18,
            ),
            onPressed: () => _showConceptDialog(context),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: const Color(0xFF5D6B6B).withOpacity(0.4),
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

  /// 하단 버튼 섹션
  Widget _buildBottomSection() {
    return Row(
      children: [
        Expanded(child: _BottomBtn('밥먹기', _onFeed)),
        const SizedBox(width: 10),
        Expanded(child: _BottomBtn('사랑하기', _onLove)),
        const SizedBox(width: 10),
        Expanded(child: _BottomBtn('기록하기', _onDiary)),
        const SizedBox(width: 10),
        Expanded(child: _BottomBtn('목표', _onGoal)),
      ],
    );
  }

  void _onFeed() async {
    final result = await CaringActionService.tryFeed();
    if (mounted) {
      final message = result.success 
          ? (result.ment ?? '밥을 줬어요')
          : (result.rejectMent ?? '나중에 다시 시도하세요');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      
      if (result.success) {
        _bootstrap();
      }
    }
  }

  void _onLove() async {
    _onCircleTap(); // 터치와 동일
  }

  void _onDiary() {
    DiaryInputSheet.show(context, (text) async {
      // 일기 저장 후 리프레시
      _bootstrap();
    });
  }

  void _onGoal() {
    UserGoalSheet.show(context);
  }

  void _showConceptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text(
              "'나' 탭에 대해서",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            content: const SingleChildScrollView(
              child: Text(
                "📱 캐릭터\n"
                "• 터치하면 작은 교감이 쌓입니다.\n"
                "• 애정 수치가 너무 낮거나 높지 않게 조절하세요.\n\n"
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
                "• 교감이 쌓일수록 결이 깊어져요.\n"
                "• 결 점수는 앱 사용과 교감에 따라 자동으로 조정됩니다.",
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

/// 일반 카드
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
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bigText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.black45,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 임박 제도 변경 롤링 카드
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

    String title = '🏥 임박 제도 변경';
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
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: Column(
                      key: ValueKey(big),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          big,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (sub.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.black45,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 하단 버튼
class _BottomBtn extends StatelessWidget {
  const _BottomBtn(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Material(
      color: Colors.white,
      elevation: 1,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
