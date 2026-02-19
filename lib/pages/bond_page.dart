import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_profile_service.dart';
import '../widgets/bond_post_sheet.dart';
import '../widgets/profile_gate_sheet.dart';
import '../widgets/bond/bond_colors.dart';
import '../widgets/bond/bond_top_bar.dart';
import '../widgets/bond/bond_summary_section.dart';
import '../widgets/bond/bond_stamp_section.dart';
import '../widgets/bond/bond_feed_section.dart';
import '../widgets/bond/bond_billboard_section.dart';
import '../widgets/bond/bond_poll_section.dart';
import 'debug_test_data_page.dart';

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

class BondPage extends StatefulWidget {
  const BondPage({super.key});

  @override
  State<BondPage> createState() => _BondPageState();
}

class _BondPageState extends State<BondPage> {
  // ── 데이터 ──
  String? _partnerGroupId; // 추후 파트너 데이터 연결용

  // ── 결 파트 확장 ──
  bool _isBondExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final groupId = await UserProfileService.getPartnerGroupId();
      if (mounted) {
        setState(() {
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

  // ── 테스트 데이터 추가 다이얼로그 (개발자 모드) ──
  void _showTestDataDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DebugTestDataPage(),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    return Scaffold(
      backgroundColor: BondColors.kBg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── 상단 타이틀 바 ──
            SliverToBoxAdapter(
              child: BondTopBar(
                onSettingsLongPress: _showTestDataDialog,
              ),
            ),

            // ── 섹션 A: 요약 헤더 (실시간 결 점수) ──
            SliverToBoxAdapter(
              child: uid != null
                  ? StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        double bondScore = 50.0;
                        if (snapshot.hasData && snapshot.data?.data() != null) {
                          final data = snapshot.data!.data() as Map<String, dynamic>;
                          bondScore = (data['bondScore'] as num?)?.toDouble() ?? 50.0;
                        }
                        return BondSummarySection(
                          bondScore: bondScore,
                          isExpanded: _isBondExpanded,
                          onToggleExpand: () => setState(() => _isBondExpanded = !_isBondExpanded),
                        );
                      },
                    )
                  : BondSummarySection(
                      bondScore: 50.0,
                      isExpanded: _isBondExpanded,
                      onToggleExpand: () => setState(() => _isBondExpanded = !_isBondExpanded),
                    ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── 스탬프: 이번 주 우리 스탬프 (확장 시에만) ──
            if (_isBondExpanded)
              SliverToBoxAdapter(
                child: BondStampSection(
                  partnerGroupId: _partnerGroupId,
                ),
              ),

            SliverToBoxAdapter(child: SizedBox(height: _isBondExpanded ? 16 : 0)),

            // ── 섹션 B: 오늘을 나누기 (펼쳐진 카드) ──
            SliverToBoxAdapter(
              child: BondFeedSection(
                partnerGroupId: _partnerGroupId,
                onOpenWrite: _openDailyWallWrite,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── 전광판 섹션 ──
            const SliverToBoxAdapter(child: BondBillboardSection()),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── 섹션 D: 공감 투표 ──
            const SliverToBoxAdapter(child: BondPollSection()),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}
