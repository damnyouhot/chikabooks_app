import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart' show AppRadius, AppSpacing;
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/widgets/app_modal_scaffold.dart';
import '../../../models/notification_prefs.dart';
import '../../../services/notification_prefs_service.dart';
import '../../jobs/web/web_typography.dart';
import '../providers/me_providers.dart';
import '../widgets/me_page_shell.dart';

/// /me/notifications — 알림 설정 페이지
///
/// 구성:
///  1. 채널 토글     : 이메일 / 카카오 알림톡 / 푸시
///  2. 야간 무음     : 21:00 ~ 08:00 알림 보류
///  3. 이벤트 토글   : 8개 트리거 on/off
///  4. 받는 사람     : 멀티 수신자 (원장/실장/인사담당) + 이벤트 매핑
///
/// 저장 위치: `clinics_accounts/{uid}/notificationPrefs/default`
/// 발송 자체는 서버 Cloud Function 이 이 prefs 를 참조해서 fan-out.
class MeNotificationsPage extends ConsumerWidget {
  const MeNotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPrefs = ref.watch(notificationPrefsProvider);

    return MePageShell(
      title: '알림 설정',
      activeMenuId: 'notifications',
      child: asyncPrefs.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(32),
          child: Text('알림 설정을 불러오지 못했습니다: $error',
              style: WebTypo.caption(color: AppColors.error, size: 12)),
        ),
        data: (prefs) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ChannelsCard(prefs: prefs),
            const SizedBox(height: AppSpacing.xxl),
            _SectionTitle('이벤트별 알림'),
            const SizedBox(height: AppSpacing.md),
            _EventsCard(prefs: prefs),
            const SizedBox(height: AppSpacing.xxl),
            _SectionTitle('받는 사람'),
            const SizedBox(height: AppSpacing.md),
            _RecipientsCard(prefs: prefs),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: WebTypo.sectionTitle(color: AppColors.textPrimary));
}

// ══════════════════════════════════════════════════════════════
// 채널 카드
// ══════════════════════════════════════════════════════════════
class _ChannelsCard extends StatelessWidget {
  const _ChannelsCard({required this.prefs});
  final NotificationPrefs prefs;

  Future<void> _set(BuildContext context,
      NotificationChannels next) async {
    try {
      await NotificationPrefsService.updateChannels(next);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')));
    }
  }

  Future<void> _setQuiet(BuildContext context, bool on) async {
    try {
      await NotificationPrefsService.setQuietHours(on);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ch = prefs.channels;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SwitchTile(
            icon: Icons.mail_outline,
            label: '이메일',
            sub: '회원가입 이메일로 발송',
            value: ch.email,
            onChanged: (v) =>
                _set(context, ch.copyWith(email: v)),
          ),
          const Divider(height: 1, color: AppColors.divider),
          _SwitchTile(
            icon: Icons.chat_bubble_outline,
            label: '카카오 알림톡',
            sub: '추후 외주 발송 연동 예정 (1차: 토글만 저장)',
            value: ch.kakaoTalk,
            onChanged: (v) =>
                _set(context, ch.copyWith(kakaoTalk: v)),
          ),
          const Divider(height: 1, color: AppColors.divider),
          _SwitchTile(
            icon: Icons.notifications_active_outlined,
            label: '브라우저 푸시',
            sub: '브라우저 알림 권한 허용 시 발송',
            value: ch.push,
            onChanged: (v) =>
                _set(context, ch.copyWith(push: v)),
          ),
          const Divider(height: 1, color: AppColors.divider),
          _SwitchTile(
            icon: Icons.bedtime_outlined,
            label: '야간 무음 (21:00 ~ 08:00)',
            sub: '긴급 알림은 영향 없음. 일반 알림은 다음 날 09:00에 묶어서 발송.',
            value: prefs.quietHours,
            onChanged: (v) => _setQuiet(context, v),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 이벤트 카드
// ══════════════════════════════════════════════════════════════
class _EventsCard extends StatelessWidget {
  const _EventsCard({required this.prefs});
  final NotificationPrefs prefs;

  Future<void> _set(BuildContext context,
      NotificationEvents next) async {
    try {
      await NotificationPrefsService.updateEvents(next);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = prefs.events;
    final tiles = [
      _evTile(context, 'jobApplied', e.jobApplied,
          (v) => _set(context, e.copyWith(jobApplied: v))),
      _evTile(context, 'jobApplicantStatus', e.jobApplicantStatus,
          (v) => _set(context, e.copyWith(jobApplicantStatus: v))),
      _evTile(context, 'jobExpiring', e.jobExpiring,
          (v) => _set(context, e.copyWith(jobExpiring: v))),
      _evTile(context, 'walletLow', e.walletLow,
          (v) => _set(context, e.copyWith(walletLow: v))),
      _evTile(context, 'walletCharged', e.walletCharged,
          (v) => _set(context, e.copyWith(walletCharged: v))),
      _evTile(context, 'taxIssued', e.taxIssued,
          (v) => _set(context, e.copyWith(taxIssued: v))),
      _evTile(context, 'weeklyDigest', e.weeklyDigest,
          (v) => _set(context, e.copyWith(weeklyDigest: v))),
      _evTile(context, 'announcements', e.announcements,
          (v) => _set(context, e.copyWith(announcements: v))),
    ];
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            tiles[i],
            if (i != tiles.length - 1)
              const Divider(height: 1, color: AppColors.divider),
          ],
        ],
      ),
    );
  }

  Widget _evTile(BuildContext context, String key, bool value,
      ValueChanged<bool> onChanged) {
    return _SwitchTile(
      icon: Icons.fiber_manual_record,
      label: kNotificationEventLabels[key] ?? key,
      sub: null,
      value: value,
      onChanged: onChanged,
      iconSize: 8,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 받는 사람 카드
// ══════════════════════════════════════════════════════════════
class _RecipientsCard extends StatelessWidget {
  const _RecipientsCard({required this.prefs});
  final NotificationPrefs prefs;

  Future<void> _add(BuildContext context) async {
    final r = await showDialog<NotificationRecipient>(
      context: context,
      builder: (_) => const _RecipientDialog(),
    );
    if (r == null) return;
    try {
      await NotificationPrefsService.addRecipient(r);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('추가 실패: $e')));
    }
  }

  Future<void> _edit(BuildContext context,
      NotificationRecipient cur) async {
    final r = await showDialog<NotificationRecipient>(
      context: context,
      builder: (_) => _RecipientDialog(initial: cur),
    );
    if (r == null) return;
    try {
      await NotificationPrefsService.updateRecipient(r);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('수정 실패: $e')));
    }
  }

