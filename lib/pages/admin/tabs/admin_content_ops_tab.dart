import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/admin_dashboard_service.dart';
import '../widgets/admin_common_widgets.dart';

/// 콘텐츠 운영 허브 — `getContentOpsHub` 스냅샷 + 공감투표 종료/삭제(2단계)
class AdminContentOpsTab extends StatefulWidget {
  const AdminContentOpsTab({super.key});

  @override
  State<AdminContentOpsTab> createState() => _AdminContentOpsTabState();
}

class _AdminContentOpsTabState extends State<AdminContentOpsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _hub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hub = await AdminDashboardService.getContentOpsHub(
        schedulePreviewDays: 21,
      );
      if (!mounted) return;
      if (hub == null || hub['success'] != true) {
        setState(() {
          _error = '허브 데이터를 불러오지 못했습니다.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _hub = hub;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _confirmClosePoll(String pollId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('투표 종료 처리'),
        content: Text(
          '투표 $pollId 을(를) 종료하고 순위를 확정합니다.\n'
          '문서는 삭제되지 않습니다.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('종료')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final r = await AdminDashboardService.manualClosePoll(pollId);
      if (!mounted) return;
      final success = r?['success'] == true;
      final msg = r?['message'] as String? ??
          (success ? '처리했습니다.' : '종료에 실패했습니다.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    }
  }

  Future<void> _twoStepDeletePoll(String pollId) async {
    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('완전 삭제 (1/2)'),
        content: Text(
          '투표 $pollId 과(와) 모든 보기·공감·댓글·신고 하위 데이터가 '
          '영구 삭제됩니다. 복구할 수 없습니다.\n\n'
          '계속하시겠습니까?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('다음'),
          ),
        ],
      ),
    );
    if (step1 != true || !mounted) return;

    final ctrl = TextEditingController();
    final step2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('완전 삭제 (2/2)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '삭제할 문서 ID를 정확히 입력하세요.\n대상: $pollId',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: '문서 ID',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              autocorrect: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('삭제 실행'),
          ),
        ],
      ),
    );
    final typed = ctrl.text.trim();
    ctrl.dispose();
    if (step2 != true || !mounted) return;

    try {
      final r = await AdminDashboardService.adminDeletePoll(
        pollId: pollId,
        confirmPollId: typed,
      );
      if (!mounted) return;
      final success = r?['success'] == true;
      final msg = r?['message'] as String? ??
          (success ? '삭제했습니다.' : '삭제에 실패했습니다.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    }
  }

  String _shortIso(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    if (iso.length >= 16) return iso.substring(0, 16).replaceFirst('T', ' ');
    return iso;
  }

  /// Callable·직렬화 경로에 따라 중첩이 `Map<Object?, Object?>` 로 올 수 있어 캐스팅 대신 복제한다.
  Map<String, dynamic>? _coerceMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  List<dynamic> _coerceList(dynamic v) {
    if (v is List) return List<dynamic>.from(v);
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const AdminLoadingState();
    if (_error != null) return AdminErrorState(onRetry: _load);

    final hub = _hub!;
    final generatedAt = hub['generatedAt'] as String? ?? '';
    final pollNext = hub['pollNextPreview'];
    final polls = _coerceList(hub['polls']);
    final quiz = _coerceMap(hub['quiz']);
    final meta = _coerceMap(quiz?['meta']);
    final cfg = _coerceMap(quiz?['contentConfig']);
    final schedules = _coerceList(quiz?['schedules']);
    final breakdown = _coerceMap(quiz?['poolPackBreakdown']);

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '생성 시각: $generatedAt',
            style: const TextStyle(fontSize: 11, color: AppColors.textDisabled),
          ),
          const SizedBox(height: 16),
          const AdminSectionTitle('예상 다음 공감투표'),
          const SizedBox(height: 6),
          _NextPollCard(
            pollNext: pollNext is Map ? Map<String, dynamic>.from(pollNext) : null,
            shortIso: _shortIso,
          ),
          const SizedBox(height: 20),
          const AdminSectionTitle('퀴즈 메타 · 패크 설정'),
          const SizedBox(height: 6),
          _QuizMetaSummary(meta: meta, cfg: cfg),
          const SizedBox(height: 16),
          const AdminSectionTitle('활성 풀 — 패크별 문항 수'),
          const SizedBox(height: 6),
          _PackBreakdownCard(breakdown: breakdown),
          const SizedBox(height: 20),
          const AdminSectionTitle('최근 스케줄 (KST 역순 21일)'),
          const SizedBox(height: 6),
          ...schedules.map((s) {
            if (s is! Map) return const SizedBox.shrink();
            final m = Map<String, dynamic>.from(s);
            final dk = m['dateKey'] as String? ?? '';
            final exists = m['exists'] == true;
            final ic = m['itemCount'];
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(dk, style: const TextStyle(fontSize: 13)),
              subtitle: exists
                  ? Text(
                      '문항 $ic개 · cycle ${m['cycleCount']}',
                      style: const TextStyle(fontSize: 11),
                    )
                  : const Text('스케줄 없음', style: TextStyle(fontSize: 11)),
            );
          }),
          const SizedBox(height: 20),
          AdminSectionTitle('공감투표 목록 (${polls.length})'),
          const SizedBox(height: 6),
          ...polls.map((raw) {
            if (raw is! Map) return const SizedBox.shrink();
            final p = Map<String, dynamic>.from(raw);
            final id = p['id'] as String? ?? '';
            final q = p['question'] as String? ?? '';
            final st = p['status'] as String? ?? '';
            final ord = p['displayOrder'];
            final starts = p['startsAt'] as String?;
            final preview = q.length > 56 ? '${q.substring(0, 56)}…' : q;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(preview, style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                  '$id · #$ord · $st · 시작 ${_shortIso(starts)}',
                  style: const TextStyle(fontSize: 10),
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (v) {
                    if (v == 'close') _confirmClosePoll(id);
                    if (v == 'delete') _twoStepDeletePoll(id);
                  },
                  itemBuilder: (ctx) {
                    final items = <PopupMenuEntry<String>>[
                      if (st != 'closed')
                        const PopupMenuItem(
                          value: 'close',
                          child: Text('종료 처리'),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          '완전 삭제…',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ];
                    return items;
                  },
                ),
              ),
            );
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _NextPollCard extends StatelessWidget {
  final Map<String, dynamic>? pollNext;
  final String Function(String?) shortIso;

  const _NextPollCard({required this.pollNext, required this.shortIso});

  @override
  Widget build(BuildContext context) {
    final p = pollNext;
    if (p == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          '아직 시작 전인 투표가 없습니다. (전부 시작됐거나 종료된 상태일 수 있음)',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      );
    }
    final q = p['question'] as String? ?? '';
    final id = p['id'] as String? ?? '';
    final ord = p['displayOrder'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '순번 #$ord · $id',
            style: const TextStyle(fontSize: 11, color: AppColors.accent),
          ),
          const SizedBox(height: 6),
          Text(
            q,
            style: const TextStyle(fontSize: 14, height: 1.35),
          ),
          const SizedBox(height: 8),
          Text(
            '시작 ${shortIso(p['startsAt'] as String?)} · 종료 ${shortIso(p['endsAt'] as String?)}',
            style: const TextStyle(fontSize: 11, color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }
}

class _QuizMetaSummary extends StatelessWidget {
  final Map<String, dynamic>? meta;
  final Map<String, dynamic>? cfg;

  const _QuizMetaSummary({required this.meta, required this.cfg});

  @override
  Widget build(BuildContext context) {
    final m = meta;
    final c = cfg;
    final cycle = m?['cycleCount'];
    final last = m?['lastScheduledDate'] ?? '';
    final used = m?['usedQuizIdsCount'];
    final tot = m?['totalActiveCount'];
    final clin = c?['currentClinicalPackId'] as String? ?? '';
    final nat = c?['currentNationalPackId'] as String? ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '사이클 $cycle · 마지막 스케줄 $last · usedQuizIds $used건 · 활성 풀(패크필터 반영 메타) $tot',
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            '임상 패크: ${clin.isEmpty ? "(전체)" : clin}',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          Text(
            '국시 패크: ${nat.isEmpty ? "(전체)" : nat}',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PackBreakdownCard extends StatelessWidget {
  final Map<String, dynamic>? breakdown;

  const _PackBreakdownCard({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final b = breakdown;
    if (b == null) {
      return const Text('집계 없음', style: TextStyle(fontSize: 12));
    }
    final total = b['activeTotal'];
    final nat = b['nationalExam'] as Map<String, dynamic>?;
    final clin = b['clinical'] as Map<String, dynamic>?;
    final natLoose = nat?['withoutPackId'];
    final clinLoose = clin?['withoutPackId'];
    final natPacks = (nat?['byPack'] as List<dynamic>?) ?? [];
    final clinPacks = (clin?['byPack'] as List<dynamic>?) ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '활성 문서 합계: $total (isActive==true)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text('국시 — packId 없음: $natLoose', style: const TextStyle(fontSize: 11)),
          ...natPacks.take(12).map((row) {
            if (row is! Map) return const SizedBox.shrink();
            final r = Map<String, dynamic>.from(row);
            return Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(
                '· ${r['packId']}: ${r['count']}문항',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            );
          }),
          if (natPacks.length > 12)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(
                '… 그 외 패크 ${natPacks.length - 12}개 (목록 축약)',
                style: const TextStyle(fontSize: 10, color: AppColors.textDisabled),
              ),
            ),
          const SizedBox(height: 10),
          Text('임상 — packId 없음: $clinLoose', style: const TextStyle(fontSize: 11)),
          ...clinPacks.take(12).map((row) {
            if (row is! Map) return const SizedBox.shrink();
            final r = Map<String, dynamic>.from(row);
            return Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(
                '· ${r['packId']}: ${r['count']}문항',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            );
          }),
          if (clinPacks.length > 12)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(
                '… 그 외 패크 ${clinPacks.length - 12}개 (목록 축약)',
                style: const TextStyle(fontSize: 10, color: AppColors.textDisabled),
              ),
            ),
        ],
      ),
    );
  }
}
