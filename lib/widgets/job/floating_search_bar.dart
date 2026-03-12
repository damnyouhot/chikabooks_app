import 'package:flutter/material.dart';

// ── 디자인 팔레트 ──
const _kText = Color(0xFF5D6B6B);
const _kShadow2 = Color(0xFFD5E5E5);

/// 지도 위에 떠있는 검색바
///
/// 검색창 + 필터 버튼 + 요약 정보
class FloatingSearchBar extends StatelessWidget {
  final String searchQuery;
  final Function(String) onSearchChanged;
  final VoidCallback onFilterPressed;
  final String filterSummary; // "반경 3km · 신입 가능 6 · 주4일 2"

  const FloatingSearchBar({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onFilterPressed,
    required this.filterSummary,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kShadow2, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 검색창 + 필터 버튼
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // 검색 아이콘
                  Icon(Icons.search, color: _kText.withOpacity(0.5), size: 20),
                  const SizedBox(width: 8),

                  // 검색 입력
                  Expanded(
                    child: TextField(
                      onChanged: onSearchChanged,
                      style: const TextStyle(fontSize: 14, color: _kText),
                      decoration: InputDecoration(
                        hintText: '치과명, 동네로 검색',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: _kText.withOpacity(0.4),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 필터 버튼
                  InkWell(
                    onTap: onFilterPressed,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _kShadow2.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.tune,
                        color: _kText.withOpacity(0.7),
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 구분선
            if (filterSummary.isNotEmpty) ...[
              Divider(color: _kShadow2.withOpacity(0.5), height: 1),

              // 필터 요약
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 12,
                      color: _kText.withOpacity(0.4),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        filterSummary,
                        style: TextStyle(
                          fontSize: 11,
                          color: _kText.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}



