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
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fn = FirebaseFunctions.instance.httpsCallable(
        'adminListProvisionalProfiles',
      );
      final res = await fn.call();
      final data = Map<String, dynamic>.from(res.data as Map);
      final items = (data['items'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('처리 완료: $clinicName → $decision')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('처리 실패: $e')),
      );
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
      builder: (ctx) => AlertDialog(
        title: Text(isApprove ? '승인 확정' : '거절 처리'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(clinicName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                labelText: isApprove ? '메모 (선택)' : '거절 사유',
                hintText: isApprove
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
            const Icon(Icons.error_outline,
                color: AppColors.error, size: 32),
            const SizedBox(height: 12),
            Text('불러오기 실패: $_error',
                style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.task_alt, size: 36, color: AppColors.success),
              SizedBox(height: 12),
              Text('대기 중인 조건부 승인 건이 없습니다.'),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _ProvisionalCard(
          item: _items[i],
          onApprove: () => _decide(
            uid: _items[i]['uid'] as String,
            profileId: _items[i]['profileId'] as String,
            decision: 'verified',
            clinicName: (_items[i]['clinicName'] ?? '') as String,
          ),
          onReject: () => _decide(
            uid: _items[i]['uid'] as String,
            profileId: _items[i]['profileId'] as String,
            decision: 'rejected',
            clinicName: (_items[i]['clinicName'] ?? '') as String,
          ),
        ),
      ),
    );
  }
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
    final lastCheckAt = lastCheckAtMs != null
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
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '조건부 승인 대기',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent),
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
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
          if (lastCheckAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '최근 검증: ${lastCheckAt.toLocal()}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
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
                  onPressed: () => launchUrl(Uri.parse(
                      'https://www.google.com/search?q=${Uri.encodeComponent(clinicName)}+치과')),
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('Google 검색'),
                ),
              FilledButton.icon(
                onPressed: onApprove,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('승인'),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success),
              ),
              FilledButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('거절'),
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.error),
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
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value.isEmpty ? '-' : value,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
