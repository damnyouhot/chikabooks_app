import 'package:flutter/material.dart';
import 'app_colors.dart';

/// ══════════════════════════════════════════════════════
/// TabTheme — 탭별 독립 컬러 팔레트 (단일 소스)
///
/// 🎨 색상 변경 방법:
///   app_colors.dart의 Primitive 4개(white/lime/black/blue)만 수정하면
///   아래 모든 탭 테마에 자동 반영됩니다.
///
/// 공통 배경: 모든 탭 White — 내부 카드/버튼으로 대비 표현
/// 반전 법칙:
///   Blue/Black 채운 요소 → White 텍스트/아이콘
///   Neon/White 채운 요소 → Black 텍스트/아이콘
///
/// 카드 종류 (같이 탭 등 복합 카드 지원):
///   cardBg       — 기본 카드 (연한 색조)
///   cardStrong   — 강조 채움 카드 (accent 색으로 채움, 텍스트 onAccent)
///   cardNeon     — 형광 채움 카드 (lime 색으로 채움, 텍스트 Black)
///   cardDark     — 다크 채움 카드 (거의 검정, 텍스트 White)
/// ══════════════════════════════════════════════════════
class TabTheme {
  final Color bg;          // 배경
  final Color onBg;        // 배경 위 텍스트/아이콘
  final Color accent;      // 포인트(버튼, 하이라이트)
  final Color onAccent;    // accent 위 텍스트/아이콘
  final Color cardBg;      // 기본 카드 배경
  final Color onCard;      // 카드 위 텍스트/아이콘
  final Color surface;     // 서브 표면
  final Color border;      // 구분선/테두리
  final Color muted;       // 비활성
  // ── 강조 카드 (구 BondColors 통합) ──────────────────
  final Color cardStrong;  // 강조 채움 카드 배경 (Blue 등)
  final Color onCardStrong;// 강조 카드 위 텍스트
  final Color cardNeon;    // 형광 채움 카드 배경
  final Color onCardNeon;  // 형광 카드 위 텍스트
  final Color cardDark;    // 다크 채움 카드 배경
  final Color onCardDark;  // 다크 카드 위 텍스트
  // ── 파생 색상 ────────────────────────────────────────
  final Color shadow1;     // 그림자/구분선 (연한)
  final Color shadow2;     // 더 연한 구분선

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
    required this.cardStrong,
    required this.onCardStrong,
    required this.cardNeon,
    required this.onCardNeon,
    required this.cardDark,
    required this.onCardDark,
    required this.shadow1,
    required this.shadow2,
  });

  // ── 사전 정의 테마 ──────────────────────────────────────
  // 공통: 모든 탭 bg = White → 내부 카드/버튼으로 대비 강화
  // 반전 법칙: Blue/Black 채운 요소 → White 텍스트
  //            Neon/White 채운 요소  → Black 텍스트

  /// 탭0 (나/Caring): White 배경 + Blue 포인트
  static const caring = TabTheme(
    bg:           AppColors.white,
    onBg:         AppColors.black,
    accent:       AppColors.blue,
    onAccent:     AppColors.white,
    cardBg:       Color(0xFFF0F4FF),   // 연파랑 카드 배경
    onCard:       AppColors.black,
    surface:      Color(0xFFE8EDFF),
    border:       AppColors.blue,
    muted:        Color(0xFF555555),
    cardStrong:   AppColors.blue,      // Blue 채움 카드
    onCardStrong: AppColors.white,
    cardNeon:     AppColors.lime,      // Neon 채움 카드
    onCardNeon:   AppColors.black,
    cardDark:     Color(0xFF111111),   // Dark 채움 카드
    onCardDark:   AppColors.white,
    shadow1:      Color(0xFFD0D8FF),   // 연파랑 그림자
    shadow2:      Color(0xFFEEF1FF),   // 더 연한 파랑
  );

  /// 탭1 (같이/Bond): White 배경 + Blue 포인트
  static const bond = TabTheme(
    bg:           AppColors.white,
    onBg:         AppColors.black,
    accent:       AppColors.blue,
    onAccent:     AppColors.white,
    cardBg:       Color(0xFFF5F7FF),   // 연파랑 카드 배경 (구 BondColors.kCardBg)
    onCard:       AppColors.black,
    surface:      Color(0xFFEEF1FF),
    border:       AppColors.blue,
    muted:        Color(0xFF888888),
    cardStrong:   AppColors.blue,      // Blue 채움 카드 (구 blueCardDecoration)
    onCardStrong: AppColors.white,
    cardNeon:     AppColors.lime,      // Neon 채움 카드 (구 neonCardDecoration)
    onCardNeon:   AppColors.black,
    cardDark:     Color(0xFF111111),   // Dark 채움 카드 (구 darkCardDecoration)
    onCardDark:   AppColors.white,
    shadow1:      Color(0xFFD0D8FF),   // 구 BondColors.kShadow1
    shadow2:      Color(0xFFEEF1FF),   // 구 BondColors.kShadow2
  );

  /// 탭2 (성장하기/Growth): White 배경 + Blue 포인트
  static const growth = TabTheme(
    bg:           AppColors.white,
    onBg:         AppColors.black,
    accent:       AppColors.blue,      // Blue로 통일
    onAccent:     AppColors.white,     // Blue 위 → White
    cardBg:       Color(0xFFF0F4FF),   // 연파랑 카드 배경
    onCard:       AppColors.black,
    surface:      Color(0xFFE8EDFF),
    border:       AppColors.blue,
    muted:        Color(0xFF555555),
    cardStrong:   AppColors.blue,      // Blue 채움 카드
    onCardStrong: AppColors.white,
    cardNeon:     AppColors.lime,      // 형광 채움 카드 (보조 유지)
    onCardNeon:   AppColors.black,
    cardDark:     Color(0xFF111111),
    onCardDark:   AppColors.white,
    shadow1:      Color(0xFFD0D8FF),   // 연파랑 그림자
    shadow2:      Color(0xFFEEF1FF),
  );

  /// 탭3 (커리어/Job): White 배경 + Blue 포인트
  static const job = TabTheme(
    bg:           AppColors.white,
    onBg:         AppColors.black,
    accent:       AppColors.blue,      // Blue로 통일
    onAccent:     AppColors.white,     // Blue 위 → White
    cardBg:       Color(0xFFF0F4FF),   // 연파랑 카드 배경
    onCard:       AppColors.black,
    surface:      Color(0xFFE8EDFF),
    border:       AppColors.blue,
    muted:        Color(0xFF555555),
    cardStrong:   AppColors.blue,      // Blue 채움 카드
    onCardStrong: AppColors.white,
    cardNeon:     AppColors.lime,      // 형광 채움 카드 (보조 유지)
    onCardNeon:   AppColors.black,
    cardDark:     Color(0xFF111111),
    onCardDark:   AppColors.white,
    shadow1:      Color(0xFFD0D8FF),   // 연파랑 그림자
    shadow2:      Color(0xFFEEF1FF),
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

  // ── 카드 데코레이션 헬퍼 (구 BondColors 통합) ────────────

  /// 기본 카드 데코레이션
  BoxDecoration cardDecoration({double radius = 16}) => BoxDecoration(
    color: cardBg,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: shadow1.withOpacity(0.5), width: 0.8),
    boxShadow: [
      BoxShadow(
        color: accent.withOpacity(0.07),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ],
  );

  /// 강조 채움 카드 데코레이션 (accent 색으로 채움)
  BoxDecoration strongCardDecoration({double radius = 16}) => BoxDecoration(
    color: cardStrong,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: cardStrong.withOpacity(0.35),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ],
  );

  /// Neon 채움 카드 데코레이션
  BoxDecoration neonCardDecoration({double radius = 16}) => BoxDecoration(
    color: cardNeon,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: cardNeon.withOpacity(0.45),
        blurRadius: 14,
        offset: const Offset(0, 5),
      ),
    ],
  );

  /// Dark 채움 카드 데코레이션
  BoxDecoration darkCardDecoration({double radius = 16}) => BoxDecoration(
    color: cardDark,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: AppColors.black.withOpacity(0.25),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );
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
