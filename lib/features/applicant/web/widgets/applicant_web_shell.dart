import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import 'applicant_side_nav.dart';
import 'applicant_top_bar.dart';

/// 웹 일반계정(지원자) 페이지 공통 셸.
///
/// 구조:
///   ┌──── ApplicantTopBar ────┐
///   │ ApplicantSideNav │ body │   (넓은 폭)
///   └──────────────────┴──────┘
///
///   ┌──── ApplicantTopBar (☰) ┐
///   │            body         │   (좁은 폭, 사이드바는 Drawer)
///   └─────────────────────────┘
///
/// 본문은 [contentMaxWidth] 로 폭을 제한하고 가운데 정렬한다.
class ApplicantWebShell extends StatefulWidget {
  const ApplicantWebShell({
    super.key,
    required this.body,
    this.searchSlot,
    this.constrainContent = true,
    this.padding,
    this.scrollable = true,
  });

  /// 본문.
  final Widget body;

  /// 상단 헤더 가운데 슬롯에 들어갈 검색바. null 이면 빈 영역.
  final Widget? searchSlot;

  /// 본문 폭 제한 적용 여부. (false 이면 풀 너비, 페이지 자체에서 컨테이너 처리)
  final bool constrainContent;

  /// 본문 패딩 커스터마이즈 (null 이면 기본값 적용)
  final EdgeInsetsGeometry? padding;

  /// 본문을 셸 내부 [SingleChildScrollView] 로 감쌀지 여부.
  ///
  /// 기본 true — 짧은 페이지에서도 스크롤 가능하도록 안전하게 감싼다.
  /// 페이지가 [CustomScrollView] 처럼 자체 스크롤 위젯을 들고 있다면
  /// false 로 두어 이중 스크롤을 방지한다.
  final bool scrollable;

  @override
  State<ApplicantWebShell> createState() => _ApplicantWebShellState();
}

class _ApplicantWebShellState extends State<ApplicantWebShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final wide = width >= AppApplicant.sideNavBreakpoint;

    final hPadding = wide
        ? AppApplicant.contentHPadding
        : AppApplicant.contentHPaddingNarrow;

    Widget body = widget.body;
    if (widget.constrainContent) {
      body = Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppApplicant.contentMaxWidth),
          child: Padding(
            padding: widget.padding ??
                EdgeInsets.symmetric(horizontal: hPadding, vertical: 24),
            child: body,
          ),
        ),
      );
    } else if (widget.padding != null) {
      body = Padding(padding: widget.padding!, child: body);
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.appBg,
      drawer: wide
          ? null
          : Drawer(
              backgroundColor: AppColors.white,
              child: SafeArea(
                child: ApplicantSideNav(
                  onItemTap: (_) => Navigator.of(context).maybePop(),
                ),
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            ApplicantTopBar(
              showMenu: !wide,
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
              searchSlot: widget.searchSlot,
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wide) const ApplicantSideNav(),
                  Expanded(
                    child: widget.scrollable
                        ? SingleChildScrollView(child: body)
                        : body,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
