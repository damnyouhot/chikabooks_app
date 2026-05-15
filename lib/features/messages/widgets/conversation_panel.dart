import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../models/message.dart';
import '../../../models/message_thread.dart';
import '../../../services/message_service.dart';
import '../../../services/user_directory_service.dart';

/// 우측 — 단일 thread 의 메시지 목록 + 입력창.
///
/// `threadId` 가 null 이면 빈 안내 화면을 보여준다.
class ConversationPanel extends StatefulWidget {
  const ConversationPanel({
    super.key,
    required this.threadId,
    this.onBack,
  });

  final String? threadId;

  /// 좁은 폭에서 뒤로가기 (스레드 리스트로 복귀) 버튼을 보일지 결정.
  /// null 이면 버튼 숨김.
  final VoidCallback? onBack;

  @override
  State<ConversationPanel> createState() => _ConversationPanelState();
}

class _ConversationPanelState extends State<ConversationPanel> {
  final _input = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _directory = UserDirectoryService();

  bool _sending = false;
  String? _otherName;
  String? _resolvedForUid;

  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _markReadAndResolve();
  }

  @override
  void didUpdateWidget(covariant ConversationPanel old) {
    super.didUpdateWidget(old);
    if (old.threadId != widget.threadId) {
      _otherName = null;
      _resolvedForUid = null;
      _markReadAndResolve();
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _markReadAndResolve() async {
    final tid = widget.threadId;
    if (tid == null) return;
    // 진입 시 안 읽음 0 처리.
    MessageService.markRead(tid);
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    final tid = widget.threadId;
    if (text.isEmpty || tid == null || _sending) return;
    setState(() => _sending = true);
    try {
      await MessageService.sendMessage(threadId: tid, text: text);
      _input.clear();
      // 다음 프레임에 스크롤 끝으로.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollCtrl.hasClients) return;
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('전송 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tid = widget.threadId;
    final myUid = _myUid;

    if (tid == null) {
      return _EmptyConversation();
    }
    if (myUid == null) {
      return const Center(child: Text('로그인이 필요해요.'));
    }

    return StreamBuilder<MessageThread?>(
      stream: MessageService.watchThread(tid),
      builder: (context, threadSnap) {
        final thread = threadSnap.data;
        final otherUid = thread?.otherUidFor(myUid) ?? '';
        if (otherUid.isNotEmpty && otherUid != _resolvedForUid) {
          _resolvedForUid = otherUid;
          _directory.displayName(otherUid).then((n) {
            if (mounted) setState(() => _otherName = n);
          });
        }
        // 진입할 때마다 markRead (다른 기기에서 읽지 않은 카운트가 발생하면 정리).
        if (thread != null && thread.unreadFor(myUid) > 0) {
          MessageService.markRead(tid);
        }
        return Column(
          children: [
            _ConversationHeader(
              name: _otherName ?? '...',
              onBack: widget.onBack,
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: _MessageStream(
                threadId: tid,
                myUid: myUid,
                scrollCtrl: _scrollCtrl,
              ),
            ),
            _Composer(
              controller: _input,
              sending: _sending,
              onSend: _send,
            ),
          ],
        );
      },
    );
  }
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({
    required this.name,
    this.onBack,
  });
  final String name;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: '대화 목록으로',
              onPressed: onBack,
            ),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.surfaceMuted,
            child: Text(
              name.isNotEmpty ? name.characters.first.toUpperCase() : '·',
              style: GoogleFonts.notoSansKr(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSansKr(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageStream extends StatefulWidget {
  const _MessageStream({
    required this.threadId,
    required this.myUid,
    required this.scrollCtrl,
  });
  final String threadId;
  final String myUid;
  final ScrollController scrollCtrl;

  @override
  State<_MessageStream> createState() => _MessageStreamState();
}

class _MessageStreamState extends State<_MessageStream> {
  int _lastCount = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Message>>(
      stream: MessageService.watchMessages(widget.threadId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                '메시지를 불러오지 못했어요.\n${snap.error}',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          );
        }
        final list = snap.data ?? const <Message>[];
        // 새로운 메시지가 도착하면 자동으로 끝까지 스크롤.
        if (list.length != _lastCount) {
          _lastCount = list.length;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (widget.scrollCtrl.hasClients) {
              widget.scrollCtrl.jumpTo(
                widget.scrollCtrl.position.maxScrollExtent,
              );
            }
          });
        }
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '대화를 시작해 보세요.',
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          );
        }
        return ListView.builder(
          controller: widget.scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final msg = list[i];
            final mine = msg.senderUid == widget.myUid;
            final showTime = i == list.length - 1 ||
                list[i + 1].senderUid != msg.senderUid ||
                _minutesBetween(list[i + 1].sentAt, msg.sentAt) > 1;
            return _Bubble(message: msg, mine: mine, showTime: showTime);
          },
        );
      },
    );
  }

  static int _minutesBetween(DateTime? a, DateTime? b) {
    if (a == null || b == null) return 99;
    return a.difference(b).inMinutes.abs();
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.showTime,
  });
  final Message message;
  final bool mine;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
      bottomLeft: Radius.circular(mine ? 14 : 4),
      bottomRight: Radius.circular(mine ? 4 : 14),
    );
    final bg = mine ? AppColors.cardPrimary : AppColors.surfaceMuted;
    final fg = mine ? AppColors.onCardPrimary : AppColors.textPrimary;
    final time = _formatTime(message.sentAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (mine && showTime)
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 2),
              child: Text(
                time,
                style: GoogleFonts.notoSansKr(
                  fontSize: 10,
                  color: AppColors.textDisabled,
                ),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: bg, borderRadius: radius),
              child: Text(
                message.text,
                style: GoogleFonts.notoSansKr(
                  fontSize: 14,
                  height: 1.4,
                  color: fg,
                ),
              ),
            ),
          ),
          if (!mine && showTime)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 2),
              child: Text(
                time,
                style: GoogleFonts.notoSansKr(
                  fontSize: 10,
                  color: AppColors.textDisabled,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final ampm = dt.hour < 12 ? '오전' : '오후';
    final h12 = dt.hour == 0
        ? 12
        : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$ampm $h12:$mm';
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              style: GoogleFonts.notoSansKr(fontSize: 14, height: 1.4),
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요',
                hintStyle: GoogleFonts.notoSansKr(
                  fontSize: 14,
                  color: AppColors.textDisabled,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide:
                      const BorderSide(color: AppColors.cardPrimary, width: 1.4),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cardPrimary,
                foregroundColor: AppColors.onCardPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: sending ? null : onSend,
              child: sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onCardPrimary,
                      ),
                    )
                  : Text(
                      '보내기',
                      style: GoogleFonts.notoSansKr(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_outlined,
                size: 56, color: AppColors.textDisabled),
            const SizedBox(height: 12),
            Text(
              '대화를 선택하세요',
              style: GoogleFonts.notoSansKr(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '왼쪽 목록에서 대화를 선택하면 메시지를 볼 수 있어요.',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

