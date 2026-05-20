import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_modal_scaffold.dart';
import '../diary_input_sheet.dart';
import '../user_goal_sheet.dart';

/// 「기록하기」 통합 허브 시트
///
/// - 1탭(나) 하단 「기록하기」(앱 레드) 버튼을 누르면 이 시트가 열린다.
/// - 두 기능을 한 화면에 섞지 않고 **세그먼트로 명확히 분리**한다:
///   - 「오늘 한줄」: 나만 보는 한 줄 기록 ([DiaryInputBody])
///   - 「나의 목표」: 루틴/프로젝트 목표 ([UserGoalContent])
///
/// 직전 진입 시 마지막으로 본 탭을 SharedPreferences로 기억하는 기능은
/// 후속 단계에서 추가된다. (현재는 항상 「오늘 한줄」로 시작)
class RecordHubSheet {
  /// 시트를 띄운다. 외부에서 결과를 받지 않는다 (모든 저장은 시트 내부에서 처리).
  static Future<void> show(BuildContext context) {
    return showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RecordHubSheetContent(),
    );
  }
}

class _RecordHubSheetContent extends StatefulWidget {
  const _RecordHubSheetContent();

  @override
  State<_RecordHubSheetContent> createState() => _RecordHubSheetContentState();
}

class _RecordHubSheetContentState extends State<_RecordHubSheetContent>
    with SingleTickerProviderStateMixin {
  /// 0 = 오늘 한줄, 1 = 나의 목표
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      // 시트가 키보드(viewInsets)를 알아서 피하도록 isScrollControlled+true 와
      // 내부 콘텐츠가 자체 viewInsets padding을 가진다. 여기서는 카드 외형만 담당.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            _buildDragHandle(),
            const SizedBox(height: 12),
            _buildHeader(context),
            const SizedBox(height: 12),
            _buildSegments(),
            const SizedBox(height: 12),
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: KeyedSubtree(
                  key: ValueKey<int>(_index),
                  child: _buildBody(),
                ),
              ),
            ),
          ],
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
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '오늘의 한 줄과 나의 목표를 한 곳에서.',
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
            onPressed: () => Navigator.of(context).maybePop(),
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
              label: '오늘 한줄',
              icon: Icons.edit_outlined,
              selected: _index == 0,
              onTap: () => setState(() => _index = 0),
            ),
            _SegmentTab(
              label: '나의 목표',
              icon: Icons.flag_outlined,
              selected: _index == 1,
              onTap: () => setState(() => _index = 1),
            ),
          ],
        ),
      ),
    );
  }

  // ── Body 분기 ────────────────────────────────────────────────
  Widget _buildBody() {
    if (_index == 0) {
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: DiaryInputBody(
          // 시트 카드를 [_RecordHubSheetContent]가 그리고 있어 본문은 데코 없이
          // 내용만 그린다. 자동 포커스도 끄고, 사용자가 입력 영역을 탭하면
          // 자연스럽게 키보드가 올라오도록 둔다.
          decorated: false,
          autofocus: false,
          onSaved: (text) {
            // 후속 단계에서 캐릭터 멘트 연결 시 이 콜백을 사용한다.
            // 현재는 별도 처리 없음.
          },
        ),
      );
    }
    // 「나의 목표」: 기존 콘텐츠 위젯을 임베드 모드로 사용.
    // 시트 카드/드래그 핸들은 [_RecordHubSheetContent] 가 그리고 있으므로
    // [UserGoalContent] 는 헤더부터 콘텐츠까지만 그린다.
    return const UserGoalContent(embedded: true);
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
