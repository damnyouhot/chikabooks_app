import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_modal_scaffold.dart';
import '../../pages/diary_timeline_page.dart';
import '../../services/admin_activity_service.dart';
import '../diary_input_sheet.dart';
import '../user_goal_sheet.dart';

/// 시트가 닫힐 때 부모에게 전달되는 결과.
///
/// - [characterMent]: 캐릭터 말풍선으로 흘려보낼 마지막 멘트.
/// - [openPastRecords]: true 이면 호출자가 시트를 닫은 직후
///   [DiaryTimelinePage]를 띄워야 함. 타임라인이 닫히면 다시 시트를 열어
///   사용자가 「지난 기록」 → 뒤로가기 흐름을 자연스럽게 쓸 수 있게 한다.
class RecordHubResult {
  const RecordHubResult({this.characterMent, this.openPastRecords = false});

  final String? characterMent;
  final bool openPastRecords;
}

/// 「기록하기」 통합 허브 시트
///
/// - 1탭(나) 하단 「기록하기」(앱 레드) 버튼을 누르면 이 시트가 열린다.
/// - 두 기능을 한 화면에 섞지 않고 **세그먼트로 명확히 분리**한다:
///   - 「오늘 한줄」: 나만 보는 한 줄 기록 ([DiaryInputBody])
///   - 「목표, 기억할 것」: 루틴/프로젝트 목표 ([UserGoalContent])
///
/// 마지막으로 선택한 탭은 SharedPreferences에 저장되어 다음 진입 시 복원된다.
///
/// 사용자가 「지난 기록」을 누르면 시트가 닫히고 [DiaryTimelinePage]가 푸시된다.
/// 타임라인에서 뒤로 가면 [show] 호출자가 시트를 한 번 더 열어 사용자 흐름이
/// 끊기지 않게 한다.
class RecordHubSheet {
  /// SharedPreferences 키 — 마지막으로 본 탭 인덱스(0=오늘 한줄, 1=목표).
  static const String prefsLastTabKey = 'record_hub_last_tab';

  /// 시트를 띄운다.
  ///
  /// 사용자가 「지난 기록」을 눌러 닫혔다면 자동으로 타임라인을 푸시하고,
  /// 타임라인에서 뒤로 돌아오면 시트를 다시 한 번 더 띄운다.
  /// 최종적으로 시트가 완전히 종료될 때 마지막 캐릭터 멘트를 반환한다.
  static Future<String?> show(BuildContext context) async {
    String? lastMent;
    while (true) {
      int initialTab = 0;
      try {
        final prefs = await SharedPreferences.getInstance();
        final stored = prefs.getInt(prefsLastTabKey);
        if (stored == 0 || stored == 1) initialTab = stored!;
      } catch (_) {
        // SharedPreferences 실패 시 기본값(0) 사용 — 사용자 흐름 영향 없음.
      }
      if (!context.mounted) return lastMent;
      final result = await showAppModalBottomSheet<RecordHubResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _RecordHubSheetContent(initialTab: initialTab),
      );
      lastMent = result?.characterMent ?? lastMent;

      // 「지난 기록」으로 닫힌 경우 타임라인을 띄우고, 닫히면 시트를 한 번 더.
      if (result?.openPastRecords == true && context.mounted) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => const DiaryTimelinePage(),
          ),
        );
        if (!context.mounted) return lastMent;
        continue; // 시트 다시 열기
      }
      return lastMent;
    }
  }
}

class _RecordHubSheetContent extends StatefulWidget {
  const _RecordHubSheetContent({required this.initialTab});

  final int initialTab;

  @override
  State<_RecordHubSheetContent> createState() => _RecordHubSheetContentState();
}

