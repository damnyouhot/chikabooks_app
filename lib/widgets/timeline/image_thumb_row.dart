import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'full_image_viewer.dart';

/// 가로 스크롤 이미지 썸네일 행. 탭하면 [FullImageViewer] 로 진입.
class ImageThumbRow extends StatelessWidget {
  final List<String> imageUrls;
  final double size;

  const ImageThumbRow({
    super.key,
    required this.imageUrls,
    this.size = 80,
  });

  void _openViewer(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullImageViewer(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: imageUrls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          return GestureDetector(
            onTap: () => _openViewer(context, i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imageUrls[i],
                width: size,
                height: size,
                fit: BoxFit.cover,
                cacheWidth: (size * 2.5).round(),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    width: size,
                    height: size,
                    color: AppColors.surfaceMuted,
                    child: const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  width: size,
                  height: size,
                  color: AppColors.surfaceMuted,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    size: 24,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
