import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/message_thread.dart';
import '../../../services/message_service.dart';
import '../../../services/user_directory_service.dart';

/// 좌측 — 내가 참여 중인 스레드 리스트.
class ThreadListPanel extends StatefulWidget {
  const ThreadListPanel({
    super.key,
    required this.selectedThreadId,
    required this.onSelect,
  });

  final String? selectedThreadId;
  final ValueChanged<MessageThread> onSelect;

  @override
  State<ThreadListPanel> createState() => _ThreadListPanelState();
}

class _ThreadListPanelState extends State<ThreadListPanel> {
  final _directory = UserDirectoryService();

  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final myUid = _myUid;
    if (myUid == null) {
      return const Center(child: Text('로그인이 필요해요.'));
    }
    return StreamBuilder<List<MessageThread>>(
      stream: MessageService.watchMyThreads(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                '대화 목록을 불러오지 못했어요.\n${snap.error}',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          );
        }
        final threads = snap.data ?? const <MessageThread>[];
        if (threads.isEmpty) {
          return _EmptyState();
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: threads.length,
          separatorBuilder: (_, __) => const Divider(
            height: 1,
            color: AppColors.divider,
            indent: 12,
            endIndent: 12,
          ),
          itemBuilder: (context, i) {
            final t = threads[i];
            final otherUid = t.otherUidFor(myUid);
            return _ThreadRow(
              thread: t,
              isSelected: t.id == widget.selectedThreadId,
              myUid: myUid,
              otherUid: otherUid,
              directory: _directory,
              onTap: () => widget.onSelect(t),
            );
          },
        );
      },
    );
  }
}

class _ThreadRow extends StatefulWidget {
  const _ThreadRow({
    required this.thread,
    required this.isSelected,
    required this.myUid,
    required this.otherUid,
    required this.directory,
    required this.onTap,
  });

  final MessageThread thread;
  final bool isSelected;
  final String myUid;
  final String otherUid;
  final UserDirectoryService directory;
  final VoidCallback onTap;

  @override
  State<_ThreadRow> createState() => _ThreadRowState();
}

class _ThreadRowState extends State<_ThreadRow> {
  String? _name;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _ThreadRow old) {
    super.didUpdateWidget(old);
    if (old.otherUid != widget.otherUid) {
      _name = null;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final cached = widget.directory.cachedName(widget.otherUid);
    if (cached != null) {
      setState(() => _name = cached);
      return;
    }
    final n = await widget.directory.displayName(widget.otherUid);
    if (mounted) setState(() => _name = n);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.thread;
    final unread = t.unreadFor(widget.myUid);
    final preview = t.lastText.isEmpty
        ? '대화를 시작해 보세요.'
        : (t.lastSenderUid == widget.myUid ? '나: ${t.lastText}' : t.lastText);
    final time = _formatTime(t.lastSentAt ?? t.updatedAt);
    final selectedBg = widget.isSelected
        ? AppColors.surfaceMuted
        : Colors.transparent;
    return InkWell(
      onTap: widget.onTap,
      child: Container(
        color: selectedBg,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.surfaceMuted,
              child: Text(
                _initial(_name ?? '·'),
                style: GoogleFonts.notoSansKr(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _name ?? '...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSansKr(
                            fontSize: 14,
                            fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (time.isNotEmpty)
                        Text(
                          time,
                          style: GoogleFonts.notoSansKr(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSansKr(
                            fontSize: 12,
                            color: unread > 0
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight:
                                unread > 0 ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (unread > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.cardEmphasis,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: GoogleFonts.notoSansKr(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initial(String name) {
    final t = name.trim();
    if (t.isEmpty) return '·';
    return t.characters.first.toUpperCase();
  }

  /// 오늘이면 HH:mm, 어제면 '어제', 그 외엔 'M/d'
  static String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(that).inDays;
    if (diffDays == 0) {
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    if (diffDays == 1) return '어제';
    if (now.year == dt.year) return '${dt.month}/${dt.day}';
    final yy = (dt.year % 100).toString().padLeft(2, '0');
    return '$yy.${dt.month}.${dt.day}';
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline,
                size: 36, color: AppColors.textDisabled),
            const SizedBox(height: 10),
            Text(
              '아직 주고받은 대화가 없어요.',
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '치과·지원자 측에서 대화를 시작하면\n여기로 연결돼요.',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                color: AppColors.textDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
