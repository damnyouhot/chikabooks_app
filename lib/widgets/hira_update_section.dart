import 'package:flutter/material.dart';
import '../models/hira_update.dart';
import '../services/hira_update_service.dart';
import 'hira_update_card.dart';

// ── 디자인 팔레트 (성장 탭과 통일) ──
const _kText = Color(0xFF5D6B6B);
const _kShadow2 = Color(0xFFD5E5E5);

/// HIRA 수가/급여 변경 포인트 섹션
class HiraUpdateSection extends StatelessWidget {
  const HiraUpdateSection({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HiraDigest?>(
      future: HiraUpdateService.getTodayDigest(),
      builder: (context, digestSnap) {
        if (digestSnap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final digest = digestSnap.data;
        if (digest == null || digest.topIds.isEmpty) {
          return _buildEmptyState();
        }

        return FutureBuilder<List<HiraUpdate>>(
          future: HiraUpdateService.getUpdates(digest.topIds),
          builder: (context, updatesSnap) {
            if (updatesSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final updates = updatesSnap.data ?? [];
            if (updates.isEmpty) {
              return _buildEmptyState();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 섹션 타이틀
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: _kText,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '오늘의 수가·급여 변경 포인트',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _kText,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Text(
                    '건강보험심사평가원의 최신 변경사항을 확인하세요.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _kText.withOpacity(0.5),
                    ),
                  ),
                ),

                // 업데이트 카드들
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: updates
                        .map((update) => HiraUpdateCard(update: update))
                        .toList(),
                  ),
                ),

                // 더보기 안내 (선택사항)
                if (updates.length >= 3)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Center(
                      child: Text(
                        '최근 14일 내 주요 변경사항 ${updates.length}건',
                        style: TextStyle(
                          fontSize: 11,
                          color: _kText.withOpacity(0.4),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// 빈 상태
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _kShadow2.withOpacity(0.5),
            width: 0.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              size: 40,
              color: _kText.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              '최신 변경사항이 없습니다',
              style: TextStyle(
                fontSize: 14,
                color: _kText.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '새로운 수가·급여 변경사항이 발표되면\n자동으로 업데이트됩니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: _kText.withOpacity(0.4),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

