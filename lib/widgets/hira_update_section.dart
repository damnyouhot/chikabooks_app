import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/hira_update.dart';
import '../services/hira_update_service.dart';
import 'hira_update_card.dart';
import 'hira_update_compact_item.dart';

// ── 디자인 팔레트 (성장 탭과 통일) ──
const _kText = Color(0xFF5D6B6B);
const _kShadow2 = Color(0xFFD5E5E5);

/// HIRA 수가/급여 변경 포인트 섹션
class HiraUpdateSection extends StatelessWidget {
  const HiraUpdateSection({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🔍 HIRA: HiraUpdateSection building...');
    return FutureBuilder<List<HiraUpdate>>(
      future: HiraUpdateService.getAllUpdates(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final updates = snapshot.data ?? [];
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
                  const Expanded(
                    child: Text(
                      '수가·급여 변경 포인트 리스트\n(건강보험심사평가원)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kText,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                '최근 3개월 간 ${updates.length}건의 변경사항',
                style: TextStyle(
                  fontSize: 12,
                  color: _kText.withOpacity(0.5),
                ),
              ),
            ),

            // 상위 3건: 전체 카드
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: updates
                    .take(3)
                    .map((update) => HiraUpdateCard(update: update))
                    .toList(),
              ),
            ),

            // 4건 이후: 간단한 리스트
            if (updates.length > 3) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '이전 항목',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kText.withOpacity(0.6),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: updates
                      .skip(3)
                      .map((update) => HiraUpdateCompactItem(update: update))
                      .toList(),
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
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

