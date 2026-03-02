import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_profile_service.dart';
import '../services/partner_service.dart';
import '../services/weekly_activity_service.dart';
import '../services/bond_post_service.dart'; // ✅ 추가
import '../models/partner_group.dart';
import '../widgets/bond_post_sheet.dart';
import '../widgets/profile_gate_sheet.dart';
import '../widgets/bond/bond_colors.dart';
import '../widgets/bond/bond_top_bar.dart';
import '../widgets/bond/bond_week_header.dart';
import '../widgets/bond/bond_summary_section.dart';
import '../widgets/bond/bond_stamp_section.dart';
import '../widgets/bond/bond_feed_section.dart';
import '../widgets/bond/bond_billboard_section.dart';
import '../widgets/bond/bond_poll_section.dart';
import '../widgets/bond/bond_continue_section.dart';
import '../widgets/bond/bond_notification_toast.dart';
import '../widgets/bond/bond_supplementation_listener.dart';
import '../widgets/bond/bond_empty_state_widget.dart';
import 'debug_test_data_page.dart';

/// ─────────────────────────────────────────────────
/// 결 탭 — 주간 페이지 기반
/// ─────────────────────────────────────────────────
///
/// 핵심 원칙:
///   - partnerGroupId 존재
///   - 그룹 문서 존재
///   - endsAt > now
///   → 이 조건을 만족할 때만 "파트너 있음"
///
/// 구조:
///   1. 주간 페이지 헤더 (항상 표시)
///   2. [파트너 있음] → 파트너 요약, 스탬프, 피드 등
///   3. [파트너 없음] → 조용한 페이지, 개인 피드 등
///   4. 전광판, 투표 (공통)
///

class BondPage extends StatefulWidget {
  const BondPage({super.key});

  @override
  State<BondPage> createState() => _BondPageState();
}

class _BondPageState extends State<BondPage> {
  // ── 데이터 ──
  String? _partnerGroupId; // 추후 파트너 데이터 연결용
  PartnerGroup? _partnerGroup; // 파트너 그룹 정보
  List<GroupMemberMeta> _groupMembers = []; // 그룹 멤버 목록
  Map<String, String> _memberNicknames = {}; // ✅ 멤버 닉네임 맵 {uid: nickname}
  String _partnerStatus = 'active'; // 파트너 상태

  // ── 주간 활동 데이터 ──
  Map<String, int> _weeklyPostCounts = {}; // {uid: postCount}
  Map<String, int> _weeklyReactionCounts = {}; // {uid: reactionCount}

  // ── Firestore 스트림 (initState에서 1회 생성) ──
  Stream<DocumentSnapshot>? _userStream;

  // ── 결 파트 확장 ──
  // (파트너 있을 때는 항상 펼침으로 고정 — state로 관리하지 않음)

