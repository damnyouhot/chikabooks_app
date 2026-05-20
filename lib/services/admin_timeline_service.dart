import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// 운영 대시보드 「타임라인」 탭용 통합 피드 서비스.
///
/// ── 데이터 소스 ─────────────────────────────────────────────
///   - notes : `users/{uid}/notes/{noteId}` — 문서마다 `createdAt`
///   - goals : `users/{uid}/goals/current` 한 문서의 `items[]` 배열
///             (목표마다 별도 Firestore 문서가 아님 → 배열을 펼쳐 타임라인에 넣음)
///
/// notes 쿼리는 [firestore.indexes.json] 의 collectionGroup 색인이 필요합니다.
/// goals 는 collectionGroup 전체 스냅샷 후 클라이언트에서 기간·정렬 처리합니다.
///
/// `users.isAdmin == true` 계정의 기록·목표는 타임라인에서 제외합니다.
class AdminTimelineService {
  AdminTimelineService._();

  static final _db = FirebaseFirestore.instance;

  /// `isAdmin == true` 유저 UID 집합 (실시간).
  static Stream<Set<String>> _adminUidStream() {
    return _db
        .collection('users')
        .where('isAdmin', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  /// 통합 피드 스트림 (실시간).
  ///
  /// notes / goals / 관리자 목록 중 하나가 바뀌면 목록이 다시 emit 됩니다.
  static Stream<List<TimelineItem>> watchFeed({
    required DateTime since,
    int limit = 100,
  }) {
    final adminStream = _adminUidStream();
    final notesStream = _db
        .collectionGroup('notes')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();

    // goals/current 문서만 구독 — items[] 안 각 목표의 createdAt 으로 필터
    final goalsStream = _db.collectionGroup('goals').snapshots();

    return _combineLatest3(
      adminStream,
      notesStream,
      goalsStream,
      (adminUids, notesSnap, goalsSnap) {
        final items = <TimelineItem>[];
        for (final doc in notesSnap.docs) {
          final item = TimelineItem.fromNoteDoc(doc);
          if (item != null) items.add(item);
        }
        items.addAll(TimelineItem.fromGoalsSnapshot(goalsSnap, since: since));
        items.removeWhere((i) => adminUids.contains(i.uid));
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (items.length > limit) {
          return items.sublist(0, limit);
        }
        return items;
      },
    );
  }
}

/// 세 스트림이 모두 최소 한 번 이상 값을 내놓은 시점부터 결합해 emit.
Stream<R> _combineLatest3<A, B, C, R>(
  Stream<A> a,
  Stream<B> b,
  Stream<C> c,
  R Function(A, B, C) combiner,
) {
  late StreamController<R> controller;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;
  StreamSubscription<C>? subC;

  A? latestA;
  B? latestB;
  C? latestC;
  bool hasA = false;
  bool hasB = false;
  bool hasC = false;

  void emit() {
    if (hasA && hasB && hasC) {
      controller.add(combiner(latestA as A, latestB as B, latestC as C));
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
      subC = c.listen(
        (v) {
          latestC = v;
          hasC = true;
          emit();
        },
        onError: controller.addError,
      );
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
      await subC?.cancel();
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

  static TimelineItem? fromNoteDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final ts = data['createdAt'];
    if (ts is! Timestamp) return null;
    final parentUid = doc.reference.parent.parent?.id;
    if (parentUid == null) return null;
    return TimelineItem(
      id: doc.id,
      uid: parentUid,
      kind: TimelineItemKind.note,
      createdAt: ts.toDate(),
      data: data,
    );
  }

  /// `users/{uid}/goals/current` 의 `items` 배열을 목표 단위 타임라인 항목으로 펼침.
  static List<TimelineItem> fromGoalsSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap, {
    required DateTime since,
  }) {
    final sinceTs = Timestamp.fromDate(since);
    final out = <TimelineItem>[];

    for (final doc in snap.docs) {
      if (doc.id != 'current') continue;

      final uid = doc.reference.parent.parent?.id;
      if (uid == null) continue;

      final rawItems = doc.data()['items'];
      if (rawItems is! List) continue;

      for (final raw in rawItems) {
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw);
        final ts = m['createdAt'];
        if (ts is! Timestamp) continue;
        if (ts.compareTo(sinceTs) <= 0) continue;

        final goalId = m['id'] as String?;
        if (goalId == null || goalId.isEmpty) continue;

        out.add(
          TimelineItem(
            id: '${doc.id}_$goalId',
            uid: uid,
            kind: TimelineItemKind.goal,
            createdAt: ts.toDate(),
            data: m,
          ),
        );
      }
    }
    return out;
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
