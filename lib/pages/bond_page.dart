import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/weekly_goal.dart';
import '../models/weekly_stamp.dart';
import '../services/user_profile_service.dart';
import '../services/weekly_goal_service.dart';
import '../services/weekly_stamp_service.dart';
import '../widgets/bond_post_sheet.dart';
import '../widgets/bond_post_card.dart';
import '../widgets/profile_gate_sheet.dart';
import '../data/goal_suggestions.dart';
import 'settings/communion_profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ─────────────────────────────────────────────────
/// 결 탭 — 피드형 (펼쳐진 콘텐츠 스크롤)
/// ─────────────────────────────────────────────────
///
/// 섹션 순서:
///   A) 요약 헤더 (결 점수 + 파트너 아바타 + 이번 주 목표 한 줄)
///   B) 오늘을 나누기 + 리액션 (펼쳐진 카드)
///   C) 파트너 활동 요약 (사람별)
///   D) 공감 투표 (펼쳐진 질문 + 선택지)
///   E) 이번 주 목표 진행률 (나 + 파트너)

// ── 디자인 팔레트 (1탭과 통일) ──
const _kAccent = Color(0xFFF7CBCA);
const _kText = Color(0xFF5D6B6B);
const _kBg = Color(0xFFF1F7F7);
const _kShadow1 = Color(0xFFDDD3D8);
const _kShadow2 = Color(0xFFD5E5E5);
const _kCardBg = Colors.white;

class BondPage extends StatefulWidget {
  const BondPage({super.key});

  @override
  State<BondPage> createState() => _BondPageState();
}

class _BondPageState extends State<BondPage> {
  // ── 데이터 ──
  double _bondScore = 50.0;
  String? _partnerGroupId; // 추후 파트너 데이터 연결용

  // ── 공감 투표 (더미) ──
  int? _selectedPollOption;

