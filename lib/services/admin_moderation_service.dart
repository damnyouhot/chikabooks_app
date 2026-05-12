import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// 모더레이션 큐 callable 래퍼.
///
/// ── 책임 ────────────────────────────────────────────────────
/// 1. Cloud Functions 콜러블 응답을 도메인 모델 (`ReportedPostSummary`,
///    `ReportedPostDetail`, `ReportEntry`) 로 변환한다.
/// 2. 콜러블 응답에서 `Map<Object?, Object?>` 중첩 캐스팅 오류를 막기 위해
///    `_deepDecode` 로 평탄화한다 (다른 어드민 서비스와 동일 패턴).
/// 3. 콜러블 실패는 `FirebaseFunctionsException` 으로 그대로 전파한다.
///    UI 가 try/catch 후 사용자에게 메시지를 보여준다.
/// ─────────────────────────────────────────────────────────────
class AdminModerationService {
  AdminModerationService._();

  static final FirebaseFunctions _fx = FirebaseFunctions.instanceFor(
    region: 'asia-northeast3',
  );

  static Future<ReportedPostListResult> listReportedPosts({
    ModerationFilter filter = ModerationFilter.all,
    int limit = 30,
  }) async {
    final call = _fx.httpsCallable('adminListReportedPosts');
    final res = await call.call<Object?>({
      'filter': filter.wire,
      'limit': limit,
    });
    final decoded = _deepDecode(res.data);
    if (decoded is! Map<String, dynamic>) {
      return const ReportedPostListResult(items: [], partialErrors: []);
    }
    final rawItems = decoded['items'];
    final items = <ReportedPostSummary>[];
    if (rawItems is List) {
      for (final r in rawItems) {
        if (r is Map<String, dynamic>) {
          items.add(ReportedPostSummary.fromMap(r));
        }
      }
    }
    final rawErrs = decoded['partialErrors'];
    final errors = <String>[];
    if (rawErrs is List) {
      for (final e in rawErrs) {
        errors.add(e.toString());
      }
    }
    return ReportedPostListResult(items: items, partialErrors: errors);
  }

  static Future<ReportedPostDetail?> getReportedItem({
    required String documentPath,
  }) async {
    final call = _fx.httpsCallable('adminGetReportedItem');
    final res = await call.call<Object?>({'documentPath': documentPath});
    final decoded = _deepDecode(res.data);
    if (decoded is! Map<String, dynamic>) return null;
    return ReportedPostDetail.fromMap(decoded);
  }

