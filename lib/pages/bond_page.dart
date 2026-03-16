import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_profile_service.dart';
import '../services/partner_service.dart';
import '../services/weekly_activity_service.dart';
import '../services/bond_post_service.dart';
import '../models/partner_group.dart';
import '../widgets/bond_post_sheet.dart';
import '../widgets/profile_gate_sheet.dart';
import '../widgets/partner_gate_sheet.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/glass_card.dart';

import '../widgets/bond/bond_top_bar.dart';
import '../widgets/bond/bond_week_header.dart';
import '../widgets/bond/bond_summary_section.dart';
import '../widgets/bond/bond_feed_section.dart';
import '../widgets/bond/bond_billboard_section.dart';
import '../widgets/bond/bond_poll_section.dart';
import '../widgets/bond/bond_continue_section.dart';
import '../widgets/bond/bond_notification_toast.dart';
import '../widgets/bond/bond_supplementation_listener.dart';
import '../widgets/bond/bond_empty_state_widget.dart';
import '../widgets/bond/bond_leave_sheet.dart';
import 'debug_test_data_page.dart';

/// 글래스모픽 테스트 플래그 — true: 그라디언트 배경 + 유리 카드
/// false: 기존 soft gray 배경 + 불투명 카드
const bool kBondGlassMode = false;

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
  State<BondPage> createState() => BondPageState();
}

// ignore: library_private_types_in_public_api
class BondPageState extends State<BondPage> with WidgetsBindingObserver {
  // ── 데이터 ──
  String? _partnerGroupId; // 추후 파트너 데이터 연결용
  PartnerGroup? _partnerGroup; // 파트너 그룹 정보
  List<GroupMemberMeta> _groupMembers = []; // 그룹 멤버 목록
  Map<String, String> _memberNicknames = {}; // ✅ 멤버 닉네임 맵 {uid: nickname}
  String _partnerStatus = 'active'; // 파트너 상태

  // ── 주간 활동 데이터 ──
  Map<String, int> _weeklyPostCounts = {}; // {uid: postCount}
  Map<String, int> _weeklyReactionCounts = {}; // {uid: reactionCount}

  // ── 첫 로드 플래그: 탭 마운트 시 1회만 forceRefresh ──
  bool _firstLoad = true;

  // ── 매칭 중 로딩 상태 ──
  bool _isMatching = false;

  // ── Firestore 스트림 (initState에서 1회 생성) ──
  Stream<DocumentSnapshot>? _userStream;

  // ── 결 파트 확장 ──
  // (파트너 있을 때는 항상 펼침으로 고정 — state로 관리하지 않음)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 스트림을 initState에서 1회만 생성 → build()에서 매번 새로 만들지 않음
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots();

