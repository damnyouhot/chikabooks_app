import 'package:flutter/material.dart';

import '../../services/content_read_state_service.dart';

/// ══════════════════════════════════════════════════════════════
/// SubTabsCatalog — 메인 탭별 소탭 정의의 단일 출처
///
/// 같이/성장/커리어 페이지마다 흩어져 있는 라벨·아이콘·콘텐츠 키를
/// 한 곳으로 모은다. 이 정의는:
///   - [BottomTabSubMenuOverlay] (떠오르는 소탭 메뉴) 가 사용
///   - 향후 상단 [AppSegmentedControl] 들도 동일 출처로 마이그레이션 가능
///
/// 새 소탭을 추가하거나 라벨/아이콘을 바꿀 때는 이 파일만 손대면
/// 떠오르는 메뉴와 NEW 뱃지 판정이 같이 갱신된다.
/// ══════════════════════════════════════════════════════════════
class SubTab {
  /// 메인 탭(0~3) 내부에서의 0-base 인덱스
  final int index;

  /// 사용자에게 보여줄 짧은 라벨 ("오늘 퀴즈", "공감투표"...)
  final String label;

  /// 떠오르는 메뉴에서 사용할 아이콘 (비선택 상태)
  final IconData icon;

  /// 떠오르는 메뉴에서 사용할 아이콘 (선택 상태)
  final IconData activeIcon;

  /// 이 소탭의 NEW 뱃지 판정에 쓰일 콘텐츠 키 목록.
  /// 비어 있으면 NEW 판정 없음. 여러 개면 OR 조합.
  final List<String> contentKeys;

  const SubTab({
    required this.index,
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.contentKeys = const [],
  });
}

class SubTabsCatalog {
  SubTabsCatalog._();

  /// 메인 탭 인덱스 → 그 안의 소탭 목록.
  /// (탭 0 "나"는 소탭 없음 → 키 없음.)
  static const Map<int, List<SubTab>> _byMainTab = {
    1: [
      SubTab(
        index: 0,
        label: '공감투표',
        icon: Icons.how_to_vote_outlined,
        activeIcon: Icons.how_to_vote,
        contentKeys: [ContentReadKeys.bondPolls],
      ),
      SubTab(
        index: 1,
        label: '속닥속닥',
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        contentKeys: [ContentReadKeys.seniorQuestions],
      ),
    ],
    2: [
      SubTab(
        index: 0,
        label: '오늘 퀴즈',
        icon: Icons.quiz_outlined,
        activeIcon: Icons.quiz,
        contentKeys: [ContentReadKeys.todayQuiz],
      ),
      SubTab(
        index: 1,
        label: '오늘 단어',
        icon: Icons.translate_outlined,
        activeIcon: Icons.translate,
        contentKeys: [ContentReadKeys.todayWords],
      ),
      SubTab(
        index: 2,
        label: '보험정보',
        icon: Icons.description_outlined,
        activeIcon: Icons.description,
        contentKeys: [ContentReadKeys.hiraPolicyUpdates],
      ),
      SubTab(
        index: 3,
        label: '내 서재',
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book,
        contentKeys: [
          ContentReadKeys.ebooks,
          ContentReadKeys.savedHiraUpdates,
          ContentReadKeys.savedWords,
        ],
      ),
    ],
    3: [
      SubTab(
        index: 0,
        label: '공고 보기',
        icon: Icons.work_outline,
        activeIcon: Icons.work,
        contentKeys: [ContentReadKeys.jobs],
      ),
      SubTab(
        index: 1,
        label: '커리어 관리',
        icon: Icons.badge_outlined,
        activeIcon: Icons.badge,
      ),
    ],
  };

  /// 해당 메인 탭에 소탭이 있는지 여부
  static bool hasSubTabs(int mainTabIndex) =>
      (_byMainTab[mainTabIndex]?.isNotEmpty ?? false);

  /// 해당 메인 탭의 소탭 목록 (없으면 빈 리스트)
  static List<SubTab> of(int mainTabIndex) =>
      _byMainTab[mainTabIndex] ?? const [];

  /// 떠오르는 메뉴에서 구독할 NEW 뱃지 매핑.
  /// 반환값: { 소탭인덱스: [콘텐츠키들], ... }
  ///
  /// [ContentReadStateService.watchNewIndices] 에 그대로 넘기면 된다.
  static Map<int, List<String>> contentKeyMapFor(int mainTabIndex) {
    final tabs = of(mainTabIndex);
    return {
      for (final t in tabs)
        if (t.contentKeys.isNotEmpty) t.index: t.contentKeys,
    };
  }
}
