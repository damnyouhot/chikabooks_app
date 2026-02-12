import 'package:flutter/material.dart';
import '../models/weekly_goal.dart';
import '../services/user_profile_service.dart';
import '../services/weekly_goal_service.dart';
import '../widgets/daily_wall_sheet.dart';
import '../widgets/profile_gate_sheet.dart';
import 'settings/communion_profile_page.dart';

/// ─────────────────────────────────────────────────
/// 결 탭 — 피드형 (펼쳐진 콘텐츠 스크롤)
/// ─────────────────────────────────────────────────
///
/// 섹션 순서:
///   A) 요약 헤더 (결 점수 + 파트너 아바타 + 이번 주 목표 한 줄)
///   B) 오늘의 한 문장 + 리액션 (펼쳐진 카드)
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
                builder: (_) => const DailyWallSheet(),
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
        builder: (_) => const DailyWallSheet(),
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

            // ── 섹션 B: 오늘의 한 문장 (펼쳐진 카드) ──
            SliverToBoxAdapter(child: _buildSectionB()),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── 섹션 C: 파트너 활동 요약 ──
            SliverToBoxAdapter(child: _buildSectionC()),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── 섹션 D: 공감 투표 ──
            SliverToBoxAdapter(child: _buildSectionD()),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── 섹션 E: 이번 주 목표 진행률 ──
            SliverToBoxAdapter(child: _buildSectionE()),

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
    return Container(
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
            ],
          ),

          // 이번 주 목표 미니 요약
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 0.5,
            color: _kShadow2.withOpacity(0.6),
          ),
          const SizedBox(height: 12),
          _buildWeeklyGoalMini(),
        ],
      ),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '이번 주 목표',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(
            hintText: '예: 지각하지 않기',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
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
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // [섹션 B] 오늘의 한 문장 (펼쳐진 카드)
  // ─────────────────────────────────────────

  Widget _buildSectionB() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 타이틀
          Row(
            children: [
              const Text(
                '오늘의 한 문장',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _kText,
                ),
              ),
              const Spacer(),
              // 슬롯 상태 배지
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getSlotStatus(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: _kText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 내 문장 작성 또는 표시
          _buildMySentenceCard(),
          const SizedBox(height: 8),

          // 파트너 문장 카드들 (더미 → 실제 데이터 연결 시 교체)
          _buildPartnerSentenceCard(
            name: '민지님',
            badge: '3~5년차 · 서울',
            text: '오늘은 조용한 하루였으면 좋겠다.',
            reactions: {'😊': 2, '💪': 1, '🤗': 0},
          ),
          const SizedBox(height: 8),
          _buildPartnerSentenceCard(
            name: '지은님',
            badge: '6년차+ · 경기',
            text: '환자분이 고맙다고 해주셔서 뿌듯.',
            reactions: {'😊': 1, '💪': 0, '🤗': 2},
          ),

          // 더보기
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: _openDailyWallWrite,
              child: Text(
                '더보기',
                style: TextStyle(
                  fontSize: 12,
                  color: _kText.withOpacity(0.35),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSlotStatus() {
    final now = TimeOfDay.now();
    if (now.hour < 12 || (now.hour == 12 && now.minute < 30)) {
      return '다음 작성 12:30';
    } else if (now.hour < 19) {
      return '작성 가능 ✍️';
    } else {
      return '오늘 마감';
    }
  }

  Widget _buildMySentenceCard() {
    // 더미: 내 문장이 없을 때 → 작성 유도
    return GestureDetector(
      onTap: _openDailyWallWrite,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kAccent.withOpacity(0.15),
              ),
              child: const Center(
                child: Text('나', style: TextStyle(fontSize: 12, color: _kText)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '오늘의 기분을 남겨보세요.',
                style: TextStyle(
                  fontSize: 14,
                  color: _kText.withOpacity(0.4),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            Icon(Icons.edit_outlined, size: 16, color: _kText.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerSentenceCard({
    required String name,
    required String badge,
    required String text,
    required Map<String, int> reactions,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 작성자
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kShadow2.withOpacity(0.6),
                ),
                child: Center(
                  child: Text(
                    name[0],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kText.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kText,
                    ),
                  ),
                  Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10,
                      color: _kText.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 문장 텍스트
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: _kText,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          // 리액션 버튼들
          Row(
            children: reactions.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    // TODO: 리액션 보내기 구현
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _kShadow2.withOpacity(0.5),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(entry.key, style: const TextStyle(fontSize: 14)),
                        if (entry.value > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${entry.value}',
                            style: TextStyle(
                              fontSize: 11,
                              color: _kText.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // [섹션 C] 파트너 활동 요약 (사람별)
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
              '함께 흐름',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
            const SizedBox(height: 14),

            // 사람별 활동 (더미 → 실제 연결 시 교체)
            _buildPersonActivity(
              name: '민지님',
              activities: [
                '이번 주 목표 +1',
                '한 문장 작성',
                '응원하기 리액션 남김',
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 0.5,
              color: _kShadow2.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            _buildPersonActivity(
              name: '지은님',
              activities: [
                '공감투표 참여',
                '한 문장 작성',
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 0.5,
              color: _kShadow2.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            _buildPersonActivity(
              name: '현수님',
              activities: ['아직 활동 없음'],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonActivity({
    required String name,
    required List<String> activities,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 아바타
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kShadow2.withOpacity(0.6),
          ),
          child: Center(
            child: Text(
              name[0],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _kText.withOpacity(0.6),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // 이름 + 활동 리스트
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 4),
              ...activities.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _kText.withOpacity(0.3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          a,
                          style: TextStyle(
                            fontSize: 12,
                            color: _kText.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  )),
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
  // [섹션 E] 이번 주 목표 진행률
  // ─────────────────────────────────────────

  Widget _buildSectionE() {
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
                  '이번 주 목표 진행률',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _showAddGoalDialog,
                  child: Text(
                    '+ 추가',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _kAccent.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 나의 목표 (실제 데이터)
            StreamBuilder<WeeklyGoals?>(
              stream: WeeklyGoalService.watchThisWeek(),
              builder: (context, snap) {
                final goals = snap.data?.goals ?? [];
                if (goals.isEmpty) {
                  return _buildGoalProgressRow(
                    name: '나',
                    isMine: true,
                    goals: [],
                  );
                }
                return _buildGoalProgressRow(
                  name: '나',
                  isMine: true,
                  goals: goals,
                );
              },
            ),

            const SizedBox(height: 12),
            Container(height: 0.5, color: _kShadow2.withOpacity(0.4)),
            const SizedBox(height: 12),

            // 파트너 목표 (더미 → 실제 연결 시 교체)
            _buildGoalProgressRow(
              name: '민지님',
              isMine: false,
              goals: [
                GoalItem(id: 'd1', title: '매일 스트레칭', createdAt: DateTime.now(), progress: 5, target: 7),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 0.5, color: _kShadow2.withOpacity(0.4)),
            const SizedBox(height: 12),
            _buildGoalProgressRow(
              name: '지은님',
              isMine: false,
              goals: [
                GoalItem(id: 'd2', title: '일찍 퇴근하기', createdAt: DateTime.now(), progress: 2, target: 5),
                GoalItem(id: 'd3', title: '물 2L 마시기', createdAt: DateTime.now(), progress: 4, target: 7),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 0.5, color: _kShadow2.withOpacity(0.4)),
            const SizedBox(height: 12),
            _buildGoalProgressRow(
              name: '현수님',
              isMine: false,
              goals: [],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalProgressRow({
    required String name,
    required bool isMine,
    required List<GoalItem> goals,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 아바타
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isMine
                ? _kAccent.withOpacity(0.2)
                : _kShadow2.withOpacity(0.6),
          ),
          child: Center(
            child: Text(
              name[0],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _kText.withOpacity(0.6),
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
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kText,
                ),
              ),
              if (goals.isEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  isMine ? '목표를 설정해보세요' : '아직 목표가 없어요',
                  style: TextStyle(
                    fontSize: 12,
                    color: _kText.withOpacity(0.35),
                  ),
                ),
              ],
              ...goals.map((g) {
                final ratio =
                    g.target > 0 ? (g.progress / g.target).clamp(0.0, 1.0) : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              g.title,
                              style: TextStyle(
                                fontSize: 12,
                                color: _kText.withOpacity(0.7),
                              ),
                            ),
                          ),
                          // 체크인 버튼 (나만)
                          if (isMine)
                            GestureDetector(
                              onTap: () => WeeklyGoalService.checkIn(g.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _kAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '+1',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: _kText.withOpacity(0.5),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            '${g.progress}/${g.target}',
                            style: TextStyle(
                              fontSize: 11,
                              color: _kText.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // 프로그레스 바
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 3,
                          backgroundColor: _kShadow2.withOpacity(0.4),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            g.progress >= g.target
                                ? const Color(0xFF8BC6A0)
                                : _kAccent.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
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
