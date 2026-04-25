import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../notifiers/job_filter_notifier.dart';
import '../../services/job_service.dart';
import '../../screen/jobs/job_listings_screen.dart';

/// 치과(공고자) 계정이 앱으로 로그인했을 때 표시되는 공고 열람 전용 화면.
///
/// - 공고 목록 스크롤만 허용
/// - 공고 상세 진입·지원 등 모든 탭 인터랙션 차단
class ClinicReadOnlyShell extends StatelessWidget {
  const ClinicReadOnlyShell({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => JobFilterNotifier()),
        Provider(create: (_) => JobService()),
      ],
      child: const _ClinicReadOnlyView(),
    );
  }
}

class _ClinicReadOnlyView extends StatelessWidget {
  const _ClinicReadOnlyView();

  static void _noOp() {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        backgroundColor: AppColors.appBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          '공고 보기',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            child: const Text('로그아웃', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
      body: Column(
        children: [
          // 안내 배너
          Container(
            width: double.infinity,
            color: const Color(0xFFFFF3CD),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: const [
                Icon(Icons.info_outline, size: 16, color: Color(0xFF856404)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '치과(공고자) 계정은 공고 열람만 가능해요.\n공고 등록은 hygienelab.kr 을 이용해주세요.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF856404),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 공고 목록 (스크롤만 허용)
          Expanded(
            child: const JobListingsScreen(onMapToggle: _noOp, readOnly: true),
          ),
        ],
      ),
    );
  }
}
