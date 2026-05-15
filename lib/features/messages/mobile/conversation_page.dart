import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../widgets/conversation_panel.dart';

/// 모바일 — 단일 대화창 화면.
///
/// [ConversationPanel] 자체가 헤더(상대 이름) + 메시지 목록 + 입력창을 모두
/// 그리므로, 별도 [AppBar] 를 두지 않고 패널 헤더의 뒤로가기 버튼([onBack])
/// 으로 pop 한다. 이중 헤더로 인한 시각적 중복을 피하기 위함.
class MobileConversationPage extends StatelessWidget {
  const MobileConversationPage({super.key, required this.threadId});

  final String threadId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: SafeArea(
        child: ConversationPanel(
          threadId: threadId,
          onBack: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}
