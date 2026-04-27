import 'package:flutter/material.dart';
import '../widgets/hira_update_section.dart';
import '../widgets/fee_lookup_section.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_segmented_control.dart';
import '../services/content_read_state_service.dart';

/// 보험정보 페이지 (구 제도 변경)
///
/// 소탭 2개:
///   1. 수가 조회 — data.go.kr API 기반 수가 코드/이름 검색
///   2. 제도 변경 — HIRA RSS + 심평원 전체 DB 검색
///
/// [tabRequestNotifier] 값이 0 또는 1일 때 해당 소탭으로 전환 (홈 1탭 정책 카드 등)
class HiraUpdatePage extends StatefulWidget {
  const HiraUpdatePage({super.key, this.tabRequestNotifier});

  final ValueNotifier<int>? tabRequestNotifier;

  @override
  State<HiraUpdatePage> createState() => _HiraUpdatePageState();
}

class _HiraUpdatePageState extends State<HiraUpdatePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final ValueNotifier<String?> _policySearchRequest = ValueNotifier<String?>(
    null,
  );
  int _lastMarkedTabIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(_markCurrentTabSeen);
    widget.tabRequestNotifier?.addListener(_onExternalTabRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) => _markCurrentTabSeen());
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_markCurrentTabSeen);
    widget.tabRequestNotifier?.removeListener(_onExternalTabRequest);
    _tabCtrl.dispose();
    _policySearchRequest.dispose();
    super.dispose();
  }

  void _markCurrentTabSeen() {
    if (!mounted || _lastMarkedTabIndex == _tabCtrl.index) return;
    _lastMarkedTabIndex = _tabCtrl.index;
    if (_tabCtrl.index == 1) {
      ContentReadStateService.markSeen(ContentReadKeys.hiraPolicyUpdates);
    }
  }

  void _onExternalTabRequest() {
    final n = widget.tabRequestNotifier?.value ?? -1;
    if (n < 0 || n > 1 || !mounted) return;
    if (_tabCtrl.index != n) {
      _tabCtrl.animateTo(n);
    }
  }

  void _openPolicySearchWithKeyword(String keyword) {
    final t = keyword.trim();
    if (t.length < 2) return;
    _tabCtrl.animateTo(1);
    // TabBarView가 두 번째 탭을 빌드하기 전에 notifier만 세팅하면 리스너가 못 받음 → 프레임 2회 대기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _policySearchRequest.value = null;
        _policySearchRequest.value = t;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.appBg,
      child: Column(
        children: [
          StreamBuilder<Set<int>>(
            stream: ContentReadStateService.watchNewIndices(const {
              1: [ContentReadKeys.hiraPolicyUpdates],
            }),
            initialData: const {},
            builder: (context, snapshot) {
              return AppSegmentedControl(
                controller: _tabCtrl,
                labels: const ['수가 조회', '제도 변경'],
                newIndices: snapshot.data ?? const {},
                margin: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xs,
                  AppSpacing.xl,
                  AppSpacing.sm,
                ),
              );
            },
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                FeeLookupSection(
                  onOpenPolicySearch: _openPolicySearchWithKeyword,
                ),
                HiraUpdateSection(policySearchRequest: _policySearchRequest),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
