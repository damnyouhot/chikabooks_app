import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// `careerNetwork` OCR·수동 입력 혼재 중복(같은 근무 기간·유사 병원명) 정리
class CareerNetworkDedupeHelper {
  CareerNetworkDedupeHelper._();

  /// 이력서 동기화 시 병원명이 같은 곳으로 보는지 (앤/연 등 OCR 차이)
  static bool areProbablySameClinic(String a, String b) =>
      _nameLikelyDuplicate(a, b);

  /// 동일 사용자 `careerNetwork` 전체를 대상으로, 기간·이름이 같다고 보면 최신 1건만 유지.
  ///
  /// 예전에는 `syncedFromResume == true`만 대상이었으나, 수동 입력 줄이 남아 OCR 중복이
  /// 계속 보이는 경우가 있어 전체 문서로 확장함.
  static Future<void> mergeSimilarNetworkEntries(
    CollectionReference<Map<String, dynamic>> networkRef,
  ) async {
    final snap = await networkRef.get();
    final items = <_NetDoc>[];
    for (final doc in snap.docs) {
      final d = doc.data();
      final ts = d['startDate'] as Timestamp?;
      if (ts == null) continue;
      final start = ts.toDate();
      final end = (d['endDate'] as Timestamp?)?.toDate();
      final name = (d['clinicName'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      final ua = d['updatedAt'] as Timestamp?;
      final ca = d['createdAt'] as Timestamp?;
      final sortTs = ua ?? ca ?? Timestamp.now();
      items.add(_NetDoc(doc.id, name, start, end, sortTs));
    }

    if (items.length < 2) return;

    items.sort((a, b) => b.sortTs.compareTo(a.sortTs));

    final keptIds = <String>{};
    for (final item in items) {
      final isDup = keptIds.any(
        (kid) {
          final k = items.firstWhere((x) => x.id == kid);
          return _sameRoughPeriod(k, item) &&
              _nameLikelyDuplicate(k.clinicName, item.clinicName);
        },
      );
      if (isDup) {
        try {
          await networkRef.doc(item.id).delete();
        } catch (e) {
          debugPrint('⚠️ mergeSimilar delete ${item.id}: $e');
        }
      } else {
        keptIds.add(item.id);
      }
    }
  }

  /// 시작 연도 동일 + 종료 상태 동일(둘 다 재직중 또는 종료 연도 동일)
  static bool _sameRoughPeriod(_NetDoc a, _NetDoc b) {
    if (a.start.year != b.start.year) return false;
    final aCur = a.end == null;
    final bCur = b.end == null;
    if (aCur != bCur) return false;
    if (aCur && bCur) return true;
    return a.end!.year == b.end!.year;
  }

  /// 정규화 후 포함 관계, 또는 짧은 이름은 편집거리 ≤2·긴 이름은 ≤3
  static bool _nameLikelyDuplicate(String a, String b) {
    final x = _normalize(a);
    final y = _normalize(b);
    if (x.isEmpty || y.isEmpty) return false;
    if (x == y) return true;
    if (x.length >= 4 && y.length >= 4) {
      if (x.contains(y) || y.contains(x)) return true;
    }
    final dist = _levenshtein(x, y);
    final minLen = math.min(x.length, y.length);
    final maxDist = minLen >= 8 ? 3 : 2;
    return dist <= maxDist;
  }

  static String _normalize(String raw) {
    var s = raw.trim();
    s = s.replaceAll(RegExp(r'\s+'), '');
    s = s.replaceAll(RegExp(r'[·•\-\(\)\[\]]'), '');
    return s;
  }

  /// 병원명용; 한글 긴 이름 대비 상한 확대
  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    final m = a.length;
    final n = b.length;
    if (m == 0) return n;
    if (n == 0) return m;
    const cap = 64;
    if (m > cap || n > cap) return 999;
    final dp = List.generate(
      m + 1,
      (i) => List<int>.filled(n + 1, 0),
    );
    for (var i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      dp[0][j] = j;
    }
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        var best = dp[i - 1][j] + 1;
        final del = dp[i][j - 1] + 1;
        final sub = dp[i - 1][j - 1] + cost;
        if (del < best) best = del;
        if (sub < best) best = sub;
        dp[i][j] = best;
      }
    }
    return dp[m][n];
  }
}

class _NetDoc {
  final String id;
  final String clinicName;
  final DateTime start;
  final DateTime? end;
  final Timestamp sortTs;

  _NetDoc(this.id, this.clinicName, this.start, this.end, this.sortTs);
}