  // ── 결 파트 확장 ──
  bool _isBondExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final score = await UserProfileService.getBondScore();
      final groupId = await UserProfileService.getPartnerGroupId();
      if (mounted) {
        setState(() {
          _bondScore = score;
          _partnerGroupId = groupId;
        });
      }
    } catch (_) {}
  }

  // ── 한줄 멘트 작성 ──
  void _openDailyWallWrite() async {
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
                builder: (_) => const BondPostSheet(),
              ).then((_) => _loadData());
            }
          },
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const BondPostSheet(),
      ).then((_) => _loadData());
    }
  }

  // ═══════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── 상단 타이틀 바 ──
            SliverToBoxAdapter(child: _buildTopBar()),

            // ── 섹션 A: 요약 헤더 ──
            SliverToBoxAdapter(child: _buildSectionA()),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── 스탬프: 이번 주 우리 스탬프 (확장 시에만) ──
            if (_isBondExpanded)
              SliverToBoxAdapter(child: _buildStampSection()),

            SliverToBoxAdapter(child: SizedBox(height: _isBondExpanded ? 16 : 0)),

            // ── 섹션 B: 오늘을 나누기 (펼쳐진 카드) ──
            SliverToBoxAdapter(child: _buildSectionB()),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── 섹션 C: 파트너 활동 요약 ──
            SliverToBoxAdapter(child: _buildSectionC()),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── 섹션 D: 공감 투표 ──
            SliverToBoxAdapter(child: _buildSectionD()),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
    );
  }

  // ─────────────────────────────────────────
  // 상단 바
  // ─────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          const Text(
            '결',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _kText,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CommunionProfilePage(),
              ),
            ),
            child: Icon(
              Icons.settings_outlined,
              color: _kText.withOpacity(0.4),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // [섹션 A] 요약 헤더
  // ─────────────────────────────────────────

  Widget _buildSectionA() {
    return GestureDetector(
      onTap: () => setState(() => _isBondExpanded = !_isBondExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(),
        child: Column(
          children: [
            // 결 점수 + 파트너 아바타
            Row(
              children: [
                // 결 점수 링
                _buildBondRing(),
                const SizedBox(width: 16),
                // 결 점수 텍스트
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '결 ${_bondScore.toInt()}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w300,
                          color: _kText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '함께 쌓아가는 교감',
                        style: TextStyle(
                          fontSize: 12,
                          color: _kText.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                // 파트너 아바타 3명
                _buildPartnerAvatars(),
                Icon(
                  _isBondExpanded ? Icons.expand_less : Icons.expand_more,
                  color: _kText.withOpacity(0.5),
                ),
              ],
            ),

            // 확장 시 파트너 상세 + 스탬프
            if (_isBondExpanded) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 0.5,
                color: _kShadow2.withOpacity(0.6),
              ),
              const SizedBox(height: 16),
              _buildExpandedPartnerDetails(),
            ],

            // 축약 시 이번 주 목표 미니 요약
            if (!_isBondExpanded) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 0.5,
                color: _kShadow2.withOpacity(0.6),
              ),
              const SizedBox(height: 12),
              _buildWeeklyGoalMini(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedPartnerDetails() {
    // 더미 파트너 (실제 연결 시 교체)
    final partners = [
      {'name': '민지', 'activity': '3', 'goals': '5/7'},
      {'name': '지은', 'activity': '1', 'goals': '2/5'},
      {'name': '현수', 'activity': '0', 'goals': '아직 없음'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '파트너 상세',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _kText,
          ),
        ),
        const SizedBox(height: 12),
        ...partners.map((p) {
          final name = p['name'] as String;
          final activity = p['activity'] as String;
          final goals = p['goals'] as String;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kShadow2,
                  ),
                  child: Center(
                    child: Text(
                      name[0],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _kText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${name}님',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _kText,
                        ),
                      ),
                      Text(
                        '활동 ${activity}회 · 목표 $goals',
                        style: TextStyle(
                          fontSize: 12,
                          color: _kText.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildBondRing() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _kAccent.withOpacity(0.6),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kAccent.withOpacity(0.15),
          ),
          child: Center(
            child: Text(
              '${_bondScore.toInt()}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerAvatars() {
    // 더미 파트너 (실제 연결 시 교체)
    final partners = ['P1', 'P2', 'P3'];
    return Row(
      children: partners.asMap().entries.map((e) {
        final i = e.key;
        return Transform.translate(
          offset: Offset(-8.0 * i, 0),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kShadow2,
              border: Border.all(color: _kCardBg, width: 1.5),
            ),
            child: Center(
              child: Text(
                e.value,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _kText.withOpacity(0.6),
                ),
              ),
            ),
          ),
        );
      }).toList(),
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
                    color: _kText.withOpacity(0.4),
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
                    color: _kAccent.withOpacity(0.8),
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
                        color: _kText,
                      ),
                    ),
                  ),
                  Text(
                    '${g.progress}/${g.target}',
                    style: TextStyle(
                      fontSize: 11,
                      color: _kText.withOpacity(0.4),
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
                    color: _kText,
                  ),
                ),
                const SizedBox(height: 16),

                // 추천 3개
                const Text(
                  '💡 이런 건 어떠세요?',
                  style: TextStyle(
                    fontSize: 13,
                    color: _kText,
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
                      backgroundColor: _kAccent.withOpacity(0.2),
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
                      borderSide: const BorderSide(color: _kAccent, width: 2),
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
                      backgroundColor: _kAccent,
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

  // ─────────────────────────────────────────
  // [스탬프] 이번 주 우리 스탬프 (합산형)
  // ─────────────────────────────────────────

  Widget _buildStampSection() {
    // 파트너 그룹이 없으면 숨김
    if (_partnerGroupId == null || _partnerGroupId!.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<WeeklyStampState>(
      stream: WeeklyStampService.watchThisWeek(_partnerGroupId!),
      builder: (context, snap) {
        final stamp = snap.data ?? WeeklyStampState.empty(
          WeeklyStampService.currentWeekKey(),
        );
        final todayIdx = WeeklyStampService.todayDayOfWeek();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 타이틀 + 안내 아이콘
                Row(
                  children: [
                    const Text(
                      '이번 주 우리 스탬프',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _kText,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _showStampInfo(),
                      child: Icon(
                        Icons.info_outline,
                        size: 16,
                        color: _kText.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 7개 스탬프 원 (월~일)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (i) {
                    final isFilled = stamp.isFilled(i);
                    final isToday = i == todayIdx;
                    return _StampCircle(
                      dayLabel: const ['월', '화', '수', '목', '금', '토', '일'][i],
                      isFilled: isFilled,
                      isToday: isToday,
                    );
                  }),
                ),

                const SizedBox(height: 14),

                // 요약 텍스트
                Center(
                  child: Text(
                    '이번 주 ${stamp.filledCount}/7 칸 채웠어요',
                    style: TextStyle(
                      fontSize: 12,
                      color: _kText.withValues(alpha: 0.5),
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

  void _showStampInfo() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '파트너 3명이 함께 투표/리액션/목표 체크를 하면\n'
          '하루 1칸씩 채워져요.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );
  }

  // ─────────────────────────────────────────
  // [섹션 B] 오늘을 나누기 (펼쳐진 카드)
  // ─────────────────────────────────────────

  Widget _buildSectionB() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 타이틀 + 작성 버튼
          Row(
            children: [
              const Text(
                '오늘을 나누기',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _kText,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _openDailyWallWrite,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kAccent.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '+ 나누기',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kText,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 게시물 피드
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bondPosts')
                .orderBy('createdAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snap.hasError) {
                return Center(
                  child: Text(
                    '불러오는 중 문제가 생겼어요.',
                    style: TextStyle(
                      fontSize: 13,
                      color: _kText.withOpacity(0.5),
                    ),
                  ),
                );
              }

              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return GestureDetector(
                  onTap: _openDailyWallWrite,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _kCardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _kShadow2.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.edit_note_outlined,
                          size: 40,
                          color: _kText.withOpacity(0.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '첫 이야기를 나눠주세요',
                          style: TextStyle(
                            fontSize: 14,
                            color: _kText.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return BondPostCard(
                    post: data,
                    postId: doc.id,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // [섹션 C] 파트너 활동 요약 (사람별) + 목표 통합
  // ─────────────────────────────────────────

  Widget _buildSectionC() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '이번 주 우리의 흐름',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
            const SizedBox(height: 14),

            // 파트너 1
            _buildUnifiedPartnerRow(
              name: '민지',
              activityCount: 3,
              goalProgress: '5/7',
            ),
            const SizedBox(height: 12),
            Container(
              height: 0.5,
              color: _kShadow2.withOpacity(0.4),
            ),
            const SizedBox(height: 12),

            // 파트너 2
            _buildUnifiedPartnerRow(
              name: '지은',
              activityCount: 1,
              goalProgress: '2/5',
            ),
            const SizedBox(height: 12),
            Container(
              height: 0.5,
              color: _kShadow2.withOpacity(0.4),
            ),
            const SizedBox(height: 12),

            // 파트너 3
            _buildUnifiedPartnerRow(
              name: '현수',
              activityCount: 0,
              goalProgress: '아직 없음',
            ),
            const SizedBox(height: 12),
            Container(
              height: 0.5,
              color: _kShadow2.withOpacity(0.4),
            ),
            const SizedBox(height: 12),

            // 나
            StreamBuilder<WeeklyGoals?>(
              stream: WeeklyGoalService.watchThisWeek(),
              builder: (context, snap) {
                final myGoals = snap.data?.goals ?? [];
                String goalText = '목표 없음';
                if (myGoals.isNotEmpty) {
                  final g = myGoals[0];
                  goalText = '${g.progress}/${g.target}';
                }
                return _buildUnifiedPartnerRow(
                  name: '나',
                  activityCount: 5,
                  goalProgress: goalText,
                  isMe: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedPartnerRow({
    required String name,
    required int activityCount,
    required String goalProgress,
    bool isMe = false,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isMe ? _kAccent : _kShadow2,
          ),
          child: Center(
            child: Text(
              name[0],
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${name}${!isMe ? "님" : ""}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isMe ? FontWeight.w700 : FontWeight.w600,
                  color: _kText,
                ),
              ),
              Text(
                '활동 ${activityCount}회 · 목표 $goalProgress',
                style: TextStyle(
                  fontSize: 12,
                  color: _kText.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // [섹션 D] 공감 투표 (펼쳐진 질문 + 선택지)
  // ─────────────────────────────────────────

  Widget _buildSectionD() {
    // 더미 투표 데이터
    const question = '요즘 가장 힘든 순간은?';
    final options = [
      '환자 컴플레인 받을 때',
      '야근이 길어질 때',
      '동료와 의견이 다를 때',
      '체력이 바닥날 때',
    ];
    // 더미 결과 (선택 후에만 표시)
    final results = [35, 25, 15, 25]; // %

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '공감 투표',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
                const Spacer(),
                Text(
                  '오늘의 질문',
                  style: TextStyle(
                    fontSize: 11,
                    color: _kText.withOpacity(0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 질문
            Text(
              question,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _kText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // 선택지
            ...options.asMap().entries.map((entry) {
              final i = entry.key;
              final option = entry.value;
              final isSelected = _selectedPollOption == i;
              final hasVoted = _selectedPollOption != null;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: hasVoted
                      ? null
                      : () => setState(() => _selectedPollOption = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
                      color: isSelected
                          ? _kAccent.withOpacity(0.12)
                          : _kBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? _kAccent.withOpacity(0.5)
                            : _kShadow2.withOpacity(0.5),
                        width: 0.5,
                      ),
        ),
        child: Row(
          children: [
                        // 라디오 아이콘
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? _kAccent
                                  : _kText.withOpacity(0.2),
                              width: isSelected ? 1.5 : 0.5,
                            ),
                            color: isSelected
                                ? _kAccent.withOpacity(0.3)
                                : Colors.transparent,
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _kAccent,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: _kText,
                            ),
                          ),
                        ),
                        // 결과 (투표 후에만 표시)
                        if (hasVoted)
                          Text(
                            '${results[i]}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _kText.withOpacity(0.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            if (_selectedPollOption != null) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '파트너 그룹 내 익명 결과',
                  style: TextStyle(
                    fontSize: 11,
                    color: _kText.withOpacity(0.35),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),
            Center(
              child: Text(
                '지난 질문 보기',
                style: TextStyle(
                  fontSize: 11,
                  color: _kText.withOpacity(0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // 공통 카드 데코레이션
  // ─────────────────────────────────────────

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: _kShadow2.withOpacity(0.3),
        width: 0.5,
      ),
      boxShadow: [
        BoxShadow(
          color: _kShadow1.withOpacity(0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════
// 스탬프 원 위젯 (pop 애니메이션 포함)
// ═══════════════════════════════════════════

class _StampCircle extends StatefulWidget {
  final String dayLabel;
  final bool isFilled;
  final bool isToday;

  const _StampCircle({
    required this.dayLabel,
    required this.isFilled,
    required this.isToday,
  });

  @override
  State<_StampCircle> createState() => _StampCircleState();
}

class _StampCircleState extends State<_StampCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _popCtrl;
  late Animation<double> _popAnim;
  bool _wasFilledBefore = false;

  @override
  void initState() {
    super.initState();
    _wasFilledBefore = widget.isFilled;
    _popCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _popAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _popCtrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant _StampCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 채워지지 않았다가 → 채워짐으로 변경 시 pop 애니메이션 + 햅틱
    if (!_wasFilledBefore && widget.isFilled) {
      _popCtrl.forward(from: 0);
      HapticFeedback.mediumImpact();
    }
    _wasFilledBefore = widget.isFilled;
  }

  @override
  void dispose() {
    _popCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _popAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: _popAnim.value,
          child: child,
        );
      },
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.isFilled
              ? _kAccent.withValues(alpha: 0.75)
              : _kShadow2.withValues(alpha: 0.3),
          border: Border.all(
            color: widget.isToday
                ? _kAccent.withValues(alpha: 0.8)
                : widget.isFilled
                    ? _kAccent.withValues(alpha: 0.4)
                    : _kShadow2.withValues(alpha: 0.4),
            width: widget.isToday ? 1.5 : 0.5,
          ),
          boxShadow: widget.isFilled
              ? [
                  BoxShadow(
                    color: _kAccent.withValues(alpha: 0.35),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Center(
      child: Text(
            widget.dayLabel,
        style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: widget.isFilled
                  ? Colors.white
                  : _kText.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}



