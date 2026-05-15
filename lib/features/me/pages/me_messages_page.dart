import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../messages/widgets/conversation_panel.dart';
import '../../messages/widgets/thread_list_panel.dart';
import '../widgets/me_page_shell.dart';

/// `/me/messages` (치과 시점)
///
/// 좌측: MePageShell 사이드바 (병원 정보 / 인재풀 …)
/// 우측: 좌(스레드 리스트, 280) / 우(대화창)
///
/// 폭이 좁아질 때는 thread 선택 시 같은 영역에서 토글된다.
class MeMessagesPage extends StatefulWidget {
  const MeMessagesPage({super.key, this.initialThreadId});

  final String? initialThreadId;

  @override
  State<MeMessagesPage> createState() => _MeMessagesPageState();
}

class _MeMessagesPageState extends State<MeMessagesPage> {
  String? _selectedThreadId;

  @override
  void initState() {
    super.initState();
    _selectedThreadId = widget.initialThreadId;
  }

  @override
  Widget build(BuildContext context) {
    return MePageShell(
      title: '메시지',
      activeMenuId: 'messages',
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: SizedBox(
          height: MediaQuery.of(context).size.height - 220,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.divider),
            ),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                if (wide) {
                  return Row(
                    children: [
                      SizedBox(
                        width: 280,
                        child: ThreadListPanel(
                          selectedThreadId: _selectedThreadId,
                          onSelect: (t) =>
                              setState(() => _selectedThreadId = t.id),
                        ),
                      ),
                      const VerticalDivider(
                          width: 1, color: AppColors.divider),
                      Expanded(
                        child: ConversationPanel(threadId: _selectedThreadId),
                      ),
                    ],
                  );
                }
                if (_selectedThreadId == null) {
                  return ThreadListPanel(
                    selectedThreadId: _selectedThreadId,
                    onSelect: (t) =>
                        setState(() => _selectedThreadId = t.id),
                  );
                }
                return ConversationPanel(
                  threadId: _selectedThreadId,
                  onBack: () => setState(() => _selectedThreadId = null),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

