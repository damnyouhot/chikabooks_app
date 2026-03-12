import 'package:flutter/material.dart';
import 'app_colors.dart';

/// ══════════════════════════════════════════════════════
/// TabTheme — 탭별 독립 컬러 팔레트
///
/// 🎨 색상 변경 방법:
///   app_colors.dart의 Primitive 4개(white/lime/black/blue)만 수정하면
///   아래 모든 탭 테마에 자동 반영됩니다.
///
/// 공통 배경: 모든 탭 White — 내부 카드/버튼으로 대비 표현
/// 반전 법칙:
///   Blue/Black 채운 요소 → White 텍스트/아이콘
///   Neon/White 채운 요소 → Black 텍스트/아이콘
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
  // 공통: 모든 탭 bg = White → 내부 카드/버튼으로 대비 강화
  // 반전 법칙: Blue/Black 채운 요소 → White 텍스트
  //            Neon/White 채운 요소  → Black 텍스트

  /// 탭0 (나/Caring): White 배경 + Blue 포인트 + Neon 강조
  static const caring = TabTheme(
    bg:       AppColors.white,
    onBg:     AppColors.black,   // White bg → Black text
    accent:   AppColors.blue,    // 버튼/카드 채움: Blue
    onAccent: AppColors.white,   // Blue 위 → White text
    cardBg:   Color(0xFFF0F4FF), // 연파랑 카드 배경
    onCard:   AppColors.black,
    surface:  Color(0xFFE8EDFF), // 서브 표면 (연파랑)
    border:   AppColors.blue,    // 테두리: Blue (선명하게)
    muted:    Color(0xFF555555), // 비활성: 진한 회색 (가독성↑)
  );

  /// 탭1 (같이/Bond): White 배경 + Blue 포인트 + Neon 강조
  static const bond = TabTheme(
    bg:       AppColors.white,
    onBg:     AppColors.black,   // White bg → Black text
    accent:   AppColors.blue,
    onAccent: AppColors.white,   // Blue accent → White text
    cardBg:   Color(0xFFF0F4FF), // 연파랑 카드 배경
    onCard:   AppColors.black,
    surface:  Color(0xFFE8EDFF), // 파생값
    border:   AppColors.blue,    // 테두리: Blue (선명하게)
    muted:    Color(0xFF555555), // 진한 회색
  );

  /// 탭2 (성장하기/Growth): White 배경 + Neon 포인트 + Black 강조
  static const growth = TabTheme(
    bg:       AppColors.white,
    onBg:     AppColors.black,   // White bg → Black text
    accent:   AppColors.lime,    // 버튼/카드 채움: Neon
    onAccent: AppColors.black,   // Neon 위 → Black text
    cardBg:   Color(0xFFF8FFD6), // 연한 Neon 카드 배경
    onCard:   AppColors.black,
    surface:  Color(0xFFF0FFB0), // 서브 표면 (연라임)
    border:   Color(0xFFB8E600), // 테두리: 진한 라임 (선명하게)
    muted:    Color(0xFF444444), // 비활성: 어두운 회색
  );

  /// 탭3 (커리어/Job): White 배경 + Black 포인트 + Neon 강조
  static const job = TabTheme(
    bg:       AppColors.white,
    onBg:     AppColors.black,   // White bg → Black text
    accent:   AppColors.black,   // 버튼/카드 채움: Black
    onAccent: AppColors.white,   // Black 위 → White text
    cardBg:   Color(0xFFF2F2F2), // 연한 회색 카드 배경
    onCard:   AppColors.black,
    surface:  Color(0xFFE8E8E8), // 파생값
    border:   AppColors.black,   // 테두리: Black (선명하게)
    muted:    Color(0xFF555555), // 비활성: 진한 회색
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
