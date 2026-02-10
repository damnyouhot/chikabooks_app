import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/activity_log_service.dart';
import '../services/bond_score_service.dart';
import '../services/partner_dialogue_service.dart';
import '../services/store_service.dart';
import '../services/user_action_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/aura_circle_widget.dart';
import 'emotion_record_page.dart';
import 'settings/communion_profile_page.dart';

/// 돌보기(홈) 탭 — 오라 원 + 세그먼트(오늘/함께)
///
/// 오늘: 중앙 오라 원 + 미니멀 액션 버튼
/// 함께: 결 탭(교류)으로의 안내
class CaringPage extends StatefulWidget {
  /// 결 탭으로 이동하기 위한 콜백 (MyHome에서 주입)
  final VoidCallback? onNavigateToBond;

  const CaringPage({super.key, this.onNavigateToBond});

  @override
  State<CaringPage> createState() => _CaringPageState();
}

class _CaringPageState extends State<CaringPage> {
  // ── 세그먼트 ──
  int _segmentIndex = 0; // 0: 오늘, 1: 함께

  // ── 결 점수 + 텍스트 ──
  double _bondScore = 50.0;
  String _defaultText = '오늘도 여기.';
  String? _feedbackText; // 즉시 피드백 (3~5초)

  // ── 파트너 ──
  String? _partnerGroupId;
  String? _ambientLine;

  // ── 기본 정서 문장 풀 ──
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
    _defaultText = _neutralPhrases[Random().nextInt(_neutralPhrases.length)];
    _loadData();
  }

  /// 결 점수, 파트너 상태, 중심회귀 등 초기 로드
  Future<void> _loadData() async {
    try {
      final score = await UserProfileService.getBondScore();
      await BondScoreService.applyCenterGravity();
      final groupId = await UserProfileService.getPartnerGroupId();

      String? line;
      if (groupId != null) {
        final logs = await ActivityLogService.getUnreadLogs(groupId);
        line = PartnerDialogueService.generateAmbientLine(logs);
      }

      if (mounted) {
        setState(() {
          _bondScore = score;
          _partnerGroupId = groupId;
          _ambientLine = line;
        });
      }
    } catch (_) {}
  }

  /// 즉시 피드백 표시 (3초 후 자동 해제)
  void _showFeedback(String text) {
    setState(() => _feedbackText = text);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _feedbackText = null);
    });
  }

  // ── 액션 핸들러 ──

  void _onCheerUp() async {
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EmotionRecordPage()),
    );
    if (success == true && mounted) {
      _showFeedback('마음을 기록했어.');
    }
  }

  void _onFeed() async {
    final msg = await UserActionService.feed();
    if (mounted) _showFeedback(msg);
  }

  void _onCheckIn() async {
    final msg = await UserActionService.dailyCheckIn();
    if (mounted) _showFeedback(msg);
  }

  void _onDressUp() {
    final storeService = context.read<StoreService>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FutureBuilder(
          future: storeService.fetchMyItems(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    '보유한 아이템이 없습니다.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }
            final myItems = snapshot.data!;
            return GridView.builder(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: myItems.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Tooltip(
                    message: "아이템 해제",
                    child: InkWell(
                      onTap: () {
                        UserActionService.equipSkin(null);
                        Navigator.pop(context);
                      },
                      child: const CircleAvatar(
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.do_not_disturb_on,
                            color: Colors.white),
                      ),
                    ),
                  );
                }
                final item = myItems[index - 1];
                return Tooltip(
                  message: item.name,
                  child: InkWell(
                    onTap: () {
                      UserActionService.equipSkin(item.id);
                      Navigator.pop(context);
                    },
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(item.imageUrl),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _onCircleTap() {
    _showFeedback(
      _neutralPhrases[Random().nextInt(_neutralPhrases.length)],
    );
  }

  /// 길게 누르기 → 상태 요약 오버레이
  void _onCircleLongPress() {
    showDialog(
      context: context,
      barrierColor: Colors.black12,
      builder: (_) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 48),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '결 ${_bondScore.toInt()}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  color: Color(0xFF1E88E5),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                BondScoreService.scoreLabel(_bondScore),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
              if (_partnerGroupId != null) ...[
                const SizedBox(height: 12),
                Text(
                  '파트너 그룹 활성',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        // 배경: 흰색 → 아주 연한 블루 그라데이션
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFCFCFF),
              Color(0xFFF4F6FB),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── 상단 바: 설정 아이콘만 ──
              _buildTopBar(),

              // ── 세그먼트 컨트롤: 오늘 / 함께 ──
              _buildSegmentControl(),

              const SizedBox(height: 8),

              // ── 콘텐츠 ──
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _segmentIndex == 0
                      ? _buildTodaySegment()
                      : _buildTogetherSegment(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 상단 바 ──
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: Icon(Icons.settings_outlined,
                color: Colors.grey[400], size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CommunionProfilePage()),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── 세그먼트 컨트롤 ──
  Widget _buildSegmentControl() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 60),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _buildSegmentButton(0, '오늘'),
          _buildSegmentButton(1, '함께'),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(int index, String label) {
    final isSelected = _segmentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _segmentIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(17),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? const Color(0xFF424242) : Colors.grey[400],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // "오늘" 세그먼트 (원래 그대로)
  // ═══════════════════════════════════════════════

  Widget _buildTodaySegment() {
    final displayText = _feedbackText ?? _ambientLine ?? _defaultText;

    return Column(
      key: const ValueKey('today'),
      children: [
        // ── 중앙 오라 원 ──
        Expanded(
          child: Center(
            child: AuraCircleWidget(
              bondScore: _bondScore,
              mainText: displayText,
              subText: '결 ${_bondScore.toInt()}',
              onTap: _onCircleTap,
              onLongPress: _onCircleLongPress,
            ),
          ),
        ),

        // ── 액션 버튼 (축소/모노톤) ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMiniAction(Icons.edit_note_outlined, '응원', _onCheerUp),
              _buildMiniAction(Icons.local_dining_outlined, '기록', _onFeed),
              _buildMiniAction(
                  Icons.check_circle_outline, '출석', _onCheckIn),
              _buildMiniAction(Icons.palette_outlined, '꾸미기', _onDressUp),
            ],
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  /// 미니 액션 버튼 (축소 + 모노톤)
  Widget _buildMiniAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFF5F5F8),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.grey[500], size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // "함께" 세그먼트 → 결 탭으로 안내
  // ═══════════════════════════════════════════════

  Widget _buildTogetherSegment() {
    return Center(
      key: const ValueKey('together'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 일러스트 대용 아이콘
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF00E5FF).withOpacity(0.12),
                    const Color(0xFF1E88E5).withOpacity(0.10),
                  ],
                ),
              ),
              child: Icon(
                Icons.all_inclusive,
                size: 32,
                color: const Color(0xFF1E88E5).withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              '함께하는 공간',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color(0xFF424242),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '한 줄 멘트, 파트너, 공감 등\n교류 기능은 결 탭에서 만나보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[450],
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),

            // 결 탭으로 이동 버튼
            GestureDetector(
              onTap: widget.onNavigateToBond,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9E9EBE).withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00E5FF), Color(0xFF1E88E5)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00BCD4).withOpacity(0.15),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      '결 탭으로 이동',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF555566),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_forward_ios,
                        size: 12, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
