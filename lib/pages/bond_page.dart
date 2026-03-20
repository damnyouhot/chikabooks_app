import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../widgets/bond/bond_poll_section.dart';
import 'settings/settings_page.dart';

/// 2번 탭 — 공감투표
class BondPage extends StatefulWidget {
  const BondPage({super.key});

  @override
  State<BondPage> createState() => BondPageState();
}

class BondPageState extends State<BondPage> {
  final _pollKey = GlobalKey<BondPollSectionState>();

  void refreshData() => _pollKey.currentState?.reload();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(child: BondPollSection(key: _pollKey)),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                '공감투표',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.info_outline,
                  color: AppColors.textDisabled,
                  size: 18,
                ),
                onPressed: () => _showConceptDialog(context),
              ),
              IconButton(
                icon: const Icon(
                  Icons.settings_outlined,
                  color: AppColors.textDisabled,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(
            '오늘의 주제에 공감을 표현해보세요.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  void _showConceptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "'공감투표' 탭에 대해서",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '매일 하나의 주제가 등록되고, 여러 보기 중 가장 공감되는 것에 투표하는 공간이에요.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              SizedBox(height: 16),
              Text('👍 공감하기',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text(
                '보기 중 하나에 공감할 수 있어요. 투표 종료 전까지 선택을 바꿀 수 있어요.',
                style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textSecondary),
              ),
              SizedBox(height: 16),
              Text('✍️ 내 보기 추가',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text(
                '기본 보기 외에 직접 새 보기를 작성할 수 있어요. 다른 사람들도 공감할 수 있어요.',
                style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textSecondary),
              ),
              SizedBox(height: 16),
              Text('🏅 결과 확인',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text(
                '투표가 끝나면 공감 수 기준 1~3위에 메달이 부여돼요. 지난 투표 결과도 확인할 수 있어요.',
                style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}
