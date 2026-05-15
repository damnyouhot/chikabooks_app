import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../widgets/thread_list_panel.dart';
import 'conversation_page.dart';

/// 모바일 — 1:1 메시지 스레드 리스트 화면.
///
/// 진입: 커리어 탭의 "메시지" 바로가기 카드.
/// - 좌측 = (모바일이라 좌우 분할 없음) 단일 컬럼 리스트
/// - 항목 탭 시 [MobileConversationPage] 로 push
class MobileMessagesPage extends StatefulWidget {
  const MobileMessagesPage({super.key});

  @override
  State<MobileMessagesPage> createState() => _MobileMessagesPageState();
}

class _MobileMessagesPageState extends State<MobileMessagesPage> {
  String? _selectedThreadId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          '메시지',
          style: GoogleFonts.notoSansKr(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: ThreadListPanel(
        selectedThreadId: _selectedThreadId,
        onSelect: (t) async {
          setState(() => _selectedThreadId = t.id);
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MobileConversationPage(threadId: t.id),
            ),
          );
          // 대화창에서 pop 으로 돌아오면 selection 해제 (목록만 강조 안 남도록)
          if (mounted) setState(() => _selectedThreadId = null);
        },
      ),
    );
  }
}
