import 'dart:math';
import 'package:flutter/material.dart';
import '../services/bond_score_service.dart';
import '../services/user_profile_service.dart';
import 'settings/communion_profile_page.dart';

/// 돌보기 탭 — 심플한 안내 + 결 탭 진입
///
/// "한 화면 = 하나의 중심" 원칙에 따라
/// 간단한 인사 텍스트와 결 탭 이동 버튼만 표시.
class CaringPage extends StatefulWidget {
  /// 결 탭으로 이동하기 위한 콜백 (MyHome에서 주입)
  final VoidCallback? onNavigateToBond;

  const CaringPage({super.key, this.onNavigateToBond});

  @override
  State<CaringPage> createState() => _CaringPageState();
}

class _CaringPageState extends State<CaringPage> {
  double _bondScore = 50.0;
  String _greeting = '';

  static const List<String> _greetings = [
    '오늘도 와줬구나.',
    '여기 있어도 돼.',
    '천천히, 괜찮아.',
    '한 걸음이면 충분해.',
    '오늘은 오늘만큼.',
    '숨 한 번 쉬어가자.',
  ];

  @override
  void initState() {
    super.initState();
    _greeting = _greetings[Random().nextInt(_greetings.length)];
    _loadScore();
  }

  Future<void> _loadScore() async {
    try {
      final score = await UserProfileService.getBondScore();
      if (mounted) setState(() => _bondScore = score);
    } catch (_) {}
  }

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
              // ── 상단 바: 설정만 ──
              _buildTopBar(),

              // ── 중앙 콘텐츠 ──
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 결 점수 표시 (작고 은은하게)
                        Text(
                          '결 ${_bondScore.toInt()}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey[350],
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 인사 텍스트
                        Text(
                          _greeting,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w300,
                            color: Color(0xFF555566),
                            height: 1.6,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          BondScoreService.scoreLabel(_bondScore),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[400],
                          ),
                        ),

                        const SizedBox(height: 48),

                        // 결 탭으로 이동 버튼 (미니멀)
                        _buildBondButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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

  /// "결" 탭으로 이동하는 미니멀 버튼
  Widget _buildBondButton() {
    return GestureDetector(
      onTap: widget.onNavigateToBond,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
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
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF1E88E5)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00BCD4).withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '결 보러 가기',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF555566),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
