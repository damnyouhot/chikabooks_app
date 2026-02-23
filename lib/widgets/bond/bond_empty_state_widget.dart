import 'package:flutter/material.dart';
import '../../models/partner_group.dart';

/// 파트너 시스템 상태별 엣지케이스 UI
/// - 그룹 없음 (첫 진입, 매칭 대기)
/// - Pause 상태 (읽기 전용)
/// - 그룹 만료 임박
class BondEmptyStateWidget extends StatelessWidget {
  final String state; // 'no_group', 'pause', 'expiring_soon'
  final VoidCallback? onAction;

  const BondEmptyStateWidget({super.key, required this.state, this.onAction});

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case 'no_group':
        return _buildNoGroupState();
      case 'pause':
        return _buildPauseState();
      case 'expiring_soon':
        return _buildExpiringSoonState();
      default:
        return const SizedBox.shrink();
    }
  }

  /// 그룹 없음 (첫 진입 또는 매칭 대기)
  Widget _buildNoGroupState() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E88E5).withOpacity(0.1),
            ),
            child: const Icon(
              Icons.auto_stories_outlined,
              size: 40,
              color: Color(0xFF1E88E5),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '조용한 페이지',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF424242),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '이번 주는 아직 페이지가 열리지 않았어.\n월요일 오전 9시,\n새로운 동행이 자동으로 이어져.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_note, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '파트너가 없어도 오늘을 남길 수 있어',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Pause 상태 (읽기 전용)
  Widget _buildPauseState() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.orange.withOpacity(0.1),
            ),
            child: Icon(
              Icons.pause_circle_outline,
              size: 40,
              color: Colors.orange[700],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '지금은 쉬는 중',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF424242),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '결 탭은 읽기만 가능해요\n언제든 다시 시작할 수 있어요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// 그룹 만료 임박 (일요일 저녁)
  Widget _buildExpiringSoonState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, size: 22, color: Color(0xFFF57C00)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '이번 주가 곧 끝나요',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF424242),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '월요일 오전 9시에 새 파트너와 함께해요',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 파트너 그룹 상태 체크 헬퍼
class BondStateHelper {
  /// ✅ 핵심: 그룹이 진짜 유효한지 확인 (endsAt > now)
  static bool isGroupActive(PartnerGroup? group) {
    if (group == null) return false;

    final now = DateTime.now().toUtc(); // UTC 기준
    final endsAt = group.endsAt.toUtc(); // UTC로 변환

    // 1. endsAt이 현재보다 미래여야 함
    if (endsAt.isBefore(now)) {
      return false;
    }

    // 2. isActiveGroup 필드도 체크
    if (!group.isActiveGroup) {
      return false;
    }

    // 3. 멤버가 1명 이상이어야 함
    if (group.memberUids.isEmpty) {
      return false;
    }

    return true;
  }

  /// 그룹 만료 임박 여부 (일요일 18:00 이후)
  static bool isExpiringSoon(PartnerGroup? group) {
    if (group == null || !isGroupActive(group)) return false;

    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    final dayOfWeek = kst.weekday; // 1=월, 7=일
    final hour = kst.hour;

    // 일요일 18:00 이후
    if (dayOfWeek == 7 && hour >= 18) {
      return true;
    }

    // 월요일 08:30 이전
    if (dayOfWeek == 1 && hour < 9) {
      return true;
    }

    return false;
  }

  /// 이어가기 선택 가능 시간대 여부
  static bool canSelectContinue(PartnerGroup? group) {
    if (group == null || !isGroupActive(group) || group.memberUids.length < 2) {
      return false;
    }

    return isExpiringSoon(group);
  }

  /// Pause 상태 여부
  static bool isPaused(String partnerStatus) {
    return partnerStatus == 'pause';
  }

  /// ✅ 핵심: 그룹 상태 문자열 반환 (단일 진실 소스)
  /// - partnerGroupId 존재
  /// - 그룹 문서 존재
  /// - endsAt > now
  /// → 이 조건을 만족할 때만 "파트너 있음"
  static String getGroupStateString(PartnerGroup? group, String partnerStatus) {
    // 1. Pause 상태는 최우선
    if (isPaused(partnerStatus)) {
      return 'pause';
    }

    // 2. 그룹이 없거나 만료됨
    if (group == null || !isGroupActive(group)) {
      return 'no_group';
    }

    // 3. 그룹은 유효하지만 만료 임박
    if (isExpiringSoon(group)) {
      return 'expiring_soon';
    }

    // 4. 정상 활동 중
    return 'active';
  }

  /// 파트너가 있는 상태인지 (파트너 UI 렌더링 가능 여부)
  static bool hasActivePartner(PartnerGroup? group, String partnerStatus) {
    final state = getGroupStateString(group, partnerStatus);
    return state == 'active' || state == 'expiring_soon';
  }
}