  Future<void> _remove(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => const AppConfirmModal(
            title: '수신자 삭제',
            message: '이 수신자에게 알림이 발송되지 않습니다.',
            confirmLabel: '삭제',
            destructive: true,
          ),
    );
    if (ok != true) return;
    try {
      await NotificationPrefsService.removeRecipient(id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = prefs.recipients;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                '등록된 수신자가 없습니다. 본인 계정 외에도 원장님·실장님·인사담당자 등을 추가하면 같은 알림을 함께 받을 수 있습니다.',
                style: WebTypo.body(color: AppColors.textSecondary),
              ),
            )
          else
            for (var i = 0; i < list.length; i++) ...[
              _RecipientTile(
                r: list[i],
                onEdit: () => _edit(context, list[i]),
                onRemove: () => _remove(context, list[i].id),
              ),
              if (i != list.length - 1)
                const Divider(
                    height: 1, color: AppColors.divider),
            ],
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _add(context),
              icon: const Icon(Icons.person_add_alt_1, size: 16),
              label: const Text('수신자 추가'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipientTile extends StatelessWidget {
  const _RecipientTile({
    required this.r,
    required this.onEdit,
    required this.onRemove,
  });
  final NotificationRecipient r;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor:
                AppColors.accent.withValues(alpha: 0.12),
            child: Text(
              r.name.isEmpty ? '?' : r.name.characters.first,
              style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(r.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius:
                            BorderRadius.circular(6),
                      ),
                      child: Text(r.role,
                          style: const TextStyle(
                              fontSize: 11,
                              color:
                                  AppColors.textSecondary)),
                    ),
                    if (!r.active) ...[
                      const SizedBox(width: 6),
                      const Text('(일시중지)',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textDisabled))
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (r.email != null && r.email!.isNotEmpty)
                      r.email,
                    if (r.phone != null && r.phone!.isNotEmpty)
                      r.phone,
                  ].whereType<String>().join(' · '),
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary),
                ),
                if (r.events.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: r.events.map((e) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent
                              .withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(6),
                        ),
                        child: Text(
                            kNotificationEventLabels[e] ?? e,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppColors.textSecondary),
          IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, size: 18),
              color: AppColors.error),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 수신자 편집/추가 다이얼로그
// ══════════════════════════════════════════════════════════════
class _RecipientDialog extends StatefulWidget {
  const _RecipientDialog({this.initial});
  final NotificationRecipient? initial;

  @override
  State<_RecipientDialog> createState() => _RecipientDialogState();
}

class _RecipientDialogState extends State<_RecipientDialog> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late String _role;
  late bool _active;
  late Set<String> _events;

  static const _roles = ['원장', '실장', '인사담당', '기타'];

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _name = TextEditingController(text: i?.name ?? '');
    _email = TextEditingController(text: i?.email ?? '');
    _phone = TextEditingController(text: i?.phone ?? '');
    _role = i?.role ?? '기타';
    _active = i?.active ?? true;
    _events = (i?.events ?? const []).toSet();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이름을 입력해 주세요')));
      return;
    }
    final id = widget.initial?.id ??
        DateTime.now().millisecondsSinceEpoch.toString();
    Navigator.pop(
      context,
      NotificationRecipient(
        id: id,
        name: name,
        role: _role,
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        events: _events.toList(),
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppModalDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.initial == null ? '수신자 추가' : '수신자 수정',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _name,
                    decoration:
                        const InputDecoration(labelText: '이름 *'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    items: _roles
                        .map((r) => DropdownMenuItem(
                            value: r, child: Text(r)))
                        .toList(),
                    decoration:
                        const InputDecoration(labelText: '역할'),
                    onChanged: (v) =>
                        setState(() => _role = v ?? _role),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _email,
                    decoration:
                        const InputDecoration(labelText: '이메일'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phone,
                    decoration: const InputDecoration(
                        labelText: '휴대폰 (예: 010-1234-5678)'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                    title: const Text('활성',
                        style: TextStyle(fontSize: 13)),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 4),
                  const Text('받을 알림 (선택 안하면 전체)',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children:
                        kNotificationEventLabels.entries.map((e) {
                      final selected = _events.contains(e.key);
                      return FilterChip(
                        label: Text(e.value,
                            style: const TextStyle(fontSize: 11)),
                        selected: selected,
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              _events.add(e.key);
                            } else {
                              _events.remove(e.key);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  backgroundColor: AppColors.surfaceMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('취소'),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: _submit,
                child: const Text('저장'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 공통 카드 / 스위치 타일
// ══════════════════════════════════════════════════════════════
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.value,
    required this.onChanged,
    this.iconSize = 18,
  });
  final IconData icon;
  final String label;
  final String? sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon,
                size: iconSize,
                color: value
                    ? AppColors.accent
                    : AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(sub!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}
