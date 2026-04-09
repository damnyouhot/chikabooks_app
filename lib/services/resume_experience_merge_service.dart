import 'package:flutter/foundation.dart';

import '../models/resume.dart';
import 'career_network_dedupe_helper.dart';

/// 이력서 **경력** 후처리: OCR·추출로 같은 근무가 두 줄 생긴 경우 1줄로 합침.
///
/// 커리어 네트워크 [CareerNetworkDedupeHelper]와 동일한 병원명 유사도·
/// `career_network_dedupe_helper`의 기간(시작 연도 + 종료 연도/재직중) 정렬을 사용.
class ResumeExperienceMergeService {
  ResumeExperienceMergeService._();

  /// 순서는 앞쪽 항목을 우선 유지하고, 뒤에서 온 중복만 흡수한다.
  static List<ResumeExperience> mergeSimilar(List<ResumeExperience> list) {
    if (list.length < 2) return list;

    final out = <ResumeExperience>[list.first];
    for (var i = 1; i < list.length; i++) {
      final exp = list[i];
      var merged = false;
      for (var j = 0; j < out.length; j++) {
        if (_canMergeInto(out[j], exp)) {
          out[j] = _mergeTwo(out[j], exp);
          merged = true;
          break;
        }
      }
      if (!merged) out.add(exp);
    }

    if (out.length < list.length) {
      debugPrint(
        '📎 경력 후처리: ${list.length}건 → ${out.length}건 (유사·동일기간 병합)',
      );
    }
    return out;
  }

  static bool _canMergeInto(ResumeExperience kept, ResumeExperience incoming) {
    if (kept.clinicName.trim().isEmpty || incoming.clinicName.trim().isEmpty) {
      return false;
    }
    if (!CareerNetworkDedupeHelper.areProbablySameClinic(
          kept.clinicName,
          incoming.clinicName,
        )) {
      return false;
    }
    return _sameRoughPeriod(kept, incoming);
  }

  /// [CareerNetworkDedupeHelper]의 `_sameRoughPeriod`와 동일한 기준(연도 단위 종료)
  static bool _sameRoughPeriod(ResumeExperience a, ResumeExperience b) {
    final sa = _parseYm(a.start);
    final sb = _parseYm(b.start);
    if (sa == null || sb == null) return false;
    if (sa.year != sb.year) return false;

    final aCur = a.end == '재직중';
    final bCur = b.end == '재직중';
    if (aCur != bCur) return false;
    if (aCur && bCur) return true;

    final ea = _parseYm(a.end);
    final eb = _parseYm(b.end);
    if (ea == null || eb == null) return false;
    return ea.year == eb.year;
  }

  static DateTime? _parseYm(String s) {
    if (s.isEmpty) return null;
    final parts = s.split('-');
    if (parts.length < 2) return null;
    try {
      return DateTime(int.parse(parts[0]), int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  static ResumeExperience _mergeTwo(ResumeExperience a, ResumeExperience b) {
    final sa = _parseYm(a.start);
    final sb = _parseYm(b.start);
    final startStr = _earlierYm(sa, sb);

    final endStr = _mergeEnd(a.end, b.end);

    final name = _pickClinicName(a.clinicName, b.clinicName);
    final region = a.region.trim().isNotEmpty ? a.region : b.region;

    return ResumeExperience(
      clinicName: name,
      region: region,
      start: startStr,
      end: endStr,
      tasks: _mergeUniqueStrings(a.tasks, b.tasks),
      tools: _mergeUniqueStrings(a.tools, b.tools),
      achievementsText: _mergeAchievements(a.achievementsText, b.achievementsText),
    );
  }

  static String _earlierYm(DateTime? a, DateTime? b) {
    if (a == null && b == null) return '';
    if (a == null) return _formatYm(b!);
    if (b == null) return _formatYm(a);
    return a.isBefore(b) ? _formatYm(a) : _formatYm(b);
  }

  static String _formatYm(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static String _mergeEnd(String a, String b) {
    if (a == '재직중' || b == '재직중') return '재직중';
    final pa = _parseYm(a);
    final pb = _parseYm(b);
    if (pa != null && pb != null) {
      return pa.isAfter(pb) ? a : b;
    }
    if (pa != null) return a;
    if (pb != null) return b;
    return a.isNotEmpty ? a : b;
  }

  static String _pickClinicName(String a, String b) {
    final ta = a.trim();
    final tb = b.trim();
    if (ta.isEmpty) return tb;
    if (tb.isEmpty) return ta;
    final na = _normalizeForLength(ta);
    final nb = _normalizeForLength(tb);
    if (na.contains(nb) && ta.length >= tb.length) return ta;
    if (nb.contains(na) && tb.length >= ta.length) return tb;
    return ta.length >= tb.length ? ta : tb;
  }

  static String _normalizeForLength(String s) =>
      s.replaceAll(RegExp(r'\s+'), '');

  static List<String> _mergeUniqueStrings(List<String> a, List<String> b) {
    final seen = <String>{};
    final out = <String>[];
    for (final s in [...a, ...b]) {
      final t = s.trim();
      if (t.isEmpty) continue;
      if (seen.add(t)) out.add(t);
    }
    return out;
  }

  static String? _mergeAchievements(String? a, String? b) {
    final ta = a?.trim() ?? '';
    final tb = b?.trim() ?? '';
    if (ta.isEmpty) return tb.isEmpty ? null : tb;
    if (tb.isEmpty) return ta;
    if (ta == tb) return ta;
    return '$ta\n$tb';
  }
}
