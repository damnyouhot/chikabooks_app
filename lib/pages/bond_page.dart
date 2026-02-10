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
import '../widgets/daily_wall_sheet.dart';
import '../widgets/partner_summary_card.dart';
import '../widgets/profile_gate_sheet.dart';
import 'emotion_record_page.dart';
import 'partner_page.dart';
import 'settings/communion_profile_page.dart';

/// 결 탭 — "오늘" / "함께" 세그먼트
///
/// 오늘: 중앙 오라 원 + 결 수치 + 미니멀 액션 버튼
/// 함께: 오늘의 한 문장 + 파트너 소식
class BondPage extends StatefulWidget {
  const BondPage({super.key});

  @override
  State<BondPage> createState() => _BondPageState();
}

class _BondPageState extends State<BondPage> {
  // ── 세그먼트 ──
  int _segmentIndex = 0; // 0: 오늘, 1: 함께

  // ── 결 점수 + 텍스트 ──
  double _bondScore = 50.0;
  String _defaultText = '오늘도 여기.';
  String? _feedbackText;

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
                    message: '아이템 해제',
                    child: InkWell(
                      onTap: () {
                        UserActionService.equipSkin(null);
                        Navigator.pop(context);
                      },
                      child: const CircleAvatar(
                        backgroundColor: Colors.grey,
                        child:
                            Icon(Icons.do_not_disturb_on, color: Colors.white),
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
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              if (_partnerGroupId != null) ...[
                const SizedBox(height: 12),
                Text(
                  '파트너 그룹 활성',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openDailyWall() async {
    final hasProfile = await UserProfileService.hasBasicProfile();
    if (!mounted) return;

    if (!hasProfile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ProfileGateSheet(
          onComplete: () {
            Navigator.pop(context);
            if (mounted) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const DailyWallSheet(),
              );
            }
          },
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const DailyWallSheet(),
      );
    }
  }

  void _openPartner() async {
    final hasProfile = await UserProfileService.hasBasicProfile();
    if (!mounted) return;

    if (!hasProfile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ProfileGateSheet(
          onComplete: () {
            Navigator.pop(context);
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PartnerPage()),
              );
            }
          },
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PartnerPage()),
      );
    }
  }

  // ═══════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
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
              _buildTopBar(),
              _buildSegmentControl(),
              const SizedBox(height: 8),
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
  // "오늘" 세그먼트
  // ═══════════════════════════════════════════════

  Widget _buildTodaySegment() {
    final displayText = _feedbackText ?? _ambientLine ?? _defaultText;

    return Column(
      key: const ValueKey('today'),
      children: [
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
  // "함께" 세그먼트
  // ═══════════════════════════════════════════════

  Widget _buildTogetherSegment() {
    return SingleChildScrollView(
      key: const ValueKey('together'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          _buildFeatureCard(
            icon: '✍️',
            title: '오늘의 한 문장',
            subtitle: '오늘의 기분을 한 문장으로 남겨보세요.',
            onTap: _openDailyWall,
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            icon: '🤝',
            title: '파트너',
            subtitle: '함께하는 동행을 만나보세요.',
            onTap: _openPartner,
          ),
          if (_partnerGroupId != null) ...[
            const SizedBox(height: 16),
            PartnerSummaryCard(groupId: _partnerGroupId!),
          ],
          if (_ambientLine != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _ambientLine!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF424242),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[300], size: 20),
          ],
        ),
      ),
    );
  }
}

