import 'package:flutter/material.dart';

/// 📖 이주의 책 카드
class WeeklyBookCard extends StatelessWidget {
  final Map<String, dynamic>? data;
  final VoidCallback? onPreview;

  const WeeklyBookCard({super.key, this.data, this.onPreview});

  @override
  Widget build(BuildContext context) {
    final bookTitle = data?['title'] as String? ?? '';
    final bookSubtitle = data?['subtitle'] as String? ?? '';
    final thumbnailUrl = data?['thumbnailUrl'] as String?;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 타이틀
            Row(
              children: [
                Text('📖', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 3),
                Text(
                  '이주의 책',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 로딩 상태
            if (data == null)
              Text('로딩 중...', style: TextStyle(fontSize: 11))
            // 데이터 없음
            else if (bookTitle.isEmpty)
              Text('이주의 책이 선정되지 않았어요', style: TextStyle(fontSize: 11))
            // 책 정보
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 작은 표지 썸네일
                  Container(
                    width: 34,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                      image:
                          thumbnailUrl != null
                              ? DecorationImage(
                                image: NetworkImage(thumbnailUrl),
                                fit: BoxFit.cover,
                              )
                              : null,
                    ),
                    child:
                        thumbnailUrl == null
                            ? Icon(
                              Icons.book,
                              size: 18,
                              color: Colors.grey[600],
                            )
                            : null,
                  ),
                  const SizedBox(width: 8),
                  // 우측 텍스트
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 메인 제목
                        Text(
                          bookTitle,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (bookSubtitle.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          // 서브타이틀
                          Text(
                            '― $bookSubtitle',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        // CTA 버튼
                        OutlinedButton(
                          onPressed: onPreview,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text('1분 미리보기', style: TextStyle(fontSize: 9)),
                        ),
                      ],
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
