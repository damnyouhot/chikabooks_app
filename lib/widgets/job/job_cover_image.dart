import 'package:flutter/material.dart';

/// 채용공고 커버 이미지 — `assets/...` 번들 경로와 `https://...` URL 모두 지원
class JobCoverImage extends StatelessWidget {
  final String source;
  final BoxFit fit;
  final double? width;
  final double? height;

  const JobCoverImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  static bool isAssetPath(String s) =>
      s.startsWith('assets/') || s.startsWith('packages/');

  @override
  Widget build(BuildContext context) {
    if (isAssetPath(source)) {
      return Image.asset(
        source,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => const _BrokenPlaceholder(),
      );
    }
    return Image.network(
      source,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) => const _BrokenPlaceholder(),
    );
  }
}

class _BrokenPlaceholder extends StatelessWidget {
  const _BrokenPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8E8E8),
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined, size: 28),
      ),
    );
  }
}
