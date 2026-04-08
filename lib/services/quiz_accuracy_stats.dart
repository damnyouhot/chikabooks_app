/// 퀴즈 정답률(0~100%) 버킷 집계 헬퍼 — `QuizPoolService.saveAnswer`와 UI에서 공유.
class QuizAccuracyStats {
  QuizAccuracyStats._();

  /// 정답률 0~100 정수(%). 시도 0이면 null.
  static int? accuracyPercent(int correct, int wrong) {
    final t = correct + wrong;
    if (t <= 0) return null;
    return ((correct / t) * 100).round().clamp(0, 100);
  }

  static void applyBucketMove({
    required Map<String, dynamic> dist,
    required int? oldPct,
    required int newPct,
    required bool firstReg,
    required void Function(int deltaParticipants) onParticipantDelta,
  }) {
    final nk = newPct.toString();
    if (firstReg) {
      onParticipantDelta(1);
      dist[nk] = ((dist[nk] as num?)?.toInt() ?? 0) + 1;
      return;
    }
    if (oldPct != null && oldPct == newPct) return;

    if (oldPct != null) {
      final ok = oldPct.toString();
      final prevC = (dist[ok] as num?)?.toInt() ?? 0;
      if (prevC <= 0) {
        onParticipantDelta(1);
        dist[nk] = ((dist[nk] as num?)?.toInt() ?? 0) + 1;
        return;
      }
      if (prevC <= 1) {
        dist.remove(ok);
      } else {
        dist[ok] = prevC - 1;
      }
    }
    dist[nk] = ((dist[nk] as num?)?.toInt() ?? 0) + 1;
  }
}
