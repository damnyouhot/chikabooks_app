import 'package:flutter/material.dart';

/// ══════════════════════════════════════════════════════════════
/// AppColors — 앱 전체 컬러 단일 소스
///
/// 🎨 색상 변경 방법:
///   Primitive 4개(white/lime/black/blue)만 수정하면
///   Semantic Token → 전체 앱 UI에 자동 반영됩니다.
///
/// 디자인 원칙:
///   - 앱 배경: 크림 화이트 (#FDFAF5) — 따뜻하고 부드러운 느낌
///   - 일반 카드: Green 배경 + White 텍스트
///   - 강조 카드: Orange 배경 + Black 텍스트
///   - 그림자 없음 / 테두리 없음 / 탭별 컬러 차이 없음
///
/// 반전 법칙:
///   Green / Black 채운 요소 → White 텍스트/아이콘
///   Orange / White 채운 요소 → Black 텍스트/아이콘
/// ══════════════════════════════════════════════════════════════
class AppColors {
  AppColors._();

  // ══════════════════════════════════════════════════════════════
  // 🎨 Primitive — 여기 4개만 바꾸면 전체 앱 색상이 바뀝니다
  // ══════════════════════════════════════════════════════════════
  static const white = Color(0xFFFFFFFF);
  static const lime = Color(0xFFAD1F23); // Lobster Red (주황 → 레드 대체)
  static const black = Color(0xFF000000);
  static const blue = Color(0xFF0A0A3A); // Steel Marine (녹색 → 네이비 대체)

  // ══════════════════════════════════════════════════════════════
  // 🏗️ Semantic Token — 역할 기반 색상 (Primitive 참조)
  // ══════════════════════════════════════════════════════════════

  // ── 앱 전체 배경 ──────────────────────────────────────────────
  /// 앱 Scaffold 배경: 크림 화이트 (따뜻하고 부드러운 배경)
  static const appBg = Color(0xFFFDFAF5);

  // ── 텍스트 ──────────────────────────────────────────────────
  /// 주요 텍스트: Pure Black (최대 대비)
  static const textPrimary = black;

  /// 보조 텍스트: 진한 회색
  static const textSecondary = Color(0xFF555555);

  /// 비활성 텍스트
  static const textDisabled = Color(0xFF999999);

  /// 네이버 로그인 버튼·관련 배지 — `assets/auth/sns_naver.png` 배경과 동일 톤
  static const naverLoginGreen = Color(0xFF54B73B);

  // ── 카드 시스템 (2종) ────────────────────────────────────────
  /// 일반 카드 배경: Green
  static const cardPrimary = blue;

  /// 일반 카드 위 텍스트/아이콘: White
  static const onCardPrimary = white;

  /// 강조 카드 배경: Orange
  static const cardEmphasis = lime;

  /// 강조 카드 위 텍스트/아이콘: creamWhite (진한 레드/주황 배경 위 부드러운 화이트)
  static const onCardEmphasis = creamWhite;

  // ── 서피스 / 비활성 영역 ──────────────────────────────────────
  /// Muted surface: 크림 배경 위 부드러운 베이지 (세그먼트 컨테이너, 비활성 배경)
  static const surfaceMuted = Color(0xFFF0EDE6);

  /// Muted surface 위 텍스트
  static const onSurfaceMuted = textSecondary;

  /// Disabled 배경
  static const disabledBg = Color(0xFFE2DDD6);

  /// Disabled 텍스트
  static const disabledText = Color(0xFFB5B0A8);

  // ── 세그먼트/필터/탭 버튼 ─────────────────────────────────────
  /// 세그먼트 선택: Green fill
  static const segmentSelected = blue;

  /// 세그먼트 선택 텍스트: White
  static const onSegmentSelected = white;

  /// 세그먼트 미선택: 투명 (surfaceMuted 컨테이너 위)
  static const segmentUnselected = Color(0x00000000); // transparent
  /// 세그먼트 미선택 텍스트: textSecondary
  static const onSegmentUnselected = textSecondary;

  // ── 내비게이션 바 ────────────────────────────────────────────
  /// BottomNavBar 배경: 크림 화이트 (앱 배경과 통일감)
  static const navBg = Color(0xFFFDFAF5);

  /// BottomNavBar 선택 아이콘/텍스트: Green
  static const navSelected = blue;

  /// BottomNavBar 비선택 아이콘/텍스트
  static const navUnselected = textSecondary;

  // ── 포인트 / 강조 ─────────────────────────────────────────────
  /// 주 포인트 색상 (버튼, 하이라이트): Green
  static const accent = blue;

  /// Accent 위 텍스트/아이콘: White
  static const onAccent = white;

