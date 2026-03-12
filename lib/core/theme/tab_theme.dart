import 'package:flutter/material.dart';
import 'app_colors.dart';

/// ══════════════════════════════════════════════════════
/// TabTheme — 탭별 독립 컬러 팔레트
///
/// 🎨 색상 변경 방법:
///   app_colors.dart의 Primitive 4개(white/lime/black/blue)만 수정하면
///   아래 모든 탭 테마에 자동 반영됩니다.
///
/// 규칙 (절대 법칙):
///   bg=Neon or White  → onBg = Black
///   bg=Blue or Black  → onBg = White
/// ══════════════════════════════════════════════════════
class TabTheme {
  final Color bg;       // 배경
  final Color onBg;     // 배경 위 텍스트/아이콘 (반전 법칙 적용)
  final Color accent;   // 포인트(버튼, 하이라이트)
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
  // 모두 AppColors Primitive 참조 — hex 직접 입력 금지

  /// 탭0 (나/Caring): Blue 배경 + Neon 포인트
  static const caring = TabTheme(
    bg:       AppColors.blue,
    onBg:     AppColors.white,   // Blue bg → White text
    accent:   AppColors.lime,
    onAccent: AppColors.black,   // Neon accent → Black text
    cardBg:   AppColors.white,
    onCard:   AppColors.black,
    surface:  Color(0xFF4A6FFF), // blue 보다 밝은 서브 (파생값)
    border:   Color(0xFF8AAEFF), // 연파랑 테두리 (파생값)
    muted:    Color(0xFFCCD6FF), // 매우 연한 파랑 (파생값)
  );

  /// 탭1 (같이/Bond): White 배경 + Blue 포인트
  static const bond = TabTheme(
    bg:       AppColors.white,
    onBg:     AppColors.black,   // White bg → Black text
    accent:   AppColors.blue,
    onAccent: AppColors.white,   // Blue accent → White text
    cardBg:   Color(0xFFF5F7FF), // 아주 연한 파랑 카드 (파생값)
    onCard:   AppColors.black,
    surface:  Color(0xFFEEF1FF), // 파생값
    border:   Color(0xFFD0D8FF), // 파생값
    muted:    Color(0xFF888888), // 중간 회색
  );

  /// 탭2 (성장하기/Growth): Neon 배경 + Black 포인트
  static const growth = TabTheme(
    bg:       AppColors.lime,
    onBg:     AppColors.black,   // Neon bg → Black text
    accent:   AppColors.black,
    onAccent: AppColors.lime,    // Black accent → Neon text
    cardBg:   AppColors.white,
    onCard:   AppColors.black,
    surface:  Color(0xFFF5FFB3), // 연한 라임 (파생값)
    border:   Color(0xFFB8E600), // 진한 라임 테두리 (파생값)
    muted:    Color(0xFF444444), // 어두운 회색
  );

  /// 탭3 (커리어/Job): Black 배경 + Neon 포인트
  static const job = TabTheme(
    bg:       AppColors.black,
    onBg:     AppColors.white,   // Black bg → White text
    accent:   AppColors.lime,
    onAccent: AppColors.black,   // Neon accent → Black text
    cardBg:   Color(0xFF1A1A1A), // 진한 검정 카드 (파생값)
    onCard:   AppColors.white,
    surface:  Color(0xFF222222), // 파생값
    border:   Color(0xFF333333), // 파생값
    muted:    Color(0xFF888888), // 중간 회색
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

// ── Provider (ChangeNotifier 기반) ───────────────────────

/// 현재 활성 탭 인덱스를 보유 → TabTheme 계산
class TabThemeNotifier extends ChangeNotifier {
  int _tabIndex = 0;

  int get tabIndex => _tabIndex;

  TabTheme get currentTheme => TabTheme.of(_tabIndex);

  // home_shell.dart 호환용 별칭
  TabTheme get theme => currentTheme;

  void setTab(int index) {
    if (_tabIndex == index) return;
    _tabIndex = index;
    notifyListeners();
  }
}
