import 'package:flutter/material.dart';

/// 감성 공지 토스트 (4가지 필수)
class BondNotificationToast {
  /// 1. 새 주 시작 (자동 매칭 완료)
  static void showNewWeek(BuildContext context) {
    _showToast(
      context,
      icon: '✨',
      message: '이번 주 페이지가 열렸어',
      subMessage: '새로운 파트너와 함께해요',
    );
  }

  /// 2. 2인으로 시작 (3번째는 곧)
  static void showTwoPersonStart(BuildContext context) {
    _showToast(
      context,
      icon: '🌙',
      message: '이번 주는 조용한 2인 페이지',
      subMessage: '곧 한 명 더 함께할 수 있어요',
    );
  }

  /// 3. 보충 합류
  static void showMemberJoined(BuildContext context) {
    _showToast(
      context,
      icon: '🍃',
      message: '새 바람이 한 칸 들어왔어',
      subMessage: '3명이 함께해요',
    );
  }

  /// 4. 이어가기 성사
  static void showContinuedPair(BuildContext context) {
    _showToast(
      context,
      icon: '💛',
      message: '두 사람이 다음 주도 이어가기로 했어',
      subMessage: '한 자리는 새 바람이 올 거예요',
    );
  }

  static void _showToast(
    BuildContext context, {
    required String icon,
    required String message,
    String? subMessage,
  }) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: _ToastWidget(
            icon: icon,
            message: message,
            subMessage: subMessage,
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }
}

class _ToastWidget extends StatefulWidget {
  final String icon;
  final String message;
  final String? subMessage;

  const _ToastWidget({
    required this.icon,
    required this.message,
    this.subMessage,
  });

  @override
  _ToastWidgetState createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(widget.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.message,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF424242),
                      ),
                    ),
                    if (widget.subMessage != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subMessage!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