  @override
  void initState() {
    super.initState();
    // 스트림을 initState에서 1회만 생성 → build()에서 매번 새로 만들지 않음
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots();
    }
    _loadData();
    _checkAndShowNewWeekToast();
  }

  Future<void> _loadData() async {
    try {
      debugPrint('🔍 [BondPage] ━━━ 데이터 로딩 시작 ━━━');

      // 프로필 및 그룹 정보 조회
      final profile = await UserProfileService.getMyProfile(forceRefresh: true);
      final groupId = profile?.partnerGroupId;

      debugPrint('🔍 [BondPage] groupId: $groupId');
      debugPrint('🔍 [BondPage] partnerStatus: ${profile?.partnerStatus}');

      if (mounted) {
        setState(() {
          _partnerGroupId = groupId;
          _partnerStatus = profile?.partnerStatus ?? 'active';
        });

        if (groupId != null) {
          debugPrint('🔍 [BondPage] 그룹 정보 조회 시작...');

          final group = await PartnerService.getMyGroup();
          debugPrint('🔍 [BondPage] group: ${group?.id}');
          debugPrint('🔍 [BondPage] group.endsAt: ${group?.endsAt}');
          debugPrint(
            '🔍 [BondPage] group.isActiveGroup: ${group?.isActiveGroup}',
          );
          debugPrint('🔍 [BondPage] group.memberUids: ${group?.memberUids}');

          // ✅ 만료된 그룹 자동 정리
          if (group == null || !BondStateHelper.isGroupActive(group)) {
            debugPrint('⚠️ [BondPage] 그룹 만료됨 → partnerGroupId 정리');
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid != null) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .update({
                    'partnerGroupId': FieldValue.delete(),
                    'partnerGroupEndsAt': FieldValue.delete(),
                  });
            }
            if (mounted) {
              setState(() {
                _partnerGroupId = null;
                _partnerGroup = null;
                _groupMembers = [];
                _memberNicknames = {};
              });
            }
            debugPrint('✅ [BondPage] 만료 그룹 정리 완료 → 개인 모드');
          } else {
            // 정상 활성 그룹
            final members = await PartnerService.getGroupMembers(groupId);
            debugPrint('🔍 [BondPage] members.length: ${members.length}');

            final nicknames = <String, String>{};
            for (final member in members) {
              final metaNick = member.nickname?.trim();
              if (metaNick != null && metaNick.isNotEmpty) {
                nicknames[member.uid] = metaNick;
                continue;
              }

              try {
                final publicDoc =
                    await FirebaseFirestore.instance
                        .collection('publicProfiles')
                        .doc(member.uid)
                        .get();
                final data = publicDoc.data();
                final pubNick = (data?['nickname'] as String?)?.trim();
                nicknames[member.uid] =
                    (pubNick != null && pubNick.isNotEmpty)
                        ? pubNick
                        : member.uid;
              } catch (e) {
                debugPrint('⚠️ 닉네임 조회 실패 (${member.uid}): $e');
                nicknames[member.uid] = member.uid;
              }
            }

            final activityData =
                await WeeklyActivityService.getWeeklyActivityData(groupId);

            if (mounted) {
              setState(() {
                _partnerGroup = group;
                _groupMembers = members;
                _memberNicknames = nicknames;
                _weeklyPostCounts = activityData['posts'] ?? {};
                _weeklyReactionCounts = activityData['reactions'] ?? {};
              });

              if (group.memberUids.length == 2 && group.weekNumber == 1) {
                _showTwoPersonStartToast();
              }
            }
          }
        } else {
          debugPrint('⚠️ [BondPage] 파트너 그룹 없음');
        }
      }

      debugPrint('✅ [BondPage] ━━━ 데이터 로딩 완료 ━━━');
    } catch (e) {
      debugPrint('⚠️ _loadData error: $e');
    }
  }

  void _onMemberJoined() {
    // 보충 멤버 합류 시 토스트 표시
    BondNotificationToast.showMemberJoined(context);
    _loadData(); // 데이터 재조회
  }

  Future<void> _checkAndShowNewWeekToast() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastShownWeek = prefs.getString('lastNewWeekToast');
      final currentWeek = _getCurrentWeekKey();

      if (lastShownWeek != currentWeek && _partnerGroupId != null) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          BondNotificationToast.showNewWeek(context);
          prefs.setString('lastNewWeekToast', currentWeek);
        }
      }
    } catch (e) {
      debugPrint('⚠️ _checkAndShowNewWeekToast error: $e');
    }
  }

  void _showTwoPersonStartToast() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shown = prefs.getBool('shown2PersonToast_${_partnerGroupId}');

      if (shown != true) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          BondNotificationToast.showTwoPersonStart(context);
          prefs.setBool('shown2PersonToast_${_partnerGroupId}', true);
        }
      }
    } catch (e) {
      debugPrint('⚠️ _showTwoPersonStartToast error: $e');
    }
  }

  String _getCurrentWeekKey() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    final year = kst.year;
    final startOfYear = DateTime(year, 1, 1);
    final days = kst.difference(startOfYear).inDays;
    final weekNumber = ((days + 1) / 7).ceil();
    return '$year-W${weekNumber.toString().padLeft(2, '0')}';
  }

  /// "0월 0주차: 00~00일" 형태 (KST)
  String _getWeekLabel() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    final month = kst.month;

    final firstDayOfMonth = DateTime(kst.year, kst.month, 1);
    final daysDiff = kst.difference(firstDayOfMonth).inDays;
    final weekOfMonth = (daysDiff / 7).floor() + 1;

    final weekday = kst.weekday; // 1=월, 7=일
    final monday = kst.subtract(Duration(days: weekday - 1));
    final sunday = monday.add(const Duration(days: 6));

    return '$month월 ${weekOfMonth}주차: ${monday.day}~${sunday.day}일';
  }

  // ── 한줄 멘트 작성 ──
  void _openDailyWallWrite() async {
    final hasActivePartner = BondStateHelper.hasActivePartner(
      _partnerGroup,
      _partnerStatus,
    );

    // 개인 모드면 스낵바로 안내하고 차단
    if (!hasActivePartner) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('파트너와 함께할 때만 기록할 수 있어요.\n매칭을 시작해보세요!'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // 1. 프로필 체크 (파트너 있을 때만)
    final hasProfile = await UserProfileService.hasBasicProfile();
    if (!mounted) return;

    if (!hasProfile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (_) => ProfileGateSheet(
              onComplete: () {
                Navigator.pop(context);
                if (mounted) {
                  _openWriteSheetWithCooldownCheck();
                }
              },
            ),
      );
      return;
    }

    // 2. 쿨타임 체크 후 바텀시트 열기
    await _openWriteSheetWithCooldownCheck();
  }

  Future<void> _openWriteSheetWithCooldownCheck() async {
    if (!mounted) return;

    final hasActivePartner = BondStateHelper.hasActivePartner(
      _partnerGroup,
      _partnerStatus,
    );

    // 개인 모드: 여기까지 오면 안 되지만 안전장치
    if (!hasActivePartner ||
        _partnerGroupId == null ||
        _partnerGroupId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('파트너와 함께할 때만 기록할 수 있어요.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // 파트너 모드: 쿨타임 체크
    final status = await BondPostService.getPostingStatus(_partnerGroupId!);

    if (!(status['canPostNow'] as bool)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status['message'] as String),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (mounted) {
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
      MaterialPageRoute(builder: (_) => const DebugTestDataPage()),
    );
  }

  // ═══════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final hasActivePartner = BondStateHelper.hasActivePartner(
      _partnerGroup,
      _partnerStatus,
    );
    final weekLabel = _getWeekLabel();

    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, snapshot) {
        double bondScore = 50.0;
        if (snapshot.hasData && snapshot.data?.data() != null) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          bondScore = (data['bondScore'] as num?)?.toDouble() ?? 50.0;
        }

        return Scaffold(
          backgroundColor: BondColors.kBg,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                // ━━━ 1. 공통 헤더 ━━━
                SliverToBoxAdapter(
                  child: BondTopBar(
                    onSettingsLongPress: _showTestDataDialog,
                    weekLabel: weekLabel,
                  ),
                ),

                // ━━━ 1.5 [파트너 없음] 상태 카드 ━━━
                if (!hasActivePartner)
                  SliverToBoxAdapter(
                    child: BondNoPartnerCard(bondScore: bondScore),
                  ),

                // 보충 알림 리스너 (파트너 있을 때만
                if (hasActivePartner)
                  SliverToBoxAdapter(
                    child: BondSupplementationListener(
                      groupId: _partnerGroupId,
                      onMemberJoined: _onMemberJoined,
                    ),
                  ),

                // ━━━ 2. [파트너 있음] 섹션 ━━━
                if (hasActivePartner) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // 파트너 요약 (통합 버전 - MemberList + PartnerSummary 흡수)
                  if (_groupMembers.isNotEmpty)
                    SliverToBoxAdapter(
                      child: BondSummarySection(
                        isExpanded: true,
                        onToggleExpand: () {},
                        enableToggle: false,
                        members: _groupMembers,
                        myUid: uid,
                        memberNicknames: _memberNicknames,
                        weeklyPostCounts: _weeklyPostCounts,
                        weeklyReactionCounts: _weeklyReactionCounts,
                        topRightOverlay: BondScoreGauge(bondScore: bondScore),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // 주간 스탬프 (파트너 있을 때 항상 표시)
                  SliverToBoxAdapter(
                    child: BondStampSection(partnerGroupId: _partnerGroupId),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // 이어가기 섹션 (주말만)
                  if (_partnerGroup != null &&
                      _groupMembers.isNotEmpty &&
                      BondStateHelper.canSelectContinue(_partnerGroup))
                    SliverToBoxAdapter(
                      child: BondContinueSection(
                        groupId: _partnerGroup!.id,
                        members: _groupMembers,
                      ),
                    ),

                  // 오늘을 나누기 (파트너 모드)
                  SliverToBoxAdapter(
                    child: BondFeedSection(
                      partnerGroupId: _partnerGroupId,
                      memberNicknames: _memberNicknames,
                      onOpenWrite: _openDailyWallWrite,
                    ),
                  ),
                ],

                // ━━━ 3. [파트너 없음] 섹션 ━━━
                if (!hasActivePartner) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // 오늘을 나누기 (개인 모드)
                  SliverToBoxAdapter(
                    child: BondFeedSection(
                      partnerGroupId: null,
                      memberNicknames: null,
                      onOpenWrite: _openDailyWallWrite,
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ━━━ 4. 공통 섹션 ━━━
                const SliverToBoxAdapter(child: BondBillboardSection()),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                const SliverToBoxAdapter(child: BondPollSection()),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        );
      },
    );
  }
}
