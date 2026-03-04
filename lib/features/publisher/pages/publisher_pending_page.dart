import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'publisher_shared.dart';
import '../services/clinic_auth_service.dart';

/// 사업자 인증 검토 대기 화면 (/publisher/pending)
class PublisherPendingPage extends StatefulWidget {
  const PublisherPendingPage({super.key});

  @override
  State<PublisherPendingPage> createState() => _PublisherPendingPageState();
}

class _PublisherPendingPageState extends State<PublisherPendingPage> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // 30초마다 승인 여부 폴링
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkApproval();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkApproval() async {
    final status = await ClinicAuthService.getStatus();
    if (!mounted) return;
    if (status.clinicVerified) {
      context.go('/publisher/done');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PubScaffold(
      title: '검토 중',
      showBack: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 애니메이션 아이콘 영역
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFFE082),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    color: Color(0xFFF59E0B),
                    size: 50,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  '서류 확인 중이에요',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: kPubText,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '제출하신 사업자등록증을 검토하고 있어요.\n보통 당일~1영업일 내 처리됩니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: kPubText.withOpacity(0.5),
                    height: 1.7,
                  ),
                ),

                const SizedBox(height: 32),

                // 상태 카드
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        color: Color(0xFFF59E0B),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '검토가 완료되면 공고 작성이 자동으로 열려요.',
                          style: TextStyle(
                            fontSize: 13,
                            color: kPubText.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 새로고침 버튼
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _checkApproval,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('승인 여부 확인하기'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPubBlue,
                      side: const BorderSide(color: kPubBlue),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 문의하기
                TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder:
                          (_) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: const Text(
                              '문의하기',
                              style: TextStyle(fontSize: 16),
                            ),
                            content: const Text(
                              '검토가 늦어지거나 문제가 있으신가요?\n\n이메일로 문의해주세요:\nsupport@chikabooks.com',
                              style: TextStyle(fontSize: 13, height: 1.6),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('닫기'),
                              ),
                            ],
                          ),
                    );
                  },
                  child: Text(
                    '문의하기',
                    style: TextStyle(
                      fontSize: 13,
                      color: kPubText.withOpacity(0.45),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


