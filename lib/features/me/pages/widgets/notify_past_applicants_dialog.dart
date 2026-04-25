import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart' show AppRadius;
import '../../../../models/applicant_pool_entry.dart';

class NotifyPastResult {
  final String jobId;
  final String? message;
  const NotifyPastResult({required this.jobId, this.message});
}

/// 풀에서 다중 선택한 지원자에게 신규 공고 안내 이메일을 발송하기 위한 다이얼로그.
///
/// 1차는 채널이 **이메일만** 이며, 실제 발송은 Cloud Function 이 큐에 적재하면
/// 워커(외주 또는 SES)가 처리한다.
class NotifyPastApplicantsDialog extends StatefulWidget {
  const NotifyPastApplicantsDialog({super.key, required this.applicants});
  final List<JoinedApplicant> applicants;

  @override
  State<NotifyPastApplicantsDialog> createState() =>
      _NotifyPastApplicantsDialogState();
}

class _NotifyPastApplicantsDialogState
    extends State<NotifyPastApplicantsDialog> {
  String? _selectedJobId;
  final _msgCtrl = TextEditingController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return AlertDialog(
      title: const Text('신규 공고로 재알림 (이메일)'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.2)),
                ),
                child: Text(
                  '${widget.applicants.length}명에게 새 공고 안내 이메일을 보냅니다.\n'
                  '24시간 내 같은 사람에게 두 번 보낼 수 없도록 서버에서 자동 차단해요.',
                  style: const TextStyle(
                      height: 1.5, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 14),
              if (uid == null)
                const Text('로그인 정보가 없어요.')
              else
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('jobs')
                      .where('createdBy', isEqualTo: uid)
                      .orderBy('createdAt', descending: true)
                      .limit(40)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(8),
                        child: Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 2)),
                      );
                    }
                    final docs = snap.data?.docs ?? [];
                    final published = docs.where((d) {
                      final s = d.data()['status'] as String? ?? '';
                      return s == 'published' ||
                          s == 'pending' ||
                          s == 'approved';
                    }).toList();
                    if (published.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warning
                              .withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Text(
                            '발송할 공고가 없어요. 먼저 새 공고를 발행해 주세요.'),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedJobId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '안내할 공고 선택',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: published
                          .map((d) => DropdownMenuItem(
                                value: d.id,
                                child: Text(
                                  (d.data()['title'] as String?) ?? d.id,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedJobId = v),
                    );
                  },
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _msgCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: '추가 메시지 (선택)',
                  hintText:
                      '예: 지난번 지원해주신 ○○ 포지션과 비슷한 자리가 새로 열렸어요.',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소')),
        FilledButton.icon(
          onPressed: _selectedJobId == null
              ? null
              : () => Navigator.pop(
                    context,
                    NotifyPastResult(
                      jobId: _selectedJobId!,
                      message: _msgCtrl.text.trim().isEmpty
                          ? null
                          : _msgCtrl.text.trim(),
                    ),
                  ),
          icon: const Icon(Icons.send_outlined, size: 16),
          label: const Text('이메일 발송 예약'),
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent),
        ),
      ],
    );
  }
}
