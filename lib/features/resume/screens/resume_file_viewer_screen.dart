import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/resume_file.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// 업로드 이력서 파일 뷰어
///
/// - PDF: 웹뷰(iframe) 또는 외부 브라우저
/// - JPG/PNG: 앱 내 이미지 뷰어
class ResumeFileViewerScreen extends StatelessWidget {
  final ResumeFile file;
  const ResumeFileViewerScreen({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              file.displayName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${file.fileType.label}  ·  ${file.fileSizeLabel}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textDisabled,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new,
                color: AppColors.textSecondary, size: 20),
            tooltip: '브라우저에서 열기',
            onPressed: () => _openInBrowser(context),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (file.fileType) {
      case ResumeFileType.jpg:
      case ResumeFileType.jpeg:
      case ResumeFileType.png:
        return _ImageViewer(url: file.downloadUrl);
      case ResumeFileType.pdf:
        return _PdfViewer(url: file.downloadUrl);
      default:
        return _UnsupportedViewer(onOpenBrowser: () => _openInBrowser(context));
    }
  }

  Future<void> _openInBrowser(BuildContext context) async {
    final uri = Uri.parse(file.downloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파일을 열 수 없어요.')),
      );
    }
  }
}

// ── 이미지 뷰어 ──────────────────────────────────────────
class _ImageViewer extends StatelessWidget {
  final String url;
  const _ImageViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 5.0,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (_, __, ___) => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined,
                    size: 48, color: AppColors.textDisabled),
                SizedBox(height: 8),
                Text('이미지를 불러올 수 없어요.',
                    style: TextStyle(color: AppColors.textDisabled)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── PDF 뷰어 ─────────────────────────────────────────────
class _PdfViewer extends StatelessWidget {
  final String url;
  const _PdfViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // 웹: iframe embed (HtmlElementView) 대신 안내 + 브라우저 열기 유도
      return _PdfWebPrompt(url: url);
    }
    // 앱: url_launcher로 외부 PDF 뷰어 열기
    return _PdfAppPrompt(url: url);
  }
}

class _PdfWebPrompt extends StatelessWidget {
  final String url;
  const _PdfWebPrompt({required this.url});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf,
                size: 64, color: Color(0xFFE53935)),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'PDF 미리보기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '아래 버튼을 눌러 새 탭에서 PDF를 확인하세요.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('새 탭에서 열기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
              onPressed: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfAppPrompt extends StatelessWidget {
  final String url;
  const _PdfAppPrompt({required this.url});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf,
                size: 64, color: Color(0xFFE53935)),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'PDF 파일',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '외부 PDF 앱으로 열거나 브라우저에서 확인하세요.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('PDF 앱으로 열기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
              onPressed: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PDF를 열 수 없어요.')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── 지원 불가 포맷 ──────────────────────────────────────
class _UnsupportedViewer extends StatelessWidget {
  final VoidCallback onOpenBrowser;
  const _UnsupportedViewer({required this.onOpenBrowser});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file_outlined,
                size: 64, color: AppColors.textDisabled),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              '미리보기를 지원하지 않는 파일이에요.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('브라우저에서 열기'),
              onPressed: onOpenBrowser,
            ),
          ],
        ),
      ),
    );
  }
}
