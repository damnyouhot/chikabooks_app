import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../models/message_thread.dart';
import '../../../messages/widgets/conversation_panel.dart';
import '../../../messages/widgets/thread_list_panel.dart';
import '../widgets/applicant_web_shell.dart';

/// `/me/messages` (지원자 시점)
///
/// 좌측: 사이드바
/// 우측: 좌(스레드 리스트, 320) / 우(대화창, 나머지)
///
/// 폭이 좁아질 때 (< 720) 는 thread 선택 시 같은 영역에서 대화창으로 토글된다.
class ApplicantMessagesPage extends StatefulWidget {
  const ApplicantMessagesPage({super.key});

  @override
  State<ApplicantMessagesPage> createState() => _ApplicantMessagesPageState();
}

class _ApplicantMessagesPageState extends State<ApplicantMessagesPage> {
  String? _selectedThreadId;

  @override
  Widget build(BuildContext context) {
    return ApplicantWebShell(
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PageHeader(),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius:
                        BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.divider),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: wide
                      ? _WideLayout(
                          selectedThreadId: _selectedThreadId,
                          onSelect: (t) =>
                              setState(() => _selectedThreadId = t.id),
                        )
                      : _NarrowLayout(
                          selectedThreadId: _selectedThreadId,
                          onSelect: (t) =>
                              setState(() => _selectedThreadId = t.id),
                          onBack: () =>
                              setState(() => _selectedThreadId = null),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.selectedThreadId,
    required this.onSelect,
  });
  final String? selectedThreadId;
  final ValueChanged<MessageThread> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 300,
          child: ThreadListPanel(
            selectedThreadId: selectedThreadId,
            onSelect: onSelect,
          ),
        ),
        const VerticalDivider(width: 1, color: AppColors.divider),
        Expanded(
          child: ConversationPanel(threadId: selectedThreadId),
        ),
      ],
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({
    required this.selectedThreadId,
    required this.onSelect,
    required this.onBack,
  });
  final String? selectedThreadId;
  final ValueChanged<MessageThread> onSelect;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    if (selectedThreadId == null) {
      return ThreadListPanel(
        selectedThreadId: selectedThreadId,
        onSelect: onSelect,
      );
    }
    return ConversationPanel(
      threadId: selectedThreadId,
      onBack: onBack,
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '메시지',
            style: GoogleFonts.notoSansKr(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '치과·지원자와 1:1 로 대화할 수 있어요. 텍스트만 주고받을 수 있어요. (이미지·푸시는 곧 지원돼요)',
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
