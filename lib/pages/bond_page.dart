import 'package:flutter/material.dart';
import '../services/activity_log_service.dart';
import '../services/partner_dialogue_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/daily_wall_sheet.dart';
import '../widgets/partner_summary_card.dart';
import '../widgets/profile_gate_sheet.dart';
import 'partner_page.dart';
import 'settings/communion_profile_page.dart';

/// 결 탭 — 교류/공감 전용
///
/// 한줄 멘트(오늘의 한 문장), 파트너, 공감 투표 등
/// 사람들과 교류하는 기능이 여기에 집중됨.
class BondPage extends StatefulWidget {
  const BondPage({super.key});

  @override
  State<BondPage> createState() => _BondPageState();
}

class _BondPageState extends State<BondPage> {
  // ── 파트너 ──
  String? _partnerGroupId;
  String? _ambientLine;
  double _bondScore = 50.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final score = await UserProfileService.getBondScore();
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

  // ── 한줄 멘트 열기 ──
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
              ).then((_) => _loadData()); // 시트 닫힌 후 갱신
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
      ).then((_) => _loadData()); // 시트 닫힌 후 갱신
    }
  }

  // ── 파트너 열기 (복귀 시 자동 갱신) ──
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
              ).then((_) => _loadData()); // 복귀 시 갱신
            }
          },
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PartnerPage()),
      ).then((_) => _loadData()); // 복귀 시 갱신
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
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 결 점수 헤더 ──
                      _buildScoreHeader(),
                      const SizedBox(height: 24),

                      // ── 오늘의 한 문장 카드 ──
                      _buildFeatureCard(
                        icon: '✍️',
                        title: '오늘의 한 문장',
                        subtitle: '오늘의 기분을 한 문장으로 남겨보세요.',
                        onTap: _openDailyWall,
                      ),
                      const SizedBox(height: 12),

                      // ── 파트너 카드 ──
                      _buildFeatureCard(
                        icon: '🤝',
                        title: '파트너',
                        subtitle: '함께하는 동행을 만나보세요.',
                        onTap: _openPartner,
                      ),

                      // ── 파트너 소식 요약 ──
                      if (_partnerGroupId != null) ...[
                        const SizedBox(height: 16),
                        PartnerSummaryCard(groupId: _partnerGroupId!),
                      ],

                      // ── 파트너 우회 멘트 ──
                      if (_ambientLine != null) ...[
                        const SizedBox(height: 16),
                        _buildAmbientCard(),
                      ],

                      // ── 공감 투표 (placeholder) ──
                      const SizedBox(height: 12),
                      _buildFeatureCard(
                        icon: '💬',
                        title: '공감 투표',
                        subtitle: '오늘의 질문에 답해보세요.',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('곧 만나볼 수 있어요.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
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
        children: [
          const SizedBox(width: 8),
          const Text(
            '결',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF424242),
            ),
          ),
          const Spacer(),
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

  // ── 결 점수 헤더 (은은하게) ──
  Widget _buildScoreHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9E9EBE).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 미니 오라 인디케이터
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF00E5FF).withOpacity(0.25),
                  const Color(0xFF1E88E5).withOpacity(0.20),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00BCD4).withOpacity(0.12),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '결 ${_bondScore.toInt()}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w300,
                    color: Color(0xFF1E88E5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '교감하며 함께 쌓아가는 점수',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 기능 카드 (미니멀) ──
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
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
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

  // ── 파트너 우회 멘트 카드 ──
  Widget _buildAmbientCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
    );
  }
}
