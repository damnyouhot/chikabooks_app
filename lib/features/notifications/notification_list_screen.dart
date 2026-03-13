import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../services/contact_request_service.dart';

/// 알림 목록 화면
///
/// 연락처 요청 알림을 포함한 앱 내 모든 알림 표시
class NotificationListScreen extends StatelessWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          '알림',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: ContactRequestService.watchMyNotifications(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snap.data ?? [];

          if (notifications.isEmpty) {
            return _buildEmpty();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) =>
                _NotificationCard(data: notifications[i]),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none,
              size: 56, color: AppColors.textDisabled),
          SizedBox(height: 16),
          Text(
            '새로운 알림이 없습니다.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 알림 카드
// ═══════════════════════════════════════════════════════════

class _NotificationCard extends StatefulWidget {
  final Map<String, dynamic> data;
  const _NotificationCard({required this.data});

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  bool _processing = false;

  String get _type => widget.data['type'] as String? ?? '';
  String get _title => widget.data['title'] as String? ?? '';
  String get _body => widget.data['body'] as String? ?? '';
  bool get _read => widget.data['read'] as bool? ?? false;
  String get _id => widget.data['id'] as String? ?? '';
  Map<String, dynamic> get _extra =>
      widget.data['data'] as Map<String, dynamic>? ?? {};

  DateTime? get _createdAt {
    final ts = widget.data['createdAt'];
    if (ts is Timestamp) return ts.toDate();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!_read) ContactRequestService.markAsRead(_id);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _read ? AppColors.white : AppColors.accent.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _read
                ? AppColors.divider
                : AppColors.accent.withOpacity(0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                _iconForType(),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (!_read)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // 본문
            Text(
              _body,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),

            // 시간
            if (_createdAt != null) ...[
              const SizedBox(height: 6),
              Text(
                _formatTime(_createdAt!),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textDisabled,
                ),
              ),
            ],

            // 연락처 요청 액션 버튼
            if (_type == 'contact_request') ...[
              const SizedBox(height: 12),
              _buildContactActions(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _iconForType() {
    final IconData icon;
    final Color color;

    switch (_type) {
      case 'contact_request':
        icon = Icons.mail_outline;
        color = AppColors.warning;
        break;
      case 'contact_approved':
        icon = Icons.check_circle_outline;
        color = AppColors.success;
        break;
      default:
        icon = Icons.notifications_outlined;
        color = AppColors.accent;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Widget _buildContactActions() {
    final applicationId = _extra['applicationId'] as String? ?? '';
    if (applicationId.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _processing
                ? null
                : () => _handleReject(applicationId),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.divider),
              padding:
                  const EdgeInsets.symmetric(vertical: 10),
            ),
            child: const Text('거절',
                style: TextStyle(fontSize: 13)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            onPressed: _processing
                ? null
                : () => _handleApprove(applicationId),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              padding:
                  const EdgeInsets.symmetric(vertical: 10),
            ),
            child: _processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: AppColors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('연락처 공개 승인',
                    style: TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Future<void> _handleApprove(String applicationId) async {
    setState(() => _processing = true);
    try {
      await ContactRequestService.approveContact(
        applicationId: applicationId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('연락처가 공개되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _handleReject(String applicationId) async {
    setState(() => _processing = true);
    try {
      await ContactRequestService.rejectContact(
        applicationId: applicationId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('연락처 요청을 거절했습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return DateFormat('M월 d일').format(dt);
  }
}
