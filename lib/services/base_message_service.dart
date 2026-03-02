import 'dart:math';
import '../data/base_message_data.dart';

/// 기본 메시지(우선순위 5) 생성 서비스
///
/// Part1 / Part2 / Part3 전체 풀에서 1문장만 무작위로 반환.
/// 최근 5개 중복 방지 룰 적용 (세션 내).
class BaseMessageService {
  static const int _recentN = 5;
  static final Random _random = Random();

  // 전체 풀 합본 (최초 접근 시 초기화)
  static late final List<String> _allPool = [
    ...BaseMessageData.part1,
    ...BaseMessageData.part2,
    ...BaseMessageData.part3,
  ];

  // 최근 선택 항목 추적 (세션 내 중복 방지)
  static final List<String> _recent = [];

  /// 전체 풀에서 1문장 선택하여 반환
  static String generate() {
    return _pick(_allPool, _recent);
  }

  static String _pick(List<String> pool, List<String> recent) {
    // 최근 N개 제외한 후보군
    final available = pool.where((s) => !recent.contains(s)).toList();
    final candidates =
        available.isNotEmpty ? available : List<String>.from(pool);
    final picked = candidates[_random.nextInt(candidates.length)];

    recent.add(picked);
    if (recent.length > _recentN) recent.removeAt(0);

    return picked;
  }

  /// 세션 내 중복 방지 기록 초기화 (필요 시 호출)
  static void reset() {
    _recent.clear();
  }
}
