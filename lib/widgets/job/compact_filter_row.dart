import 'package:flutter/material.dart';

// ── 디자인 팔레트 ──
const _kAccent = Color(0xFFF7CBCA);
const _kText = Color(0xFF5D6B6B);
const _kShadow2 = Color(0xFFD5E5E5);

/// 목록용 컴팩트 필터 행 (1줄)
///
/// 검색창 + 필터 버튼 + 정렬 드롭다운
class CompactFilterRow extends StatelessWidget {
  final String searchQuery;
  final Function(String) onSearchChanged;
  final VoidCallback onFilterPressed;
  final String sortBy; // 거리순/최신순/급여순
  final Function(String) onSortChanged;
  final int activeFilterCount; // 활성 필터 수 (배지 표시용)

  const CompactFilterRow({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onFilterPressed,
    required this.sortBy,
    required this.onSortChanged,
    this.activeFilterCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: _kShadow2.withOpacity(0.5), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // 검색창 (짧게)
          Expanded(
            flex: 3,
            child: TextField(
              onChanged: onSearchChanged,
              style: const TextStyle(fontSize: 14, color: _kText),
              decoration: InputDecoration(
                hintText: '검색',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: _kText.withOpacity(0.4),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: _kText.withOpacity(0.5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _kShadow2, width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _kShadow2, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _kAccent, width: 1.0),
                ),
                filled: true,
                fillColor: _kShadow2.withOpacity(0.2),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 필터 버튼 (배지 포함)
          Stack(
            children: [
              InkWell(
                onTap: onFilterPressed,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        activeFilterCount > 0
                            ? _kAccent.withOpacity(0.2)
                            : _kShadow2.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: activeFilterCount > 0 ? _kAccent : _kShadow2,
                      width: 0.5,
                    ),
                  ),
                  child: Icon(
                    Icons.tune,
                    size: 18,
                    color:
                        activeFilterCount > 0
                            ? _kAccent
                            : _kText.withOpacity(0.7),
                  ),
                ),
              ),
              // 활성 필터 수 배지
              if (activeFilterCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _kAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$activeFilterCount',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: _kText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),

          // 정렬 드롭다운
          DropdownButton<String>(
            value: sortBy,
            onChanged: (value) {
              if (value != null) onSortChanged(value);
            },
            items:
                ['거리순', '최신순', '급여순'].map((sort) {
                  return DropdownMenuItem(
                    value: sort,
                    child: Text(
                      sort,
                      style: const TextStyle(fontSize: 13, color: _kText),
                    ),
                  );
                }).toList(),
            underline: Container(),
            icon: Icon(Icons.arrow_drop_down, color: _kText.withOpacity(0.7)),
            style: const TextStyle(fontSize: 13, color: _kText),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }
}



