import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// 운영 대시보드 「타임라인」 탭용 통합 피드 서비스.
///
/// 전체 유저가 작성한 「기록(notes)」과 「목표(goals — 루틴/프로젝트 포함)」를
/// 시간순으로 합쳐 트위터 타임라인처럼 노출합니다.
///
/// ── 데이터 소스 ─────────────────────────────────────────────
///   - collectionGroup('notes')   : `users/{uid}/notes/{noteId}`
///   - collectionGroup('goals')   : `users/{uid}/goals/{goalId}`
///
/// 단일 필드 색인(`createdAt desc`) 이 필요하며, Firestore 콘솔에서
/// 자동 제안되는 collectionGroup 인덱스를 한 번 생성해두어야 합니다.
class AdminTimelineService {
  AdminTimelineService._();

  static final _db = FirebaseFirestore.instance;

  /// 통합 피드 스트림.
  ///
  /// [since] 이후 생성된 항목만 조회합니다.
  /// [limit] 은 각 컬렉션별 상한 — 합쳐서 최대 `limit * 2` 개가 들어온 뒤
  /// 정렬 후 다시 [limit] 개로 자릅니다.
  static Stream<List<TimelineItem>> watchFeed({
    required DateTime since,
    int limit = 100,
  }) {
    final notesStream = _db
        .collectionGroup('notes')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();

    final goalsStream = _db
        .collectionGroup('goals')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();

    return _combineLatest2(notesStream, goalsStream, (notesSnap, goalsSnap) {
      final items = <TimelineItem>[];
      for (final doc in notesSnap.docs) {
        final item = TimelineItem._fromDoc(doc, TimelineItemKind.note);
        if (item != null) items.add(item);
      }
      for (final doc in goalsSnap.docs) {
        final item = TimelineItem._fromDoc(doc, TimelineItemKind.goal);
        if (item != null) items.add(item);
      }
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (items.length > limit) {
        return items.sublist(0, limit);
      }
      return items;
    });
  }
}

/// 두 스트림이 모두 최소 한 번 이상 값을 내놓은 시점부터 결합해 emit.
/// rxdart 의존 없이 구현.
Stream<R> _combineLatest2<A, B, R>(
  Stream<A> a,
  Stream<B> b,
  R Function(A, B) combiner,
) {
  late StreamController<R> controller;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;

  A? latestA;
  B? latestB;
  bool hasA = false;
  bool hasB = false;

  void emit() {
    if (hasA && hasB) {
      controller.add(combiner(latestA as A, latestB as B));
    }
  }

  controller = StreamController<R>(
    onListen: () {
      subA = a.listen(
        (v) {
          latestA = v;
          hasA = true;
          emit();
        },
        onError: controller.addError,
      );
      subB = b.listen(
        (v) {
          latestB = v;
          hasB = true;
          emit();
        },
        onError: controller.addError,
      );
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
    },
  );

  return controller.stream;
}

enum TimelineItemKind { note, goal }

/// 타임라인 한 항목 — 노트 또는 목표(루틴/프로젝트).
class TimelineItem {
  final String id;
  final String uid;
  final TimelineItemKind kind;
  final DateTime createdAt;
  final Map<String, dynamic> data;

  const TimelineItem({
    required this.id,
    required this.uid,
    required this.kind,
    required this.createdAt,
    required this.data,
  });

  static TimelineItem? _fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    TimelineItemKind kind,
  ) {
    final data = doc.data();
    final ts = data['createdAt'];
    if (ts is! Timestamp) return null;
    final parentUid = doc.reference.parent.parent?.id;
    if (parentUid == null) return null;
    return TimelineItem(
      id: doc.id,
      uid: parentUid,
      kind: kind,
      createdAt: ts.toDate(),
      data: data,
    );
  }

  // ── 노트(기록) 편의 접근자 ─────────────────────────────────
  String get noteText => (data['text'] as String?) ?? '';
  String? get noteMood => data['mood'] as String?;
  List<String> get noteImageUrls {
    final raw = data['imageUrls'];
    if (raw is List) return raw.cast<String>();
    return const [];
  }

  // ── 목표 편의 접근자 ───────────────────────────────────────
  String get goalTitle => (data['title'] as String?) ?? '';
  String get goalType => (data['type'] as String?) ?? 'project';
  bool get goalIsDone => (data['isDone'] as bool?) ?? false;
  List<Map<String, dynamic>> get goalCheckpoints {
    final raw = data['checkpoints'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }
}
