import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';

/// 운영자 — 조건부 승인(provisional) 프로필 검토
///
/// `adminListProvisionalProfiles` 콜러블로 자동 1~4단계 통과한 프로필 목록을
/// 가져와 운영자가 사업자등록증/주소/홈페이지 등을 직접 확인 후
/// `adminSetProfileVerification` 으로 verified 또는 rejected 처리.
class AdminVerifyTab extends StatefulWidget {
  const AdminVerifyTab({super.key});

  @override
  State<AdminVerifyTab> createState() => _AdminVerifyTabState();
}

class _AdminVerifyTabState extends State<AdminVerifyTab> {
  bool _loading = true;
  String? _error;
  String? _profileQueueError;
  String? _nameQueueError;
  String? _historyError;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _nameRequests = [];
  List<Map<String, dynamic>> _historyItems = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _profileQueueError = null;
      _nameQueueError = null;
      _historyError = null;
    });
    final fn = FirebaseFunctions.instance.httpsCallable(
      'adminListProvisionalProfiles',
    );
    final nameFn = FirebaseFunctions.instance.httpsCallable(
      'adminListBusinessNameReviewRequests',
    );
    final historyFn = FirebaseFunctions.instance.httpsCallable(
      'adminListVerificationReviewHistory',
    );

    List<Map<String, dynamic>> items = [];
    List<Map<String, dynamic>> nameRequests = [];
    List<Map<String, dynamic>> historyItems = [];
    String? profileError;
    String? nameError;
    String? historyError;

    try {
      final res = await fn.call();
      final data = Map<String, dynamic>.from(res.data as Map);
      items =
          (data['items'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
    } catch (e) {
      profileError = _errorText(e);
    }

    try {
      final nameRes = await nameFn.call();
      final nameData = Map<String, dynamic>.from(nameRes.data as Map);
      nameRequests =
          (nameData['items'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
    } catch (e) {
      nameError = _errorText(e);
    }

    try {
      final historyRes = await historyFn.call();
      final historyData = Map<String, dynamic>.from(historyRes.data as Map);
      historyItems =
          (historyData['items'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
    } catch (e) {
      historyError = _errorText(e);
    }

    if (!mounted) return;
    setState(() {
      _items = items;
      _nameRequests = nameRequests;
      _historyItems = historyItems;
      _profileQueueError = profileError;
      _nameQueueError = nameError;
      _historyError = historyError;
      _error =
          profileError != null && nameError != null && historyError != null
              ? '조건부 승인 큐: $profileError\n'
                  '상호 확인 큐: $nameError\n'
                  '처리 이력: $historyError'
              : null;
      _loading = false;
    });
  }

  String _errorText(Object e) {
    if (e is FirebaseFunctionsException) {
      return '[${e.code}] ${e.message ?? e.details ?? e.toString()}';
    }
    return e.toString();
  }

  Future<void> _resolveNameRequest({
    required String requestId,
    required String decision,
    required String displayName,
    required String reviewReason,
  }) async {
    final note = await _askNameReviewNote(
      decision: decision,
      displayName: displayName,
      reviewReason: reviewReason,
    );
    if (note == null) return;
    try {
      final fn = FirebaseFunctions.instance.httpsCallable(
        'adminResolveBusinessNameReview',
      );
      await fn.call({
        'requestId': requestId,
        'decision': decision,
        'note': note,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('상호 확인 요청 처리 완료: $decision')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('처리 실패: $e')));
    }
  }

  Future<String?> _askNameReviewNote({
    required String decision,
    required String displayName,
    required String reviewReason,
  }) {
    final ctrl = TextEditingController();
    final approved = decision == 'approved';
    final isOcrIssue = reviewReason == 'registered_name_ocr_error';
    return showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              isOcrIssue
                  ? (approved ? 'OCR 상호 확인 완료' : 'OCR 상호 반려')
                  : (approved ? '노출명 승인' : '노출명 반려'),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                    labelText: approved ? '메모 (선택)' : '반려 사유',
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: Text(approved ? '승인' : '반려'),
              ),
            ],
          ),
    );
  }

  Future<void> _decide({
    required String uid,
    required String profileId,
    required String decision,
    required String clinicName,
  }) async {
    final note = await _askNote(decision: decision, clinicName: clinicName);
    if (note == null) return;
    try {
      final fn = FirebaseFunctions.instance.httpsCallable(
        'adminSetProfileVerification',
      );
      await fn.call({
        'uid': uid,
        'profileId': profileId,
        'decision': decision,
        'note': note,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('처리 완료: $clinicName → $decision')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('처리 실패: $e')));
    }
  }

  Future<String?> _askNote({
    required String decision,
    required String clinicName,
  }) async {
    final ctrl = TextEditingController();
    final isApprove = decision == 'verified';
    return showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(isApprove ? '승인 확정' : '거절 처리'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  clinicName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                    labelText: isApprove ? '메모 (선택)' : '거절 사유',
                    hintText:
                        isApprove
                            ? '확인한 정보 메모 (예: 홈페이지 확인 OK)'
                            : '예: 등록증 사진 위조 의심',
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isApprove ? AppColors.success : AppColors.error,
                ),
                child: Text(isApprove ? '승인' : '거절'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 32),
            const SizedBox(height: 12),
            Text(
              '불러오기 실패: $_error',
              style: const TextStyle(color: AppColors.error),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    final queueWarnings = <_QueueWarning>[
      if (_nameQueueError != null)
        _QueueWarning(title: '상호 확인 큐 로드 실패', message: _nameQueueError!),
      if (_profileQueueError != null)
        _QueueWarning(title: '조건부 승인 큐 로드 실패', message: _profileQueueError!),
      if (_historyError != null)
        _QueueWarning(title: '처리 이력 로드 실패', message: _historyError!),
    ];
    if (_items.isEmpty &&
        _nameRequests.isEmpty &&
        _historyItems.isEmpty &&
        queueWarnings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.task_alt, size: 36, color: AppColors.success),
              SizedBox(height: 12),
              Text('대기 중인 인증 검토 건이 없습니다.'),
            ],
          ),
        ),
      );
    }
    final children = <Widget>[
      for (final warning in queueWarnings)
        _QueueWarningCard(warning: warning, onRetry: _load),
      if (_nameRequests.isNotEmpty) ...[
        _SectionHeader(
          title: '상호 확인 대기',
          subtitle: '${_nameRequests.length}건',
        ),
        for (final item in _nameRequests)
          _NameReviewCard(
            item: item,
            onApprove:
                () => _resolveNameRequest(
                  requestId: item['id'] as String,
                  decision: 'approved',
                  displayName: (item['displayName'] ?? '') as String,
                  reviewReason: (item['reviewReason'] ?? '') as String,
                ),
            onReject:
                () => _resolveNameRequest(
                  requestId: item['id'] as String,
                  decision: 'rejected',
                  displayName: (item['displayName'] ?? '') as String,
                  reviewReason: (item['reviewReason'] ?? '') as String,
                ),
          ),
      ],
      if (_items.isNotEmpty) ...[
        _SectionHeader(title: '사업자 인증 대기', subtitle: '${_items.length}건'),
        for (final item in _items)
          _ProvisionalCard(
            item: item,
            onApprove:
                () => _decide(
                  uid: item['uid'] as String,
                  profileId: item['profileId'] as String,
                  decision: 'verified',
                  clinicName: (item['clinicName'] ?? '') as String,
                ),
            onReject:
                () => _decide(
                  uid: item['uid'] as String,
                  profileId: item['profileId'] as String,
                  decision: 'rejected',
                  clinicName: (item['clinicName'] ?? '') as String,
                ),
          ),
      ],
      if (_nameRequests.isEmpty && _items.isEmpty)
        const _AllQueuesClearedCard(),
      if (_historyItems.isNotEmpty) ...[
        _SectionHeader(title: '최근 처리 내역', subtitle: '${_historyItems.length}건'),
        for (final item in _historyItems) _ReviewHistoryCard(item: item),
      ],
    ];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AllQueuesClearedCard extends StatelessWidget {
  const _AllQueuesClearedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: const Row(
        children: [
          Icon(Icons.task_alt, size: 22, color: AppColors.success),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '대기 중인 인증 검토 건은 없습니다. 아래에서 최근 처리 내역을 확인할 수 있습니다.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewHistoryCard extends StatelessWidget {
  const _ReviewHistoryCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final type = item['type']?.toString() ?? '';
    final status = item['status']?.toString() ?? '';
    final clinicName = item['clinicName']?.toString() ?? '';
    final displayName = item['displayName']?.toString() ?? '';
    final ownerName = item['ownerName']?.toString() ?? '';
    final address = item['address']?.toString() ?? '';
    final bizNo = item['bizNo']?.toString() ?? '';
    final adminNote = item['adminNote']?.toString() ?? '';
    final reviewedAt = _formatMillis(item['reviewedAt']);
    final isRejected = status == 'rejected';
    final isNameReview = type == 'business_name_review';
    final color = isRejected ? AppColors.error : AppColors.success;
    final title =
        clinicName.isNotEmpty
            ? clinicName
            : (displayName.isNotEmpty ? displayName : '이름 없음');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: color.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _HistoryBadge(
                label: _statusLabel(type: type, status: status),
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _row('구분', isNameReview ? '상호 확인' : '사업자 인증'),
          if (displayName.isNotEmpty && displayName != clinicName)
            _row('노출명', displayName),
          if (bizNo.isNotEmpty) _row('사업자번호', bizNo),
          if (ownerName.isNotEmpty) _row('대표자', ownerName),
          if (address.isNotEmpty) _row('주소', address),
          _row('처리일시', reviewedAt),
          if (adminNote.isNotEmpty) _row('메모', adminNote),
        ],
      ),
    );
  }

  static String _statusLabel({required String type, required String status}) {
    if (type == 'business_name_review') {
      return status == 'rejected' ? '상호 반려' : '상호 승인';
    }
    return status == 'rejected' ? '인증 거절' : '확인 완료';
  }

  static String _formatMillis(Object? raw) {
    final millis = raw is num ? raw.toInt() : null;
    if (millis == null || millis <= 0) return '-';
    final dt = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${dt.year}.${two(dt.month)}.${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

class _HistoryBadge extends StatelessWidget {
  const _HistoryBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _QueueWarning {
  const _QueueWarning({required this.title, required this.message});

  final String title;
  final String message;
}

class _QueueWarningCard extends StatelessWidget {
  const _QueueWarningCard({required this.warning, required this.onRetry});

  final _QueueWarning warning;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  warning.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  warning.message,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('재시도')),
        ],
      ),
    );
  }
}

