import 'package:flutter/material.dart';

// ── 디자인 팔레트 ──
const _kAccent = Color(0xFFF7CBCA);
const _kText = Color(0xFF5D6B6B);
const _kShadow2 = Color(0xFFD5E5E5);

/// 도전하기 탭 빠른 액션 행
///
/// [지도/목록] 전환 + 공고 등록 + 내 지원/스크랩
class QuickActionRow extends StatelessWidget {
  final bool isMapView; // true: 지도, false: 목록
  final VoidCallback onViewToggle; // 뷰 전환 콜백
  final VoidCallback onCreateJob; // 공고 등록 콜백
  final VoidCallback onMyApplications; // 내 지원/스크랩 콜백

  const QuickActionRow({
    super.key,
    required this.isMapView,
    required this.onViewToggle,
    required this.onCreateJob,
    required this.onMyApplications,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // SegmentedButton: 지도/목록 전환
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _kShadow2.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSegmentButton(
                      label: '지도',
                      icon: Icons.map_outlined,
                      isSelected: isMapView,
                      onPressed: () {
                        if (!isMapView) onViewToggle();
                      },
                    ),
                  ),
                  Expanded(
                    child: _buildSegmentButton(
                      label: '목록',
                      icon: Icons.list_alt,
                      isSelected: !isMapView,
                      onPressed: () {
                        if (isMapView) onViewToggle();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 공고 등록 버튼
          _buildActionButton(
            icon: Icons.add_circle_outline,
            label: '공고등록',
            onPressed: onCreateJob,
            isPrimary: true,
          ),
          const SizedBox(width: 8),

          // 내 지원/스크랩 버튼
          _buildActionButton(
            icon: Icons.folder_outlined,
            label: '내활동',
            onPressed: onMyApplications,
            isPrimary: false,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? _kText : _kText.withOpacity(0.5),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? _kText : _kText.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? _kAccent : Colors.white,
        foregroundColor: _kText,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side:
              isPrimary
                  ? BorderSide.none
                  : BorderSide(color: _kShadow2, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}



