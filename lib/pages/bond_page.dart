import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_segmented_control.dart';
import '../features/senior_qna/widgets/senior_question_feed.dart';
import '../services/admin_activity_service.dart';
import '../services/content_read_state_service.dart';
import '../widgets/bond/bond_poll_section.dart';
import 'settings/settings_page.dart';

/// 2번 탭 — 공감투표
class BondPage extends StatefulWidget {
  const BondPage({super.key});

  @override
  State<BondPage> createState() => BondPageState();
}

class BondPageState extends State<BondPage>
    with SingleTickerProviderStateMixin {
  final _pollKey = GlobalKey<BondPollSectionState>();
  late final TabController _tabCtrl;
  int _lastMarkedTabIndex = -1;

  void refreshData() => _pollKey.currentState?.reload();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(_markCurrentTabSeen);
    WidgetsBinding.instance.addPostFrameCallback((_) => _markCurrentTabSeen());
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_markCurrentTabSeen);
    _tabCtrl.dispose();
    super.dispose();
  }

  void _markCurrentTabSeen() {
    if (!mounted || _lastMarkedTabIndex == _tabCtrl.index) return;
    _lastMarkedTabIndex = _tabCtrl.index;
    final key = switch (_tabCtrl.index) {
      0 => ContentReadKeys.bondPolls,
      1 => ContentReadKeys.seniorQuestions,
      _ => null,
    };
    if (key != null) ContentReadStateService.markSeen(key);
    if (_tabCtrl.index == 1) {
      AdminActivityService.log(
        ActivityEventType.viewWhisper,
        page: 'bond_whisper',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            StreamBuilder<Set<int>>(
              stream: ContentReadStateService.watchNewIndices(const {
                0: [ContentReadKeys.bondPolls],
                1: [ContentReadKeys.seniorQuestions],
              }),
              initialData: const {},
              builder: (context, snapshot) {
                return AppSegmentedControl(
                  controller: _tabCtrl,
                  labels: const ['공감투표', '속닥속닥'],
                  newIndices: snapshot.data ?? const {},
                  margin: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
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
                  CustomScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverToBoxAdapter(child: BondPollSection(key: _pollKey)),
                      const SliverToBoxAdapter(child: SizedBox(height: 40)),
                    ],
                  ),
                  const SeniorQuestionFeed(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),
          IconButton(
            icon: const Icon(
              Icons.info_outline,
              color: AppColors.textDisabled,
              size: 18,
            ),
            onPressed: () => _showConceptDialog(context),
          ),
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: AppColors.textDisabled,
              size: 20,
            ),
            onPressed:
                () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
    );
  }

  void _showConceptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text(
              "'같이' 탭 · 공감 투표에 대해서",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            content: const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '서로의 생각에 공감하고, 투표와 반응으로 연결되는 공간이에요. 오늘의 주제와 지난 결과를 함께 볼 수 있어요.',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '👍 공감하기',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '보기 중 하나에 공감할 수 있어요. 투표가 끝나기 전까지 선택을 바꿀 수 있어요.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '✍️ 내 보기 추가',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '진행 중인 투표에서 기본 보기 외에 직접 새 보기를 적을 수 있어요(운영 정책에 따라 제한될 수 있어요).',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '📊 지난 투표',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '끝난 투표는 공감 수 기준 순위(1위, 2위 …)로 볼 수 있어요. 전체 보기로 펼치면 종료된 투표에 한마디를 남길 수 있어요.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('닫기'),
              ),
            ],
          ),
    );
  }
}
