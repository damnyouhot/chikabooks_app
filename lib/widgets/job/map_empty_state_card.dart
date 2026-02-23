import 'package:flutter/material.dart';

// ── 디자인 팔레트 ──
const _kAccent = Color(0xFFF7CBCA);
const _kText = Color(0xFF5D6B6B);
const _kShadow2 = Color(0xFFD5E5E5);

/// 지도에 마커가 없을 때 표시되는 안내 카드
///
/// 중앙에 배치되며 행동 유도 버튼 제공
class MapEmptyStateCard extends StatelessWidget {
  final VoidCallback onExpandRadius; // 반경 확장
  final VoidCallback onEnableNotification; // 알림 켜기
  final VoidCallback onCreateJob; // 공고 등록

  const MapEmptyStateCard({
    super.key,
    required this.onExpandRadius,
    required this.onEnableNotification,
    required this.onCreateJob,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kShadow2, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 아이콘
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _kShadow2.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_off_outlined,
                size: 28,
                color: _kText.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),

            // 제목
            const Text(
              '근처에 공고가 아직 없어요',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // 서브 텍스트
            Text(
              '반경을 넓히거나 알림을 켜두면\n바로 알려드릴게요',
              style: TextStyle(
                fontSize: 13,
                color: _kText.withOpacity(0.6),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // 버튼들
            Column(
              children: [
                // 1. 반경 확장 버튼 (Primary)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onExpandRadius,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAccent,
                      foregroundColor: _kText,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.zoom_out_map, size: 18),
                    label: const Text(
                      '반경 10km로 보기',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // 2. 알림 켜기 버튼
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onEnableNotification,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kText,
                      side: BorderSide(color: _kShadow2, width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.notifications_outlined, size: 18),
                    label: const Text(
                      '주변 구인 알림 켜기',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // 3. 공고 등록 버튼
                TextButton.icon(
                  onPressed: onCreateJob,
                  style: TextButton.styleFrom(
                    foregroundColor: _kText.withOpacity(0.7),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text(
                    '공고 등록하기',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



