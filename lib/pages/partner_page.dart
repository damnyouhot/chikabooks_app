import 'package:flutter/material.dart';
import '../models/partner_group.dart';
import '../services/partner_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/partner/group_status_card.dart';
import '../widgets/partner/new_slot_card.dart';
import '../widgets/partner/bond_score_card.dart';
import '../widgets/partner/invite_card.dart';

/// 파트너 페이지
///
/// 4개 카드: 그룹 상태 / 오늘의 말 / 결 점수 / 추천·초대
/// 대시보드 느낌 금지, 카드형 세로 스크롤.
class PartnerPage extends StatefulWidget {
  const PartnerPage({super.key});

  @override
  State<PartnerPage> createState() => _PartnerPageState();
}

class _PartnerPageState extends State<PartnerPage> {
  bool _loading = true;
  PartnerGroup? _group;
  List<GroupMemberMeta> _members = [];
  double _bondScore = 60.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final group = await PartnerService.getMyGroup();
      List<GroupMemberMeta> members = [];
      if (group != null) {
        members = await PartnerService.getGroupMembers(group.id);
      }
      final score = await UserProfileService.getBondScore();
      if (mounted) {
        setState(() {
          _group = group;
          _members = members;
          _bondScore = score;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 매칭 성공 시 호출 — 캐시 초기화 후 데이터 다시 로드
  void _onMatchSuccess() {
    UserProfileService.clearCache();
    setState(() => _loading = true);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('파트너'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                setState(() => _loading = true);
                await _load();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  // ── 카드 1: 그룹 상태 ──
                  if (_group != null) ...[
                    GroupStatusCard(
                        group: _group!, members: _members),
                    const SizedBox(height: 12),

                    // ── 카드 2: 오늘의 말 (새로운 서버 기준 슬롯) ──
                    NewSlotCard(groupId: _group!.id),
                    const SizedBox(height: 12),

                    // ── 카드 3: 결 점수 ──
                    BondScoreCard(score: _bondScore),
                    const SizedBox(height: 12),
                  ] else ...[
                    // 그룹 없음 안내
                    _buildNoGroupCard(),
                    const SizedBox(height: 12),

                    // 결 점수 (그룹 없어도 표시)
                    BondScoreCard(score: _bondScore),
                    const SizedBox(height: 12),

                    // ── 카드 4: 추천/초대 (그룹 없을 때만) ──
                    InviteCard(onMatchSuccess: _onMatchSuccess),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildNoGroupCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.people_outline,
              color: Color(0xFFCE93D8), size: 40),
          const SizedBox(height: 12),
          const Text(
            '아직 파트너가 없어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF424242),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '비슷한 고민을 가진 3명이 1주일간\n서로의 하루를 나눕니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

