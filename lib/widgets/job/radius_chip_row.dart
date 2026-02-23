import 'package:flutter/material.dart';

// ── 디자인 팔레트 ──
const _kAccent = Color(0xFFF7CBCA);
const _kText = Color(0xFF5D6B6B);
const _kShadow2 = Color(0xFFD5E5E5);

/// 반경 선택 칩 행 (지도 전용)
///
/// [1km] [3km] [5km] [10km]
class RadiusChipRow extends StatelessWidget {
  final double selectedRadius;
  final Function(double) onRadiusChanged;

  const RadiusChipRow({
    super.key,
    required this.selectedRadius,
    required this.onRadiusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final radiusOptions = [1.0, 3.0, 5.0, 10.0];

    return Positioned(
      top: 140, // FloatingSearchBar 아래
      left: 12,
      right: 12,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // "반경:" 라벨
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kShadow2, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '반경',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kText.withOpacity(0.7),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // 반경 칩들
            ...radiusOptions.map((radius) {
              final isSelected = selectedRadius == radius;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onRadiusChanged(radius),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? _kAccent.withOpacity(0.9)
                              : Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? _kAccent : _kShadow2,
                        width: isSelected ? 1.5 : 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '${radius.toStringAsFixed(0)}km',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? _kText : _kText.withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}



