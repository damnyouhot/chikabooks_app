import 'package:flutter/material.dart';

/// 전체 화면 이미지 뷰어 (좌우 스와이프 + 확대/축소)
///
/// 여러 곳(나의 기록 타임라인, 관리자 운영 타임라인)에서 공통으로 사용합니다.
class FullImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<FullImageViewer> createState() => _FullImageViewerState();
}

class _FullImageViewerState extends State<FullImageViewer> {
  late final PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_current + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(fontSize: 16),
        ),
        elevation: 0,
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.imageUrls.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 3.0,
            child: Center(
              child: Image.network(
                widget.imageUrls[i],
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white54),
                  );
                },
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 48,
                    color: Colors.white38,
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
