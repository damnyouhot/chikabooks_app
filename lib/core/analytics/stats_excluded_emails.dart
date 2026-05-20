/// 대시보드 통계·activityLogs 에서 제외할 계정 이메일 (소문자 정규화 기준).
///
/// - [excludeFromStats] 와 별도로, Firestore 플래그 설정 전·누락 시에도
///   기록·집계에서 빼기 위한 코드 화이트리스트입니다.
/// - 관리자 대시보드 접근([isAdmin])과 무관합니다.
class StatsExcludedEmails {
  StatsExcludedEmails._();

  static const Set<String> normalized = {
    'bma2080@naver.com',
  };

  static bool isExcludedEmail(String? email) {
    if (email == null || email.trim().isEmpty) return false;
    return normalized.contains(email.trim().toLowerCase());
  }

  static bool isExcludedUserData(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['excludeFromStats'] == true) return true;
    final raw = data['normalizedEmail'] ?? data['email'];
    if (raw is! String) return false;
    return isExcludedEmail(raw);
  }
}
