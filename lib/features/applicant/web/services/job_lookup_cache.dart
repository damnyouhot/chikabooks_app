import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../models/job.dart';

/// 여러 [Application] 카드 등에서 같은 [Job] 문서를 반복해서 fetch 하지 않도록
/// id → Future<Job?> 결과를 메모리에 캐시한다.
///
/// - 동일 jobId 에 대해 첫 호출만 실제 fetch, 이후 호출은 캐시된 Future 를 반환.
/// - 30개씩 묶어 `whereIn` 쿼리로 한 번에 가져오는 [preload] 도 제공.
/// - 인스턴스를 페이지 [State] 에 한 개만 두고, 페이지 dispose 시 [clear] 호출.
class JobLookupCache {
  JobLookupCache({this.includeOffline = true});

  /// `mock_*` 같은 ID 도 [Job.fromJson] fallback 으로 만들어 줄지 여부.
  /// 대시보드/지원 내역에서는 true 로 두면 빈 칸 대신 placeholder 가 보여 안정적.
  final bool includeOffline;

  final Map<String, Future<Job?>> _futures = {};
  final Map<String, Job?> _resolved = {};

  /// 단건 조회. 같은 id 호출은 동일 Future 를 공유한다.
  Future<Job?> get(String jobId) {
    if (jobId.isEmpty) return Future.value(null);
    final cached = _futures[jobId];
    if (cached != null) return cached;
    final future = _fetchOne(jobId);
    _futures[jobId] = future;
    return future;
  }

  /// 캐시에 이미 들어 있는 결과(있으면).
  Job? peek(String jobId) => _resolved[jobId];

  /// 여러 id 를 30개씩 묶어 한 번에 가져온다 (Firestore `whereIn` 한도).
  /// 미리 호출해 두면 이후 [get] 은 즉시 캐시 hit.
  Future<void> preload(Iterable<String> ids) async {
    final missing = ids
        .where((id) => id.isNotEmpty && !_futures.containsKey(id))
        .toSet();
    if (missing.isEmpty) return;

    // 미리 placeholder Future 를 채워서 동시 호출 시 중복 fetch 방지.
    final completers = <String, Completer<Job?>>{};
    for (final id in missing) {
      final c = Completer<Job?>();
      completers[id] = c;
      _futures[id] = c.future;
    }

    final list = missing.toList();
    for (var i = 0; i < list.length; i += 30) {
      final batch = list.sublist(i, (i + 30).clamp(0, list.length));
      try {
        final snap = await FirebaseFirestore.instance
            .collection('jobs')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        final got = <String, Job>{};
        for (final doc in snap.docs) {
          try {
            got[doc.id] = Job.fromDoc(doc);
          } catch (e) {
            debugPrint('⚠️ JobLookupCache.preload parse(${doc.id}): $e');
          }
        }
        for (final id in batch) {
          final job = got[id] ??
              (includeOffline ? _fallback(id) : null);
          _resolved[id] = job;
          completers[id]?.complete(job);
        }
      } catch (e) {
        debugPrint('⚠️ JobLookupCache.preload batch error: $e');
        for (final id in batch) {
          final job = includeOffline ? _fallback(id) : null;
          _resolved[id] = job;
          completers[id]?.complete(job);
        }
      }
    }
  }

  Future<Job?> _fetchOne(String jobId) async {
    if (jobId.startsWith('mock_')) {
      final job = includeOffline ? _fallback(jobId) : null;
      _resolved[jobId] = job;
      return job;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('jobs')
          .doc(jobId)
          .get();
      if (doc.exists && doc.data() != null) {
        final job = Job.fromDoc(doc);
        _resolved[jobId] = job;
        return job;
      }
    } catch (e) {
      debugPrint('⚠️ JobLookupCache.get($jobId): $e');
    }
    final job = includeOffline ? _fallback(jobId) : null;
    _resolved[jobId] = job;
    return job;
  }

  Job _fallback(String jobId) {
    return Job.fromJson(
      const {
        'title': '',
        'clinicName': '',
        'career': '미정',
        'salaryRange': [0, 0],
        'details': '',
        'benefits': <String>[],
        'images': <String>[],
      },
      docId: jobId,
    );
  }

  void clear() {
    _futures.clear();
    _resolved.clear();
  }
}
