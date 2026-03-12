import 'package:flutter/material.dart';
import 'app_colors.dart';

/// ══════════════════════════════════════════════════════
/// TabTheme — 탭별 독립 컬러 팔레트
///
/// 규칙 (절대 법칙):
///   bg=Neon or White  → onBg = Black
///   bg=Blue or Black  → onBg = White
/// ══════════════════════════════════════════════════════
class TabTheme {
  final Color bg;     // 배경
  final Color onBg;   // 배경 위 텍스트/아이콘 (반전 법칙 적용)
  final Color accent; // 포인트(버튼, 하이라이트)
  final Color onAccent; // accent 위 텍스트/아이콘
  final Color cardBg;   // 카드 배경
  final Color onCard;   // 카드 위 텍스트/아이콘
  final Color surface;  // 서브 표면
  final Color border;   // 구분선/테두리
  final Color muted;    // 비활성

  const TabTheme({
    required this.bg,
    required this.onBg,
    required this.accent,
    required this.onAccent,
    required this.cardBg,
    required this.onCard,
    required this.surface,
    required this.border,
    required this.muted,
  });

  // ── 사전 정의 테마 ──────────────────────────────────────

  /// 탭0 (나/Caring): 1번탭 — 현재 Blue 모드 유지
  static const caring = TabTheme(
    bg:       Color(0xFF2E5BFF),
    onBg:     Color(0xFFFFFFFF),
    accent:   Color(0xFFD1FF00),
    onAccent: Color(0xFF000000),
    cardBg:   Color(0xFFFFFFFF),
    onCard:   Color(0xFF000000),
    surface:  Color(0xFF4A6FFF),
    border:   Color(0xFF8AAEFF),
    muted:    Color(0xFFCCD6FF),
  );

  /// 탭1 (같이/Bond): White + Blue
  static const bond = TabTheme(
    bg:       Color(0xFFFFFFFF),
    onBg:     Color(0xFF000000),  // Inversion: White bg → Black text
    accent:   Color(0xFF2E5BFF),
    onAccent: Color(0xFFFFFFFF),  // Blue accent → White text
    cardBg:   Color(0xFFF5F7FF),
    onCard:   Color(0xFF000000),
    surface:  Color(0xFFEEF1FF),
    border:   Color(0xFFD0D8FF),
    muted:    Color(0xFF888888),
  );

  /// 탭2 (성장하기/Growth): Neon + Black
  static const growth = TabTheme(
    bg:       Color(0xFFD1FF00),
    onBg:     Color(0xFF000000),  // Inversion: Neon bg → Black text
    accent:   Color(0xFF000000),
    onAccent: Color(0xFFD1FF00),  // Black accent → Neon text
    cardBg:   Color(0xFFFFFFFF),
    onCard:   Color(0xFF000000),
    surface:  Color(0xFFF5FFB3),
    border:   Color(0xFFB8E600),
    muted:    Color(0xFF444444),
  );

  /// 탭3 (커리어/Job): Black + Neon
  static const job = TabTheme(
    bg:       Color(0xFF000000),
    onBg:     Color(0xFFFFFFFF),  // Inversion: Black bg → White text
    accent:   Color(0xFFD1FF00),
    onAccent: Color(0xFF000000),  // Neon accent → Black text
    cardBg:   Color(0xFF1A1A1A),
    onCard:   Color(0xFFFFFFFF),
    surface:  Color(0xFF222222),
    border:   Color(0xFF333333),
    muted:    Color(0xFF888888),
  );

  static const List<TabTheme> _byIndex = [caring, bond, growth, job];

  /// 탭 인덱스로 테마 조회
  static TabTheme of(int tabIndex) {
    if (tabIndex < 0 || tabIndex >= _byIndex.length) return caring;
    return _byIndex[tabIndex];
  }

  /// BottomNavBar: 현재 탭 기준 배경색
  Color get navBg => bg;

  /// BottomNavBar 선택 아이콘 컬러
  Color get navSelected => accent;

  /// BottomNavBar 비선택 아이콘 컬러
  Color get navUnselected => muted;
}

// ── Provider (ValueNotifier 기반) ───────────────────────

/// 현재 활성 탭 인덱스를 보유 → TabTheme 계산
class TabThemeNotifier extends ChangeNotifier {
  int _tabIndex = 0;

  int get tabIndex => _tabIndex;

  TabTheme get theme => TabTheme.of(_tabIndex);

  void setTab(int index) {
    if (_tabIndex == index) return;
    _tabIndex = index;
    notifyListeners();
  }
}

