import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/job.dart';
import '../../services/job_service.dart';
import '../../services/bond_score_service.dart';
import '../../models/activity_log.dart';

// ── 디자인 팔레트 ──
const _kAccent = Color(0xFFF7CBCA);
const _kText = Color(0xFF5D6B6B);
const _kCardBg = Colors.white;

/// 1분 지원 바텀시트
///
/// 최소 입력으로 빠르게 지원하는 UI
class QuickApplySheet extends StatefulWidget {
  final Job job;

  const QuickApplySheet({super.key, required this.job});

  static Future<dynamic> show(BuildContext context, Job job) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickApplySheet(job: job),
    );
  }

  @override
  State<QuickApplySheet> createState() => _QuickApplySheetState();
}

class _QuickApplySheetState extends State<QuickApplySheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();

  String _career = '신입'; // 신입/경력
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  /// 사용자 프로필 자동 로드
  Future<void> _loadUserProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final jobService = JobService();
      final profile = await jobService.getUserProfile(uid);

      if (mounted && profile != null) {
        setState(() {
          _nameController.text = profile['name'] ?? '';
          _phoneController.text = profile['phone'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('⚠️ 프로필 로드 실패: $e');
    }
  }

  /// 지원 제출
  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final jobService = JobService();

      // 지원 데이터 저장
      await jobService.submitApplication(
        jobId: widget.job.id,
        applicantUid: uid,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        career: _career,
        message: _messageController.text.trim(),
      );

      // ★ 포인트 적용
      await BondScoreService.applyEvent(uid, ActivityType.jobApply);

      if (mounted) {
        Navigator.pop(context, true); // 성공 신호 전달
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 지원이 완료되었습니다! +1.0P'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ 지원 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('지원 실패: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '1분 지원',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _kText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.job.clinicName,
                            style: TextStyle(
                              fontSize: 14,
                              color: _kText.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      color: _kText.withOpacity(0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 포인트 안내
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.star,
                        size: 18,
                        color: _kAccent.withOpacity(0.9),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '지원 완료 시 +1.0P 적립됩니다',
                        style: TextStyle(
                          fontSize: 12,
                          color: _kText.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 이름 입력
                const Text(
                  '이름',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: '이름을 입력하세요',
                    hintStyle: TextStyle(color: _kText.withOpacity(0.4)),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '이름을 입력해주세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 연락처 입력
                const Text(
                  '연락처',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: '010-0000-0000',
                    hintStyle: TextStyle(color: _kText.withOpacity(0.4)),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '연락처를 입력해주세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 경력 선택
                const Text(
                  '경력',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children:
                      ['신입', '경력'].map((career) {
                        final isSelected = _career == career;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: career == '신입' ? 8 : 0,
                              left: career == '경력' ? 8 : 0,
                            ),
                            child: InkWell(
                              onTap: () => setState(() => _career = career),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isSelected ? _kAccent : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  career,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isSelected
                                            ? _kText
                                            : _kText.withOpacity(0.6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),

                // 한 줄 메시지 (선택)
                const Text(
                  '한 줄 메시지 (선택)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _messageController,
                  maxLines: 2,
                  maxLength: 100,
                  decoration: InputDecoration(
                    hintText: '지원 동기나 각오 등을 간단히 작성해주세요',
                    hintStyle: TextStyle(color: _kText.withOpacity(0.4)),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 24),

                // 지원하기 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitApplication,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAccent,
                      foregroundColor: _kText,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child:
                        _isSubmitting
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _kText,
                                ),
                              ),
                            )
                            : const Text(
                              '지원하기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
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