class _NameReviewCard extends StatelessWidget {
  const _NameReviewCard({
    required this.item,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> item;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final registered = (item['registeredClinicName'] ?? '') as String;
    final display = (item['displayName'] ?? '') as String;
    final reviewReason = (item['reviewReason'] ?? '') as String;
    final isOcrIssue = reviewReason == 'registered_name_ocr_error';
    final owner = (item['ownerName'] ?? '') as String;
    final address = (item['address'] ?? '') as String;
    final email = item['requesterEmail']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isOcrIssue ? 'OCR 상호 확인 요청' : '상호 확인 요청',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '관리자 확인 대기',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _row('요청 유형', isOcrIssue ? '등록증상 상호 OCR 오류' : '노출명 불일치 확인'),
          _row('등록증 상호', registered),
          _row('노출명', display),
          _row('대표자', owner),
          _row('주소', address),
          _row('요청 계정', email),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (registered.isNotEmpty)
                OutlinedButton.icon(
                  onPressed:
                      () => launchUrl(
                        Uri.parse(
                          'https://www.google.com/search?q=${Uri.encodeComponent('$registered $display')}',
                        ),
                      ),
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('검색'),
                ),
              FilledButton.icon(
                onPressed: onApprove,
                icon: const Icon(Icons.check, size: 16),
                label: Text(isOcrIssue ? '확인 완료' : '노출명 승인'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                ),
              ),
              FilledButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('반려'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

class _ProvisionalCard extends StatelessWidget {
  const _ProvisionalCard({
    required this.item,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> item;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final clinicName = (item['clinicName'] ?? '') as String;
    final displayName = (item['displayName'] ?? '') as String;
    final address = (item['address'] ?? '') as String;
    final ownerName = (item['ownerName'] ?? '') as String;
    final bizNo = (item['bizNo'] ?? '') as String;
    final docUrl = item['bizRegImageUrl'] as String?;
    final hiraMatched = item['hiraMatched'] as bool?;
    final hiraLevel = item['hiraMatchLevel'] as String?;
    final hiraNote = item['hiraNote'] as String?;
    final lastCheckAtMs = item['lastCheckAt'] as num?;
    final lastCheckAt =
        lastCheckAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(lastCheckAtMs.toInt())
            : null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  clinicName.isNotEmpty
                      ? clinicName
                      : (displayName.isNotEmpty ? displayName : '이름 없음'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '조건부 승인 대기',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _row('사업자번호', bizNo),
          _row('대표자', ownerName),
          _row('주소', address),
          _row(
            '심평원 대조',
            hiraMatched == true
                ? '일치 (${hiraLevel ?? "-"})'
                : '불일치/없음 (${hiraLevel ?? "none"})',
          ),
          if (hiraNote != null && hiraNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '메모: $hiraNote',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (lastCheckAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '최근 검증: ${lastCheckAt.toLocal()}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (docUrl != null && docUrl.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(docUrl)),
                  icon: const Icon(Icons.image_outlined, size: 16),
                  label: const Text('등록증 보기'),
                ),
              if (clinicName.isNotEmpty)
                OutlinedButton.icon(
                  onPressed:
                      () => launchUrl(
                        Uri.parse(
                          'https://www.google.com/search?q=${Uri.encodeComponent(clinicName)}+치과',
                        ),
                      ),
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('Google 검색'),
                ),
              FilledButton.icon(
                onPressed: onApprove,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('승인'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                ),
              ),
              FilledButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('거절'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
