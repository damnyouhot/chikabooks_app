import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_badge.dart';
import '../models/hira_update.dart';

/// 심평원 문서를 앱 내 WebView로 표시.
///
/// [searchContext]가 있으면 제도 변경 **검색 결과** 탭과 동일한 톤으로
/// (`HiraUpdateDetailSheet`와 맞춤): `appBg`, 「상세 정보」헤더, 뱃지·메타·「원문」구역.
/// 없으면 RSS 상세의 「원문 보기」와 같이 제목 + 「공식 원문」만 올리고 WebView.
class HiraWebViewSheet extends StatefulWidget {
  final String url;
  final String title;
  final HiraSearchResult? searchContext;

  const HiraWebViewSheet({
    super.key,
    required this.url,
    required this.title,
    this.searchContext,
  });

  static Future<void> show(
    BuildContext context, {
    required String url,
    required String title,
    HiraSearchResult? searchContext,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (_) => HiraWebViewSheet(
        url: url,
        title: title,
        searchContext: searchContext,
      ),
    );
  }

  @override
  State<HiraWebViewSheet> createState() => _HiraWebViewSheetState();
}

class _HiraWebViewSheetState extends State<HiraWebViewSheet> {
  late final WebViewController _ctrl;
  bool _isLoading = true;
  int _loadingProgress = 0;
  /// 페이지 분석 후 true면 「첨부파일 있음」 표시
  bool _hasAttachment = false;

  static const _hideCloseButtonsJs = r'''
(function() {
  var tags = ['a', 'button', 'input'];
  tags.forEach(function(tag) {
    var nodes = document.querySelectorAll(tag);
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      var tx = ((el.textContent || el.value || '') + '').replace(/\s+/g, ' ').trim();
      if (tx === '닫기' || tx === '닫기 X' || tx === 'Close' || /^닫기\s*[X×]?$/i.test(tx)) {
        el.style.setProperty('display', 'none', 'important');
      }
    }
  });
})()
''';

  static const _attachmentDetectJs = r'''
(function() {
  var links = document.querySelectorAll('a[href]');
  for (var i = 0; i < links.length; i++) {
    var h = (links[i].getAttribute('href') || '').toLowerCase();
    if (h.indexOf('.pdf') >= 0 || h.indexOf('.hwp') >= 0 || h.indexOf('.doc') >= 0 ||
        h.indexOf('.xlsx') >= 0 || h.indexOf('.xls') >= 0 || h.indexOf('download') >= 0 ||
        h.indexOf('filedownload') >= 0 || h.indexOf('atchfile') >= 0 || h.indexOf('fileid=') >= 0) {
      return true;
    }
  }
  if (document.querySelectorAll('.col-file a, td.col-file a, [class*="atch"] a, [class*="file"] a').length > 0) {
    return true;
  }
  var txt = (document.body && document.body.innerText) || '';
  if (txt.indexOf('첨부파일') >= 0 || txt.indexOf('첨부 파일') >= 0) return true;
  return false;
})()
''';

  static const _themeCss = '''
html, body {
  background-color: #F0EDE6 !important;
  color: #000000 !important;
  font-family: system-ui, -apple-system, "Apple SD Gothic Neo", "Malgun Gothic", sans-serif !important;
  font-size: 15px !important;
  line-height: 1.55 !important;
}
body { padding: 12px !important; margin: 0 !important; }
a { color: #0A0A3A !important; }
table { font-size: 14px !important; }
input[type="button"][value*="인쇄"],
input[type="button"][value*="print" i],
button[onclick*="print" i],
button[onclick*="Print"],
a[onclick*="print" i],
a[onclick*="Print"],
.btn_print, .btnType01, #btnPrint {
  display: none !important;
}
a[href="javascript:self.close();"], a[href*="self.close"] {
  display: none !important;
}
''';

  Future<void> _afterPageLoaded() async {
    const unlock = '''
(function() {
  try {
    document.documentElement.style.overflow = 'auto';
    document.documentElement.style.height = 'auto';
    document.body.style.overflow = 'auto';
    document.body.style.height = 'auto';
    document.body.style.minHeight = '100%';
  } catch (e) {}
})();
''';
    final inject =
        '(()=>{try{var e=document.getElementById("chikabooks-hira-theme");'
        'if(e)e.remove();var s=document.createElement("style");'
        's.id="chikabooks-hira-theme";s.textContent=${jsonEncode(_themeCss)};'
        'document.head.appendChild(s);}catch(_){}})();';
    try {
      await _ctrl.runJavaScript(inject);
      await _ctrl.runJavaScript(unlock);
      await _ctrl.runJavaScript(_hideCloseButtonsJs);
    } catch (_) {}
  }

  Future<void> _detectAttachment() async {
    try {
      final v = await _ctrl.runJavaScriptReturningResult(_attachmentDetectJs);
      final has = v == true ||
          v == 1 ||
          (v is String && v.toLowerCase() == 'true');
      if (mounted) setState(() => _hasAttachment = has);
    } catch (_) {
      if (mounted) setState(() => _hasAttachment = false);
    }
  }

  Future<void> _openOriginalInBrowser() async {
    final uri = Uri.parse(widget.url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _loadingProgress = p),
          onPageStarted: (_) => setState(() {
            _isLoading = true;
            _hasAttachment = false;
          }),
          onPageFinished: (_) async {
            await _afterPageLoaded();
            await _detectAttachment();
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (_) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final r = widget.searchContext;

    return Container(
      height: screenH * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.appBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          if (_isLoading)
            LinearProgressIndicator(
              value: _loadingProgress / 100,
              minHeight: 2,
              backgroundColor: AppColors.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 32,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.md,
                      AppSpacing.xl,
                      AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (r != null) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppStatusBadge(
                                badgeLevel: 'NOTICE',
                                badgeText: r.category.isNotEmpty
                                    ? r.category
                                    : '심평원',
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  widget.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _formatPostLine(r.date),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary.withValues(alpha: 0.45),
                            ),
                          ),
                          if (r.reference.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '관련근거 ${r.reference}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '조회수 ${r.views}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textDisabled,
                            ),
                          ),
                        ] else ...[
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.xs,
                                children: [
                                  Text(
                                    r != null
                                        ? '보험인정기준 원문'
                                        : '공식 원문',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                  if (_hasAttachment)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceMuted,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.xs,
                                        ),
                                      ),
                                      child: const Text(
                                        '첨부파일 있음',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: _openOriginalInBrowser,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                '원문 보러가기',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 68,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      0,
                      AppSpacing.xl,
                      AppSpacing.lg,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: ColoredBox(
                        color: AppColors.surfaceMuted,
                        child: WebViewWidget(
                          controller: _ctrl,
                          gestureRecognizers:
                              <Factory<OneSequenceGestureRecognizer>>{
                            Factory<VerticalDragGestureRecognizer>(
                              () => VerticalDragGestureRecognizer(),
                            ),
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPostLine(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(t)) {
      final p = t.split('-');
      return '${p[0]}년 ${int.parse(p[1])}월 ${int.parse(p[2])}일 게시';
    }
    return '게시일 $t';
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            children: [
              const Text(
                '상세 정보',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(
                  Icons.close,
                  size: 22,
                  color: AppColors.textPrimary.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
      ],
    );
  }
}