      // 스트림 첫 이벤트에서 partnerGroupId를 즉시 읽어 캐시보다 빠르게 상태 세팅
      // → 앱 재시작 시 Firestore 로컬 캐시가 먼저 반환되므로 초기 UI가 올바르게 표시됨
      _userStream!.first.then((snap) {
        if (!mounted) return;
        final data = snap.data() as Map<String, dynamic>?;
        if (data == null) return;
        final firestoreGroupId = data['partnerGroupId'] as String?;
        final firestoreStatus = data['partnerStatus'] as String? ?? 'active';
        // _loadData()가 아직 완료되지 않은 경우에만 즉시 반영
        if (_partnerGroupId != firestoreGroupId) {
          setState(() {
            _partnerGroupId = firestoreGroupId;
            _partnerStatus = firestoreStatus;
          });
          // 그룹이 있으면 전체 데이터 로드 트리거
          if (firestoreGroupId != null) {
            _firstLoad = false;
            _loadData();
          }
        }
      });
    }
    _loadData();
    _checkAndShowNewWeekToast();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 앱이 foreground로 돌아올 때 닉네임 등 최신 데이터 갱신
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // publicProfiles 포함한 닉네임 재조회를 위해 _firstLoad 리셋
      _firstLoad = true;
      _loadData();
    }
  }

  /// 탭 복귀 등 외부에서 데이터 새로고침이 필요할 때 호출
  void refreshData() {
    _firstLoad = true;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      debugPrint('🔍 [BondPage] ━━━ 데이터 로딩 시작 ━━━');

      // ① 프로필 조회 (첫 로드만 forceRefresh, 이후는 캐시 활용)
      final profile = await UserProfileService.getMyProfile(
        forceRefresh: _firstLoad,
      );
      _firstLoad = false;
      final groupId = profile?.partnerGroupId;

      debugPrint('🔍 [BondPage] groupId: $groupId');
      debugPrint('🔍 [BondPage] partnerStatus: ${profile?.partnerStatus}');

      if (!mounted) return;
      setState(() {
        _partnerGroupId = groupId;
        _partnerStatus = profile?.partnerStatus ?? 'active';
      });

      if (groupId == null) {
        debugPrint('⚠️ [BondPage] 파트너 그룹 없음');
        debugPrint('✅ [BondPage] ━━━ 데이터 로딩 완료 ━━━');
        return;
      }

      debugPrint('🔍 [BondPage] 그룹 정보 조회 시작...');

      // ② 그룹 + 멤버 목록 병렬 조회
      final PartnerGroup? group;
      final List<GroupMemberMeta> members;
      final groupResult = await Future.wait<dynamic>([
        PartnerService.getMyGroup(),
        PartnerService.getGroupMembers(groupId),
      ]);
      group = groupResult[0] as PartnerGroup?;
      members = groupResult[1] as List<GroupMemberMeta>;

      debugPrint('🔍 [BondPage] group: ${group?.id}');
      debugPrint('🔍 [BondPage] group.endsAt: ${group?.endsAt}');
      debugPrint('🔍 [BondPage] group.isActiveGroup: ${group?.isActiveGroup}');
      debugPrint('🔍 [BondPage] group.memberUids: ${group?.memberUids}');
      debugPrint('🔍 [BondPage] members.length: ${members.length}');

      // ✅ 만료된 그룹 자동 정리
      // group==null 이거나 isGroupActive==false인 경우,
      // 캐시 타이밍 이슈일 수 있으므로 반드시 서버에서 재확인 후 정리
      if (group == null || !BondStateHelper.isGroupActive(group)) {
        debugPrint('⚠️ [BondPage] group 비활성 감지 (group=${group?.id}, isActive=${group?.isActive}) → 서버 재확인');

        // 서버에서 직접 그룹 문서 재확인 (캐시 무시)
        try {
          final snap = await FirebaseFirestore.instance
              .collection('partnerGroups')
              .doc(groupId)
              .get(const GetOptions(source: Source.server));
          if (snap.exists) {
            final serverData = snap.data();
            final serverIsActive = serverData?['isActive'] as bool? ?? false;
            final serverEndsAt = (serverData?['endsAt'] as Timestamp?)?.toDate();
            final serverNotExpired = serverEndsAt != null && serverEndsAt.toUtc().isAfter(DateTime.now().toUtc());
            final serverMemberUids = List<String>.from(serverData?['memberUids'] ?? []);

            debugPrint('🔍 [BondPage] 서버 재확인 결과: isActive=$serverIsActive, expired=${!serverNotExpired}, members=${serverMemberUids.length}');

            if (serverIsActive && serverNotExpired && serverMemberUids.isNotEmpty) {
              // 서버에 그룹이 활성으로 존재 → 캐시 이슈이므로 정리하지 않고 재시도
              debugPrint('⚠️ [BondPage] 서버에서는 활성 그룹 → 정리 스킵, 재시도');
              UserProfileService.clearCache();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _firstLoad = true;
                  _loadData();
                }
              });
              return;
            }
          }
        } catch (e) {
          debugPrint('⚠️ [BondPage] 그룹 서버 재확인 실패: $e');
          // 네트워크 에러 시에는 정리하지 않고 그냥 리턴 (다음 시도 때 다시 확인)
          return;
        }

        debugPrint('⚠️ [BondPage] 서버 확인 후에도 비활성 → partnerGroupId 정리');
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
        debugPrint('✅ [BondPage] ━━━ 데이터 로딩 완료 ━━━');
        return;
      }

      // ③ 닉네임 조회 + 주간 활동 데이터 병렬 처리
      // 닉네임: publicProfiles에서 항상 최신 값으로 조회 (설정 변경 즉시 반영)
      final nicknamesFuture = Future.wait<MapEntry<String, String>>(
        members.map((m) async {
          try {
            final doc = await FirebaseFirestore.instance
                .collection('publicProfiles')
                .doc(m.uid)
                .get();
            final nick = (doc.data()?['nickname'] as String?)?.trim();
            // publicProfiles에 없으면 memberMeta 닉네임 폴백
            if (nick != null && nick.isNotEmpty) return MapEntry(m.uid, nick);
            final metaNick = m.nickname?.trim();
            return MapEntry(m.uid, metaNick?.isNotEmpty == true ? metaNick! : m.uid);
          } catch (e) {
            debugPrint('⚠️ 닉네임 조회 실패 (${m.uid}): $e');
            final metaNick = m.nickname?.trim();
            return MapEntry(m.uid, metaNick?.isNotEmpty == true ? metaNick! : m.uid);
          }
        }),
      );
      final activityFuture =
          WeeklyActivityService.getWeeklyActivityData(groupId);

      final fetchedEntries = await nicknamesFuture;
      final activityData = await activityFuture;

      final nicknames = <String, String>{};
      // publicProfiles에서 가져온 최신 닉네임으로 덮어쓰기
      for (final entry in fetchedEntries) {
        nicknames[entry.key] = entry.value;
      }

      if (!mounted) return;
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

  /// 소모임 나가기 바텀시트 표시
  void _showLeaveSheet() {
    BondLeaveSheet.show(
      context,
      onLeft: () {
        // 로컬 상태 즉시 리셋 → "파트너 없음" UI 전환
        UserProfileService.clearCache();
        setState(() {
          _partnerGroupId = null;
          _partnerGroup = null;
          _groupMembers = [];
          _memberNicknames = {};
          _weeklyPostCounts = {};
          _weeklyReactionCounts = {};
          _partnerStatus = 'none';
        });
        _loadData(); // 서버 데이터와 동기화
      },
    );
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

  // ── 파트너 매칭 요청 ──
  void _onFindPartner() async {
    final hasBasic = await UserProfileService.hasBasicProfile();
    if (!mounted) return;

    if (!hasBasic) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ProfileGateSheet(
          onComplete: () {
            Navigator.pop(context);
            if (mounted) _checkStepBAndMatch();
          },
        ),
      );
      return;
    }
    _checkStepBAndMatch();
  }

  void _checkStepBAndMatch() async {
    final hasPartner = await UserProfileService.hasPartnerProfile();
    if (!mounted) return;

    if (!hasPartner) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => PartnerGateSheet(
          onComplete: () {
            Navigator.pop(context);
            if (mounted) _doMatch();
          },
        ),
      );
      return;
    }
    _doMatch();
  }

  void _doMatch() async {
    setState(() => _isMatching = true);
    final result = await PartnerService.requestMatching();
    if (!mounted) return;

    switch (result.status) {
      case MatchingStatus.matched:
        // 캐시 초기화 후 데이터 갱신, 완료 시점에 _isMatching 해제
        UserProfileService.clearCache();
        _firstLoad = true;
        await _loadData();
        if (mounted) {
          setState(() => _isMatching = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 파트너를 찾았어요! 1주일간 서로의 하루를 나눠보세요.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        }
        break;
      case MatchingStatus.waiting:
        setState(() => _isMatching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? '아직 함께할 사람이 부족해요. 매칭 대기 중이에요.'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        break;
      case MatchingStatus.error:
        setState(() => _isMatching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? '매칭 요청 중 문제가 생겼어요.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
    }
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

          // ── Firestore 실시간 변경 감지 ──
          // 1) 다른 사람의 매칭으로 내 그룹이 생성된 경우 즉시 UI 갱신
          // 2) 파트너 그룹이 있을 때 닉네임 변경 감지
          final firestoreGroupId = data['partnerGroupId'] as String?;
          final groupChanged = firestoreGroupId != _partnerGroupId;

          // 닉네임 변경 감지: 파트너 그룹이 있고 멤버가 로드된 경우에만 비교
          // (그룹 없을 때는 _memberNicknames가 비어있어 항상 null → 무한 루프 방지)
          final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
          final firestoreNickname = data['nickname'] as String?;
          final cachedNickname = _groupMembers.isNotEmpty
              ? _memberNicknames[myUid]
              : null; // 그룹 없으면 비교 자체를 안 함
          final nicknameChanged = _partnerGroupId != null &&
              firestoreNickname != null &&
              cachedNickname != null &&
              firestoreNickname != cachedNickname;

          if ((groupChanged || nicknameChanged) && !_isMatching) {
            // build() 중 setState 금지 → 다음 프레임에 실행
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                debugPrint('🔄 [BondPage] Firestore 변경 감지'
                    '${groupChanged ? " (그룹: $_partnerGroupId→$firestoreGroupId)" : ""}'
                    '${nicknameChanged ? " (닉네임 변경)" : ""}');
                UserProfileService.clearCache();
                _firstLoad = true;
                _loadData();
              }
            });
          }
        }

        return Scaffold(
          backgroundColor: kBondGlassMode
              ? const Color(0xFF0A0A0A)   // 글래스 모드: 순수 검정
              : AppColors.appBg,
          body: Stack(
            children: [
              // ── 글래스 모드: 그라디언트 배경 레이어 ──
              if (kBondGlassMode) ...[
                // 메인 베이스: 검정 → 검정 (순수 다크)
                Container(color: const Color(0xFF0A0A0A)),
                // 글로우 블롭 1 — 우상단 형광 라임 (메인 포인트)
                Positioned(
                  top: -80,
                  right: -60,
                  child: GlowBlob(
                    color: AppColors.lime,
                    width: 320,
                    height: 380,
                    opacity: 0.55,
                  ),
                ),
                // 글로우 블롭 2 — 우상단 보조 (좀 더 작고 선명)
                Positioned(
                  top: 20,
                  right: 10,
                  child: GlowBlob(
                    color: AppColors.lime,
                    width: 160,
                    height: 180,
                    opacity: 0.35,
                  ),
                ),
                // 글로우 블롭 3 — 좌하단 은은한 형광 잔광
                Positioned(
                  bottom: 120,
                  left: -80,
                  child: GlowBlob(
                    color: AppColors.lime,
                    width: 240,
                    height: 260,
                    opacity: 0.12,
                  ),
                ),
              ],

              // ── 콘텐츠 레이어 ──
              SafeArea(
                child: CustomScrollView(
                  slivers: [
                    // ━━━ 1. 공통 헤더 ━━━
                    SliverToBoxAdapter(
                      child: BondTopBar(
                        onSettingsLongPress: _showTestDataDialog,
                        weekLabel: weekLabel,
                        onLeaveGroupTap: hasActivePartner ? _showLeaveSheet : null,
                        glassMode: kBondGlassMode,
                      ),
                    ),

                    // ━━━ 1.5 [파트너 없음] 상태 카드 ━━━
                    if (!hasActivePartner)
                      SliverToBoxAdapter(
                        child: BondNoPartnerCard(
                          bondScore: bondScore,
                          glassMode: kBondGlassMode,
                        ),
                      ),

                    // 보충 알림 리스너 (파트너 있을 때만)
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

                      const SliverToBoxAdapter(child: SizedBox(height: 16)),

                      if (_partnerGroup != null &&
                          _groupMembers.isNotEmpty &&
                          BondStateHelper.canSelectContinue(_partnerGroup))
                        SliverToBoxAdapter(
                          child: BondContinueSection(
                            groupId: _partnerGroup!.id,
                            members: _groupMembers,
                          ),
                        ),

                      SliverToBoxAdapter(
                        child: BondFeedSection(
                          partnerGroupId: _partnerGroupId,
                          memberNicknames: _memberNicknames,
                          onOpenWrite: _openDailyWallWrite,
                          glassMode: kBondGlassMode,
                          isMatching: _isMatching,
                        ),
                      ),
                    ],

                    // ━━━ 3. [파트너 없음] 섹션 ━━━
                    if (!hasActivePartner) ...[
                      const SliverToBoxAdapter(child: SizedBox(height: 8)),

                      SliverToBoxAdapter(
                        child: BondFeedSection(
                          partnerGroupId: null,
                          memberNicknames: null,
                          onOpenWrite: _openDailyWallWrite,
                          onFindPartnerTap: _onFindPartner,
                          glassMode: kBondGlassMode,
                          isMatching: _isMatching,
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
            ],
          ),
        );
      },
    );
  }
}