  static Future<ResolveResult> resolveReportedPost({
    required String documentPath,
    required ResolveAction action,
    String? note,
  }) async {
    final call = _fx.httpsCallable('adminResolveReportedPost');
    final res = await call.call<Object?>({
      'documentPath': documentPath,
      'action': action.wire,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    final decoded = _deepDecode(res.data);
    if (decoded is! Map<String, dynamic>) {
      return const ResolveResult(success: false, message: '응답 파싱 실패');
    }
    return ResolveResult(
      success: decoded['success'] == true,
      message: decoded['message']?.toString() ?? '',
    );
  }

  // ── decode helper ─────────────────────────────────────────
  static dynamic _deepDecode(dynamic v) {
    if (v is Map) {
      return Map<String, dynamic>.fromEntries(
        v.entries.map(
          (e) => MapEntry(e.key.toString(), _deepDecode(e.value)),
        ),
      );
    }
    if (v is List) {
      return v.map(_deepDecode).toList();
    }
    return v;
  }
}

enum ModerationFilter {
  all('all'),
  hiddenOnly('hidden_only'),
  reportedOnly('reported_only');

  final String wire;
  const ModerationFilter(this.wire);
}

enum ResolveAction {
  restore('restore'),
  permanentDelete('permanent_delete'),
  keepHidden('keep_hidden');

  final String wire;
  const ResolveAction(this.wire);
}

enum ReportedDocumentType {
  bondPost('bondPost'),
  partnerPost('partnerPost'),
  unknown('unknown');

  final String wire;
  const ReportedDocumentType(this.wire);

  static ReportedDocumentType fromWire(String? v) {
    if (v == 'bondPost') return ReportedDocumentType.bondPost;
    if (v == 'partnerPost') return ReportedDocumentType.partnerPost;
    return ReportedDocumentType.unknown;
  }

  String get displayName {
    switch (this) {
      case ReportedDocumentType.bondPost:
        return '전국 (bondPosts)';
      case ReportedDocumentType.partnerPost:
        return '그룹 (partnerGroups)';
      case ReportedDocumentType.unknown:
        return '미상';
    }
  }
}

@immutable
class ReportedPostSummary {
  final String documentPath;
  final ReportedDocumentType documentType;
  final String authorUid;
  final String preview;
  final int reportCount;
  final bool isHidden;
  final String? hiddenReason;
  final DateTime? hiddenAt;
  final DateTime? lastReportedAt;
  final String? lastReportReason;
  final DateTime? createdAt;

  const ReportedPostSummary({
    required this.documentPath,
    required this.documentType,
    required this.authorUid,
    required this.preview,
    required this.reportCount,
    required this.isHidden,
    required this.hiddenReason,
    required this.hiddenAt,
    required this.lastReportedAt,
    required this.lastReportReason,
    required this.createdAt,
  });

  factory ReportedPostSummary.fromMap(Map<String, dynamic> m) {
    return ReportedPostSummary(
      documentPath: (m['documentPath'] ?? '').toString(),
      documentType: ReportedDocumentType.fromWire(
        m['documentType']?.toString(),
      ),
      authorUid: (m['authorUid'] ?? '').toString(),
      preview: (m['preview'] ?? '').toString(),
      reportCount: (m['reportCount'] as num?)?.toInt() ?? 0,
      isHidden: m['isHidden'] == true,
      hiddenReason: m['hiddenReason']?.toString(),
      hiddenAt: _ms(m['hiddenAtMs']),
      lastReportedAt: _ms(m['lastReportedAtMs']),
      lastReportReason: m['lastReportReason']?.toString(),
      createdAt: _ms(m['createdAtMs']),
    );
  }

  static DateTime? _ms(dynamic v) {
    if (v is num) {
      return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    }
    return null;
  }
}

@immutable
class ReportEntry {
  final String reporterUid;
  final String reason;
  final String reasonDisplay;
  final String? additionalInfo;
  final DateTime? createdAt;

  const ReportEntry({
    required this.reporterUid,
    required this.reason,
    required this.reasonDisplay,
    required this.additionalInfo,
    required this.createdAt,
  });

  factory ReportEntry.fromMap(Map<String, dynamic> m) {
    final ms = m['createdAtMs'];
    return ReportEntry(
      reporterUid: (m['reporterUid'] ?? '').toString(),
      reason: (m['reason'] ?? '').toString(),
      reasonDisplay: (m['reasonDisplay'] ?? '').toString(),
      additionalInfo: m['additionalInfo']?.toString(),
      createdAt:
          ms is num ? DateTime.fromMillisecondsSinceEpoch(ms.toInt()) : null,
    );
  }
}

@immutable
class ReportedPostDetail {
  final ReportedPostSummary summary;
  final String body;
  final List<String> imageUrls;
  final List<ReportEntry> reports;
  final Map<String, dynamic> metadata;

  const ReportedPostDetail({
    required this.summary,
    required this.body,
    required this.imageUrls,
    required this.reports,
    required this.metadata,
  });

  factory ReportedPostDetail.fromMap(Map<String, dynamic> m) {
    final summaryMap = m['summary'];
    final reportsRaw = m['reports'];
    final imagesRaw = m['imageUrls'];
    final metaRaw = m['metadata'];
    return ReportedPostDetail(
      summary: summaryMap is Map<String, dynamic>
          ? ReportedPostSummary.fromMap(summaryMap)
          : const ReportedPostSummary(
              documentPath: '',
              documentType: ReportedDocumentType.unknown,
              authorUid: '',
              preview: '',
              reportCount: 0,
              isHidden: false,
              hiddenReason: null,
              hiddenAt: null,
              lastReportedAt: null,
              lastReportReason: null,
              createdAt: null,
            ),
      body: (m['body'] ?? '').toString(),
      imageUrls: imagesRaw is List
          ? imagesRaw.map((e) => e.toString()).toList(growable: false)
          : const [],
      reports: reportsRaw is List
          ? [
              for (final r in reportsRaw)
                if (r is Map<String, dynamic>) ReportEntry.fromMap(r),
            ]
          : const [],
      metadata: metaRaw is Map<String, dynamic>
          ? Map<String, dynamic>.from(metaRaw)
          : const {},
    );
  }
}

@immutable
class ReportedPostListResult {
  final List<ReportedPostSummary> items;
  final List<String> partialErrors;
  const ReportedPostListResult({
    required this.items,
    required this.partialErrors,
  });
}

@immutable
class ResolveResult {
  final bool success;
  final String message;
  const ResolveResult({required this.success, required this.message});
}
