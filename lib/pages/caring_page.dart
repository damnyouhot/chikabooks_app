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
import '../pages/ebook/ebook_detail_page.dart';
import 'settings/settings_page.dart';

// ── 디자인 컬러 팔레트 ──
const _colorAccent = Color(0xFFF7CBCA);
const _colorText = Color(0xFF5D6B6B);
const _colorBg = Color(0xFFF1F7F7);

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

  // ── 말풍선 ──
  String? _currentSpeech;
  bool _isDismissingSpeech = false;

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
      await CaringStateService.loadState();
      await BondScoreService.applyCenterGravity();
      // 구인 요약
      final jobService = JobService();
      final jobData = await jobService.getRecentJobsSummary();
      final jobCount = jobData['count'] ?? 0;
      final clinicName = jobData['clinicName'] ?? '';

      // 임박 제도 변경 (더미 - HiraUpdateService 연동 필요)
      final policies = [
        {'title': '2026 스케일링 급여 개정', 'dday': 'D-12', 'date': '3월 1일'},
        {'title': '치주질환 급여 인정 기준 변경', 'dday': 'D-21', 'date': '3월 10일'},
        {'title': '근관치료 행위 산정 지침 개정', 'dday': 'D-26', 'date': '3월 15일'},
      ];

      // 이주의 책 (EbookService 재사용)
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

  /// 이주의 책 상세 페이지 이동
  void _goBookDetail() {
    if (_weeklyBook == null) {
      widget.onTabRequested?.call(2); // 책 없으면 성장하기 탭
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EbookDetailPage(ebook: _weeklyBook!)),
    );
  }

  /// 캐릭터 터치
  void _onCircleTap() async {
    _tapTrigger?.fire();

    // tryTouch 호출: 쿨타임(하루 3회) 체크
    final result = await CaringActionService.tryTouch();
    if (!mounted) return;

    // 멘트: tryTouch 결과 또는 중립 문구
    final phrase = result.ment.isNotEmpty
        ? result.ment
        : _neutralPhrases[Random().nextInt(_neutralPhrases.length)];

    setState(() {
      _currentSpeech = phrase;
      _isDismissingSpeech = false;
    });

    // 실제 점수가 있을 때만 플러스 텍스트 표시 (쿨타임 중이면 0.0)
    if (result.bondDelta > 0) {
      _showFloatingDelta(result.bondDelta);
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isDismissingSpeech = true);
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

  void _showFloatingDelta(double delta) {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offsetX = (size.width / 2) + (Random().nextDouble() * 60 - 30);
    final offsetY = (size.height * 0.65) + (Random().nextDouble() * 30 - 15);
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
                      fontSize: 18,
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _colorBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 캐릭터 영역: 카드 아래 ~ 버튼 위
    // safeBottom: BottomNavBar 포함 하단 여백 확보
    final safeBottom = _bottomH + 8;

    return Scaffold(
      backgroundColor: _colorBg,
      body: Stack(
        children: [
          // 배경 (터치 불가)
          IgnorePointer(
            ignoring: true,
            child: Positioned.fill(child: Container(color: _colorBg)),
          ),

          // ── 캐릭터 ──
          // 4번째 카드 아래 ~ 하단 버튼 위 사이에 배치, 4.4배 확대
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
                        const scale = 4.4;
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

          // 말풍선
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

          // 하단 버튼들 (먼저 배치해야 높이 측정 가능)
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

          // 상단 카드 4개 (Stack 최상단)
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
                    // ① 구인 → 도전하기 탭(3)
                    _TapCard(
                      title: '📍 내 주변 신규 구인',
                      bigText: _jobsSummary,
                      subtitle: _jobsSub,
                      onTap: () => widget.onTabRequested?.call(3),
                    ),
                    // ② 임박 제도 변경 → 성장하기 탭(2)
                    _PolicyRollingCard(
                      policies: _upcomingPolicies,
                      index: _policyIndex,
                      onTap: () => widget.onTabRequested?.call(2),
                    ),
                    // ③ 이주의 책 → 책 상세 페이지 (유일하게 새 화면)
                    _TapCard(
                      title: '📖 이주의 책',
                      bigText: _weeklyBook?.title ?? '이번 주 추천 책이 없어요',
                      subtitle: '',
                      onTap: _goBookDetail,
                    ),
                    // ④ 오늘의 1문제 → 성장하기 탭(2)
                    _TapCard(
                      title: '🧠 오늘의 1문제',
                      bigText: _quizSummary,
                      subtitle: '터치해서 풀기',
                      onTap: () => widget.onTabRequested?.call(2),
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

  /// 상단 바
  Widget _buildTopBar() {
    return Padding(
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
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
            },
          ),
        ],
      ),
    );
  }

  /// 하단 버튼 섹션 (아이콘+텍스트 구조 복원)
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

  void _onFeed() async {
    final result = await CaringActionService.tryFeed();
    if (mounted) {
      final message =
          result.success
              ? (result.ment ?? '밥을 줬어요')
              : (result.rejectMent ?? '나중에 다시 시도하세요');

      // 스낵바 대신 기존 말풍선 형태로 표시
      setState(() {
        _currentSpeech = message;
        _isDismissingSpeech = false;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isDismissingSpeech = true);
      });
      Future.delayed(const Duration(milliseconds: 2300), () {
        if (mounted) {
          setState(() {
            _currentSpeech = null;
            _isDismissingSpeech = false;
          });
        }
      });

      if (result.success) _bootstrap();
    }
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

/// 일반 정보 카드 (터치 피드백 포함)
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
                      // 타이틀
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // 본문 + 세부설명 (같은 줄, 우측 정렬)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              bigText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black45,
                              ),
                            ),
                          ],
                        ],
                      ),
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
/// 타이틀("🏥 임박 제도 변경")은 고정, big+sub 내용만 AnimatedSwitcher
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
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ 타이틀은 AnimatedSwitcher 밖 (고정)
                      const Text(
                        '🏥 임박 제도 변경',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // 내용만 롤링 (이전: 위로 나감 / 새것: 아래에서 올라옴)
                      ClipRect(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          layoutBuilder:
                              (current, previous) => Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  ...previous,
                                  if (current != null) current,
                                ],
                              ),
                          transitionBuilder: (child, animation) {
                            // animation: 진입 시 0→1, 퇴장 시 1→0
                            // 퇴장(reverse) → 위로 나감, 진입(forward) → 아래에서 올라옴
                            final isLeaving =
                                animation.status == AnimationStatus.reverse ||
                                animation.status == AnimationStatus.dismissed;
                            final offsetTween = Tween<Offset>(
                              begin:
                                  isLeaving
                                      ? const Offset(0, -1.0) // 퇴장: 위로
                                      : const Offset(0, 1.0), // 진입: 아래에서
                              end: Offset.zero,
                            );
                            return SlideTransition(
                              position: offsetTween.animate(
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
                            key: ValueKey(big),
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                      ),
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

/// 하단 액션 버튼 (아이콘 + 텍스트, 원래 디자인 복원)
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
