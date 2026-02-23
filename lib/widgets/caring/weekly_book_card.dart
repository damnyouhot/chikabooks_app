import 'package:flutter/material.dart';

/// 📖 이주의 책 카드
class WeeklyBookCard extends StatelessWidget {
  final VoidCallback? onPreview;

  const WeeklyBookCard({super.key, this.onPreview});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(10),
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
            // 책 정보 (좌측 썸네일 + 우측 텍스트)
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
                  ),
                  child: Icon(Icons.book, size: 18, color: Colors.grey[600]),
                ),
                const SizedBox(width: 8),
                // 우측 텍스트
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 메인 제목
                      Text(
                        '치주 기본 술식 완전정리',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      // 서브타이틀
                      Text(
                        '― 임상에서 바로 쓰는 스케일링 테크닉',
                        style: TextStyle(fontSize: 9, color: Colors.black54),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
