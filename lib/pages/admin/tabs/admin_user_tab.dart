import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/widgets/app_modal_scaffold.dart';
import '../../../services/admin_user_service.dart';
import '../widgets/admin_common_widgets.dart';

/// 사용자 검색·상세 탭 (P1.B)
///
/// ── 사용자 시나리오 ────────────────────────────────────────
/// 1. 운영자가 검색창에 uid / 이메일 / 닉네임 prefix 중 하나 입력
/// 2. 결과 카드 클릭 → 상세 모달 (프로필 · auth · 최근 활동 · 모더레이션 ·
///    결제 통계 5섹션) 노출
/// 3. 상세에서 `excludeFromStats` / `isAdmin` 플래그 토글 가능
///    (isAdmin 토글은 destructive 감사 로그 자동 기록)
/// ────────────────────────────────────────────────────────────
class AdminUserTab extends StatefulWidget {
  const AdminUserTab({super.key});

  @override
  State<AdminUserTab> createState() => _AdminUserTabState();
}

class _AdminUserTabState extends State<AdminUserTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => false;

  final TextEditingController _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  UserSearchResult? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      setState(() {
        _result = null;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await AdminUserService.search(query: q);
      if (!mounted) return;
      setState(() {
        _result = r;
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

  Future<void> _openDetail(UserSearchHit hit) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _UserDetailDialog(targetUid: hit.uid, summary: hit),
    );
    if (changed == true) {
      // 플래그 변경 시 결과 새로고침
      await _runSearch();
    }
  }

  String get _matchedByLabel {
    switch (_result?.matchedBy) {
      case 'uid':
        return 'uid 정확 매칭';
      case 'email':
        return '이메일 매칭';
      case 'nickname':
        return '닉네임 prefix 매칭';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SearchBar(
          controller: _controller,
          loading: _loading,
          onSubmit: _runSearch,
        ),
        const SizedBox(height: 8),
        const Text(
          '검색 규칙: 28~64자 영숫자 = uid · @ 포함 = 이메일 · 그 외 = 닉네임 prefix',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textDisabled,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),

        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Text(
              '검색 실패: $_error',
              style:
                  const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          )
        else if (_result != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${_result!.items.length}건 — $_matchedByLabel',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (_result!.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: AdminEmptyState(message: '검색 결과 없음'),
            )
          else
            for (final hit in _result!.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _UserSearchCard(
                  hit: hit,
                  onTap: () => _openDetail(hit),
                ),
              ),
        ] else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: AdminEmptyState(message: '검색어를 입력하세요.'),
          ),

        const SizedBox(height: 32),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSubmit;
  const _SearchBar({
    required this.controller,
    required this.loading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'uid / 이메일 / 닉네임 prefix',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => onSubmit(),
            autocorrect: false,
            enableSuggestions: false,
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: loading ? null : onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.onAccent,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          child: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('검색', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _UserSearchCard extends StatelessWidget {
  final UserSearchHit hit;
  final VoidCallback onTap;
  const _UserSearchCard({required this.hit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.surfaceMuted,
              child: Text(
                (hit.nickname?.isNotEmpty ?? false)
                    ? hit.nickname![0]
                    : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hit.nickname ?? '(닉네임 없음)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (hit.isAdmin)
                        const _MiniBadge(text: 'ADMIN', color: AppColors.error),
                      if (hit.excludeFromStats)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: _MiniBadge(
                            text: '통계제외',
                            color: AppColors.warning,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'uid: ${_shortUid(hit.uid)}'
                    '${hit.emailMasked != null ? "  ·  ${hit.emailMasked}" : ""}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textDisabled,
                    ),
                  ),
                  if (hit.region != null || hit.careerGroup != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        [
                          if (hit.region != null) hit.region!,
                          if (hit.careerGroup != null) hit.careerGroup!,
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textDisabled,
            ),
          ],
        ),
      ),
    );
  }

  static String _shortUid(String uid) =>
      uid.length <= 12 ? uid : '${uid.substring(0, 12)}…';
}

class _MiniBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _MiniBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

// ─── 상세 모달 ─────────────────────────────────────────────────

class _UserDetailDialog extends StatefulWidget {
  final String targetUid;
  final UserSearchHit summary;
  const _UserDetailDialog({required this.targetUid, required this.summary});

  @override
  State<_UserDetailDialog> createState() => _UserDetailDialogState();
}

class _UserDetailDialogState extends State<_UserDetailDialog> {
  bool _loading = true;
  String? _error;
  UserDetail? _detail;
  bool _busy = false;
  bool _flagChanged = false;

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
      final d = await AdminUserService.getDetail(targetUid: widget.targetUid);
      if (!mounted) return;
      setState(() {
        _detail = d;
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

  Future<void> _toggleFlag(UserFlag flag, bool nextValue) async {
    final isAdminToggle = flag == UserFlag.isAdmin;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AppConfirmModal(
        title: isAdminToggle
            ? (nextValue ? 'ADMIN 부여' : 'ADMIN 해제')
            : (nextValue ? '통계 제외 켜기' : '통계 제외 끄기'),
        message: isAdminToggle
            ? '대상: ${widget.targetUid}\n\nadmin 권한은 운영 권한 전체에 영향을 줍니다. 신중히 진행하세요.'
            : '대상: ${widget.targetUid}\n\n통계 KPI 계산에서 이 사용자를 ${nextValue ? "제외" : "다시 포함"}합니다.',
        confirmLabel: '진행',
        destructive: isAdminToggle,
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final r = await AdminUserService.toggleFlag(
        targetUid: widget.targetUid,
        flag: flag,
        value: nextValue,
      );
      if (!mounted) return;
      if (r.success) {
        _flagChanged = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${flag.wire} = $nextValue 로 변경됨')),
        );
        await _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('변경 실패')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppModalDialog(
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      borderOpacity: 0.7,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.summary.nickname ?? '(닉네임 없음)',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.targetUid,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textDisabled,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                '불러오기 실패: $_error',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.error,
                ),
              ),
            )
          else if (_detail != null)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.6,
              ),
              child: SingleChildScrollView(
                child: _DetailBody(detail: _detail!, busy: _busy),
              ),
            ),
          if (_detail?.partialErrors.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '일부 섹션 로드 실패: ${_detail!.partialErrors.join(", ")}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.warning,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _toggleFlag(
                            UserFlag.excludeFromStats,
                            _detail?.profile['excludeFromStats'] != true,
                          ),
                  icon: const Icon(Icons.filter_alt_off, size: 18),
                  label: Text(
                    _detail?.profile['excludeFromStats'] == true
                        ? '통계 제외 끄기'
                        : '통계 제외 켜기',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _toggleFlag(
                            UserFlag.isAdmin,
                            _detail?.profile['isAdmin'] != true,
                          ),
                  icon: const Icon(Icons.admin_panel_settings, size: 18),
                  label: Text(
                    _detail?.profile['isAdmin'] == true
                        ? 'ADMIN 해제'
                        : 'ADMIN 부여',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_flagChanged),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final UserDetail detail;
  final bool busy;
  const _DetailBody({required this.detail, required this.busy});

  String _fmtMs(DateTime? d) {
    if (d == null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final profile = detail.profile;
    final auth = detail.auth;
    final moderation = detail.moderation;
    final billing = detail.billing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Section(title: '프로필'),
        _kv('닉네임', profile['nickname']?.toString() ?? '—'),
        _kv('지역', profile['region']?.toString() ?? '—'),
        _kv('연차', profile['careerGroup']?.toString() ?? '—'),
        _kv('connect 통계 제외',
            profile['excludeFromStats'] == true ? '예' : '아니오'),
        _kv('어드민', profile['isAdmin'] == true ? '예' : '아니오'),
        _kv(
          '프로필 생성',
          _fmtMs(_msToDate(profile['createdAtMs'])),
        ),
        const SizedBox(height: 12),

        const _Section(title: 'Auth'),
        if (auth == null)
          const Text(
            '인증 정보 로드 실패',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          )
        else ...[
          _kv('이메일', auth.emailMasked ?? '—'),
          _kv('인증 여부', auth.emailVerified ? '예' : '아니오'),
          _kv('비활성화', auth.disabled ? '예' : '아니오'),
          _kv('Provider', auth.providers.join(', ')),
          _kv('마지막 로그인', _fmtMs(auth.lastSignIn)),
          _kv('Auth 생성', _fmtMs(auth.createdAt)),
        ],
        const SizedBox(height: 12),

        const _Section(title: '모더레이션 통계'),
        if (moderation == null)
          const Text(
            '로드 실패',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          )
        else ...[
          _kv('자동 숨김된 글', '${moderation.hiddenPostCount}건'),
          _kv('신고 누적된 본인 글', '${moderation.reportedAgainstCount}건'),
        ],
        const SizedBox(height: 12),

        const _Section(title: '결제 통계'),
        if (billing == null)
          const Text(
            '로드 실패',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          )
        else ...[
          _kv('결제 완료', '${billing.paidCount}건'),
          _kv('결제 금액 합', '${billing.paidAmountKrw}원'),
          _kv('환불', '${billing.refundCount}건'),
          _kv('마지막 결제', _fmtMs(billing.lastPaidAt)),
        ],
        const SizedBox(height: 12),

        const _Section(title: '최근 활동 50건'),
        if (detail.recentActivity.isEmpty)
          const Text(
            '활동 기록 없음',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          )
        else
          ...detail.recentActivity.take(20).map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.type,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        _fmtMs(e.timestamp),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        if (detail.recentActivity.length > 20)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+ ${detail.recentActivity.length - 20}건 더 (상위 20건만 표시)',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textDisabled,
              ),
            ),
          ),
      ],
    );
  }

  DateTime? _msToDate(dynamic v) {
    if (v is num) {
      return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    }
    return null;
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              k,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textDisabled,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.accent,
        ),
      ),
    );
  }
}
