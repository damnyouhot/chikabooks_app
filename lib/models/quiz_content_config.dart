import 'package:cloud_firestore/cloud_firestore.dart';

/// `config/quiz_content` — 임상 퀴즈 패크 전환 설정 (국시·공감투표와 무관)
class QuizContentConfig {
  final String currentClinicalPackId;
  final bool includeClinicalWithoutPack;
  final DateTime? updatedAt;

  const QuizContentConfig({
    required this.currentClinicalPackId,
    required this.includeClinicalWithoutPack,
    this.updatedAt,
  });

  factory QuizContentConfig.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return QuizContentConfig(
      currentClinicalPackId: (d['currentClinicalPackId'] as String? ?? '').trim(),
      includeClinicalWithoutPack: d['includeClinicalWithoutPack'] as bool? ?? true,
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// 문서 없을 때: 기존 동작(전체 임상 후보)과 동일
  factory QuizContentConfig.defaultLegacy() => const QuizContentConfig(
        currentClinicalPackId: '',
        includeClinicalWithoutPack: true,
      );
}

/// `quiz_packs/{packId}` 메타 (앱·관리용 조회)
class QuizPackMeta {
  final String id;
  final String kind;
  final String title;
  final int version;
  final bool isActive;

  const QuizPackMeta({
    required this.id,
    required this.kind,
    required this.title,
    required this.version,
    required this.isActive,
  });

  factory QuizPackMeta.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return QuizPackMeta(
      id: doc.id,
      kind: d['kind'] as String? ?? '',
      title: d['title'] as String? ?? '',
      version: (d['version'] as num?)?.toInt() ?? 0,
      isActive: d['isActive'] as bool? ?? true,
    );
  }
}