class _RecordHubSheetContentState extends State<_RecordHubSheetContent>
    with SingleTickerProviderStateMixin {
  /// 0 = 오늘 한줄, 1 = 나의 목표
  late int _index = widget.initialTab;

  /// 시트가 닫힐 때 캐릭터 말풍선으로 노출할 마지막 멘트.
  /// 두 콘텐츠(오늘 한줄·나의 목표)에서 발생한 가장 마지막 한 건만 보존.
  String? _pendingCharacterMent;

  void _selectTab(int index) {
    if (_index == index) return;
    setState(() => _index = index);
    AdminActivityService.log(
      index == 0
          ? ActivityEventType.tapRecordTabDiary
          : ActivityEventType.tapRecordTabGoal,
      page: 'record_hub',
    );
    // 다음 진입 시 복원하기 위해 SharedPreferences 에 저장 (fire-and-forget).
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setInt(RecordHubSheet.prefsLastTabKey, index))
        .catchError((_) => false);
  }

  /// 콘텐츠 위젯에서 호출되는 멘트 후보 수집기.
  void _bufferCharacterMent(String ment) {
    _pendingCharacterMent = ment;
  }

  /// 사용자 닫기 동작(드래그/탭 바깥/X 버튼/Back 등)에서 공통적으로 마지막
  /// 멘트를 반환값으로 실어 시트를 닫는다.
  void _closeWithResult({bool openPastRecords = false}) {
    Navigator.of(context).pop<RecordHubResult>(
      RecordHubResult(
        characterMent: _pendingCharacterMent,
        openPastRecords: openPastRecords,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<RecordHubResult>(
      // 사용자가 시스템 백 제스처/드래그로 닫을 때도 멘트가 같이 전달되도록 한다.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _closeWithResult();
      },
      // 시트 높이를 항상 동일하게 유지해 탭 전환 시 시트가 늘었다 줄었다
      // 하는 「점프」를 방지한다. (사용자 화면 90% 고정)
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 12),
                _buildDragHandle(),
                const SizedBox(height: 12),
                _buildHeader(context),
                const SizedBox(height: 12),
                _buildSegments(),
                const SizedBox(height: 12),
                // IndexedStack — 두 콘텐츠를 항상 마운트해 탭 전환 시
                // 재로딩(initState/Firestore 재조회/입력 초기화)이 일어나지
                // 않게 한다. 보이는 자식만 화면에 표시.
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    children: [
                      _buildDiaryTab(),
                      _buildGoalTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Drag handle ─────────────────────────────────────────────
  Widget _buildDragHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // ── Header (앱레드 점 + 「기록하기」 + 부제 + 닫기) ───────────
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 앱레드 강조 점 — 1탭 「기록하기」 버튼 색과 일치
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.lime,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  '기록하기',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '오늘 한 줄을 남기거나, 꾸준히 챙길 목표를 정해요.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '닫기',
            icon: const Icon(Icons.close, color: AppColors.textPrimary),
            onPressed: _closeWithResult,
          ),
        ],
      ),
    );
  }

  // ── Segmented control (오늘 한줄 / 나의 목표) ───────────────
  Widget _buildSegments() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            _SegmentTab(
              label: '오늘, 지금',
              icon: Icons.edit_outlined,
              selected: _index == 0,
              onTap: () => _selectTab(0),
            ),
            _SegmentTab(
              label: '목표, 리마인드',
              icon: Icons.flag_outlined,
              selected: _index == 1,
              onTap: () => _selectTab(1),
            ),
          ],
        ),
      ),
    );
  }

  // ── 「오늘 한줄」 ─────────────────────────────────────────────
  Widget _buildDiaryTab() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: DiaryInputBody(
        // 시트 카드를 [_RecordHubSheetContent]가 그리고 있어 본문은 데코 없이
        // 내용만 그린다. 자동 포커스도 끄고, 사용자가 입력 영역을 탭하면
        // 자연스럽게 키보드가 올라오도록 둔다.
        decorated: false,
        autofocus: false,
        popOnSave: false,
        // 「지난 기록」 칩 → 시트를 닫고, 호출자(RecordHubSheet.show)가
        // 타임라인을 띄운 뒤 시트를 다시 열어준다. (뒤로가기 흐름 자연스럽게)
        onShowPastRecords: () => _closeWithResult(openPastRecords: true),
        onSaved: (text) {
          // 저장 성공 → 멘트를 버퍼에 담아둔다. 시트는 닫지 않고
          // 사용자가 닫을 때(드래그/X/시스템 백) 부모에게 함께 전달된다.
          // (DiaryInputBody 가 popOnSave:false 모드라 입력칸은 자동 비워짐)
          final ment = DiaryResponseService.getRandomResponse(text);
          _bufferCharacterMent(ment);
        },
      ),
    );
  }

  // ── 「나의 목표」 ─────────────────────────────────────────────
  Widget _buildGoalTab() {
    // 기존 콘텐츠 위젯을 임베드 모드로 사용.
    // 시트 카드/드래그 핸들은 [_RecordHubSheetContent] 가 그리고 있으므로
    // [UserGoalContent] 는 헤더부터 콘텐츠까지만 그린다.
    return UserGoalContent(
      embedded: true,
      onCharacterMent: _bufferCharacterMent,
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.divider.withValues(alpha: 0.5),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