  // ── 구분선 ───────────────────────────────────────────────────
  /// 카드 내부 VerticalDivider / Divider 색상
  static const divider = Color(0xFFE2DDD6);

  // ── 이력서 편집 폼 블록 (appBg 위 밝은 패널 — 기본정보·경력 등) ───
  /// 근무지별 경력 등 복수 블록 배경
  static const resumeFormSurface = white;
  /// 블록 외곽선 (Theme [Card]의 진한색 대신 사용)
  static const resumeFormBlockBorder = divider;

  /// 이력서 임시저장·작성 진행 중간 단계 등 강조 (구 주황 대체)
  /// [cardEmphasis] 단일 소스 — 팔레트 일괄 변경 시 연동
  static const resumeEmphasis = cardEmphasis;

  // ── 크림 화이트 (진한 배경 위 부드러운 강조 텍스트) ──────────────
  /// Green/Orange 카드 등 진한 배경 위 부드러운 화이트 텍스트
  /// 나중에 색상 변경 시 이 토큰 한 곳만 수정하면 전체 반영됨
  static const creamWhite = Color(0xFFFDFAF5);

  // ── 투표/퀴즈 공용 선택지 컬러 (2번탭·3번탭 동일 법칙) ──────────
  // ✅ 이 토큰들만 바꾸면 공감투표·퀴즈 모두 자동 반영
  /// 배지 배경 (이번 주 / Q1 Q2) = cardEmphasis
  static const pollBadgeBg = cardEmphasis;

  /// 배지 텍스트 = onCardEmphasis
  static const pollBadgeText = onCardEmphasis;

  /// 선택지 — 미선택 배경
  static const pollOptionBg = disabledBg;

  /// 선택지 — 선택 배경 = cardEmphasis
  static const pollOptionSelectedBg = cardEmphasis;

  /// 선택지 — 미선택 텍스트
  static const pollOptionText = textPrimary;

  /// 선택지 — 선택 텍스트 = onCardEmphasis
  static const pollOptionSelectedText = onCardEmphasis;

  // 하위 호환 별칭 (퀴즈 전용 → poll* 토큰으로 통합)
  static const quizBadgeBg = pollBadgeBg;
  static const quizBadgeText = pollBadgeText;

  // ── 퀴즈 정답/오답 컬러 — Primitive 기반 semantic token ──────
  // ✅ 정답: 파랑(blue = Steel Marine) 계열
  static const quizCorrect = blue;                    // #0A0A3A
  static const quizCorrectBg = Color(0xFFE8EAF6);    // 연한 인디고 배경
  static const quizCorrectText = blue;
  static const quizCorrectBorder = blue;              // 하위 호환

  // ❌ 오답: 레드(lime = Lobster Red) 계열 — lime 바꾸면 자동 반영
  static const quizWrong = lime;                      // #AD1F23
  static const quizWrongBg = Color(0xFFFFECEC);
  static const quizWrongText = lime;
  static const quizWrongBorder = lime;                // 하위 호환

  // ── 강조 배지/버튼 (치과위생사·관리·단계 등) ──────────────────
  // ✅ 이 토큰 한 곳만 바꾸면 앱 전체 강조 배지가 자동 반영됩니다
  /// 강조 배지 배경: cardEmphasis (Lobster Red)
  static const emphasisBadgeBg = cardEmphasis;

  /// 강조 배지 텍스트: onCardEmphasis (creamWhite)
  static const emphasisBadgeText = onCardEmphasis;

  // ── '준비중' 배지 등 — 어두운 포레스트 그린 ([PrepInProgressBadge]와 동일)
  static const prepBadgeGreen = Color(0xFF14532D);

  // ── 웹 공고자 로그인 · 게시자 인증 진행 ────────────────────────
  /// 페이지 배경: 뉴트럴 라이트 그레이 (크림 대체, 노란기 없음)
  static const webPublisherPageBg = Color(0xFFF0F0F0);

  // ── 의미 컬러 (상태) ─────────────────────────────────────────
  static const success = Color(0xFF00E676);
  static const warning = Color(0xFFFF9100);
  static const error = Color(0xFFFF1744);

  /// 삭제 등 파괴적 액션 — 브랜드 레드 ([lime] / Lobster Red, Material error 아님)
  static const destructive = lime;

  // ── 공고 초안 미리보기 (JobPostPreview) ─────────────────────
  /// '+N' 오버플로 칩 배경 — [surfaceMuted] 별칭 (팔레트 일괄 변경 시 의미 유지)
  static const jobPreviewOverflowChipBg = surfaceMuted;
  /// '+N' 오버플로 칩 글자
  static const jobPreviewOverflowChipText = textSecondary;
}
