import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../services/content_read_state_service.dart';
import 'sub_tabs_catalog.dart';

/// ══════════════════════════════════════════════════════════════
/// BottomTabSubMenuOverlay — 하단 메인 메뉴 위로 떠오르는 소탭 메뉴
///
/// 동작:
///   - HomeShell이 사용자의 손가락 동작에 따라 [visible], [mode],
///     [pointerGlobalPosition] 을 갱신한다.
///   - 이 위젯은 시각 표현과 NEW 뱃지 구독, 호버된 소탭 계산만 담당
///     (실제 제스처/선택은 HomeShell 의 GestureDetector 에서 처리).
///
/// 두 가지 모드:
///   - [SubMenuMode.hint]
///       짧은 탭 직후 잠깐 떴다 사라지는 학습용 페이드 힌트.
///       사용자가 손을 이미 뗀 상태이므로 호버 하이라이트 없음.
///   - [SubMenuMode.interactive]
///       사용자가 누른 상태로 유지 중. 손가락 위 소탭이 강조되고
///       NEW 뱃지가 실시간으로 켜진다.
///
/// 디자인:
///   - 패널: white + 옅은 그림자 + 큰 라운드 (appBg 위에 떠 보이게)
///   - 아이템: 평소 surfaceMuted 알약 / 호버 시 cardPrimary(blue) 필
///   - NEW 뱃지: 기존 _NavNewBadge 와 동일 노란색·펄스
/// ══════════════════════════════════════════════════════════════

enum SubMenuMode {
  /// 메뉴를 그리지 않음
  hidden,

  /// 페이드 힌트 (짧게 떴다 사라짐, 호버 없음)
  hint,

  /// 사용자가 누른 채로 유지 중 — 호버/슬라이드 선택 가능
  interactive,
}

class BottomTabSubMenuOverlay extends StatefulWidget {
  const BottomTabSubMenuOverlay({
    super.key,
    required this.mainTabIndex,
    required this.mode,
    required this.bottomNavHeight,
    this.pointerGlobalPosition,
    this.defaultSelectedIndex = -1,
    this.onHoveredSubIndexChanged,
    this.onDismissed,
  });

  /// 어떤 메인 탭의 소탭들을 보여줄지 (1, 2, 3 중 하나).
  /// 0 ("나") 또는 소탭이 없는 탭이면 [BottomTabSubMenuOverlay] 가
  /// 빈 위젯을 반환한다.
  final int mainTabIndex;

  /// 현재 표시 모드
  final SubMenuMode mode;

  /// 떠오르는 메뉴가 하단 메인 메뉴 위로 얼마나 띄워질지 계산용
  /// (현재는 미사용 — bottom: 0 으로 BottomNavigationBar 윗선에 직접 붙임.)
  final double bottomNavHeight;

  /// 손가락의 글로벌 좌표 ([SubMenuMode.interactive] 일 때만 의미 있음)
  final Offset? pointerGlobalPosition;

  /// "손을 지금 떼면 가게 될 소탭" 의 [SubTab.index]. (-1 = 없음)
  /// 현재는 해당 메인탭이 마지막으로 보고 있던 소탭. hover 가 있을 땐 hover 가
  /// 우선 보이고, hover 가 없는 짧은 페이드 힌트 / interactive 진입 직후 등에
  /// 옅은 음영으로 표시되어 사용자가 결과를 미리 알 수 있게 한다.
  final int defaultSelectedIndex;

  /// 손가락 위치가 어느 소탭 위로 갔는지 상위에 알려줌
  /// (선택 없음 = -1). HomeShell 은 이 값을 받아 손 뗄 때 이동.
  final ValueChanged<int>? onHoveredSubIndexChanged;

  /// 페이드아웃 애니메이션이 완전히 끝나 위젯을 트리에서 제거해도 안전한 시점.
  /// HomeShell 은 이 콜백을 받으면 [_subMenuForTab] 을 -1 로 되돌려 위젯을 해제한다.
  final VoidCallback? onDismissed;

  @override
  State<BottomTabSubMenuOverlay> createState() =>
      _BottomTabSubMenuOverlayState();
}

class _BottomTabSubMenuOverlayState extends State<BottomTabSubMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _slide;

  /// 메뉴 패널의 GlobalKey — 손가락 좌표가 어느 아이템 위인지 계산할 때 사용
  final GlobalKey _panelKey = GlobalKey();

  int _lastReportedHover = -1;

  /// 소탭 NEW 뱃지용 스트림.
  ///
  /// build() 안에서 매번 새로 만들면 setState 마다 재구독되어 NEW 가 깜빡이므로,
  /// mainTabIndex 변경 시에만 재생성하고 그 외에는 동일 인스턴스를 유지.
  late Stream<Set<int>> _newIndicesStream;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _slide = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutBack,
      // reverse 시 back curve 가 거꾸로 튀는 느낌을 없애려 부드러운 ease-in 으로.
      reverseCurve: Curves.easeInCubic,
    );
    _ctrl.addStatusListener(_handleStatus);
    if (widget.mode != SubMenuMode.hidden) {
      _ctrl.value = 1;
    }
    _newIndicesStream = ContentReadStateService.watchNewIndices(
      SubTabsCatalog.contentKeyMapFor(widget.mainTabIndex),
    );
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && widget.mode == SubMenuMode.hidden) {
      widget.onDismissed?.call();
    }
  }

  @override
  void didUpdateWidget(covariant BottomTabSubMenuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldShow = widget.mode != SubMenuMode.hidden;
    if (shouldShow && _ctrl.status != AnimationStatus.completed) {
      _ctrl.forward();
    } else if (!shouldShow && _ctrl.value > 0) {
      _ctrl.reverse();
    }

    if (widget.mainTabIndex != oldWidget.mainTabIndex) {
      _lastReportedHover = -1;
      _newIndicesStream = ContentReadStateService.watchNewIndices(
        SubTabsCatalog.contentKeyMapFor(widget.mainTabIndex),
      );
    }

    if (widget.mode == SubMenuMode.interactive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _reportHoverFromPointer();
      });
    } else if (oldWidget.mode == SubMenuMode.interactive &&
        _lastReportedHover != -1) {
      _lastReportedHover = -1;
      widget.onHoveredSubIndexChanged?.call(-1);
    }
  }

  @override
  void dispose() {
    _ctrl.removeStatusListener(_handleStatus);
    _ctrl.dispose();
    super.dispose();
  }

  /// 현재 [widget.pointerGlobalPosition] 가 어떤 소탭 위인지 계산해 상위에 통지.
  ///
  /// 세로 배치 — 패널 안에서 위쪽이 표시 인덱스 0, 아래쪽이 마지막. 표시는
  /// [SubTabsCatalog] 의 역순이므로 (좌측 메뉴일수록 아래) 실제 [SubTab.index] 로
  /// 변환해서 상위에 전달한다.
  void _reportHoverFromPointer() {
    if (!mounted) return;
    final tabs = SubTabsCatalog.of(widget.mainTabIndex);
    if (tabs.isEmpty) return;

    final pointer = widget.pointerGlobalPosition;
    final renderBox =
        _panelKey.currentContext?.findRenderObject() as RenderBox?;
    if (pointer == null || renderBox == null) {
      _setHover(-1);
      return;
    }

    final local = renderBox.globalToLocal(pointer);
    final size = renderBox.size;

    // 좌우 슬랙은 넉넉히 — 사용자가 손가락을 패널 폭 중앙에 정확히 두지 않아도 선택 유지.
    const horizontalSlack = 64.0;
    if (local.dx < -horizontalSlack ||
        local.dx > size.width + horizontalSlack) {
      _setHover(-1);
      return;
    }
    // 위/아래 슬랙은 짧게 — 패널을 한참 벗어나면 선택 취소.
    const verticalSlack = 16.0;
    if (local.dy < -verticalSlack || local.dy > size.height + verticalSlack) {
      _setHover(-1);
      return;
    }

    final perItem = size.height / tabs.length;
    final clampedY = local.dy.clamp(0.0, size.height - 0.001);
    final displayedIdx =
        (clampedY / perItem).floor().clamp(0, tabs.length - 1);
    // 표시 순서는 역순 → 실제 SubTab.index 로 변환
    final realIdx = tabs.length - 1 - displayedIdx;
    _setHover(realIdx);
  }

  void _setHover(int idx) {
    if (idx == _lastReportedHover) return;
    _lastReportedHover = idx;
    widget.onHoveredSubIndexChanged?.call(idx);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = SubTabsCatalog.of(widget.mainTabIndex);
    if (tabs.isEmpty || widget.mode == SubMenuMode.hidden && _ctrl.value == 0) {
      return const SizedBox.shrink();
    }

    // 세로 배치 — 패널 폭은 좁고 길게. 라벨이 잘리지 않을 정도면 충분하다.
    const panelWidth = 120.0;
    const safePadding = 8.0;

    // 4탭 등간격 기준으로 누른 탭 중심에 정렬.
    // 화면 가장자리(특히 커리어 탭)에서는 safePadding 으로 클램프.
    final screenWidth = MediaQuery.of(context).size.width;
    final tabWidth = screenWidth / 4;
    final tabCenterX = tabWidth * (widget.mainTabIndex + 0.5);
    final left = (tabCenterX - panelWidth / 2).clamp(
      safePadding,
      (screenWidth - panelWidth - safePadding).clamp(safePadding, double.infinity),
    );

    // Scaffold body 좌표계에서 bottom: 0 = BottomNavigationBar 의 윗선.
    // 추가 오프셋 없이 그대로 두면 하단 메뉴 바로 위에 패널 바닥이 정확히 붙는다.
    return Positioned(
      left: left,
      bottom: 0,
      width: panelWidth,
      child: IgnorePointer(
        // hint 모드든 interactive 모드든 위젯은 손가락을 받지 않는다.
        // 모든 제스처는 HomeShell 의 GestureDetector 가 처리한다.
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            final fadeV = _fade.value;
            final slideV = _slide.value;
            return Opacity(
              opacity: fadeV,
              child: Transform.translate(
                offset: Offset(0, (1 - slideV) * 16),
                child: child,
              ),
            );
          },
          child: _SubMenuPanel(
            panelKey: _panelKey,
            tabs: tabs,
            hoveredIndex:
                widget.mode == SubMenuMode.interactive
                    ? _lastReportedHover
                    : -1,
            showHoverGuide: widget.mode == SubMenuMode.interactive,
            defaultSelectedIndex: widget.defaultSelectedIndex,
            newIndicesStream: _newIndicesStream,
          ),
        ),
      ),
    );
  }
}

class _SubMenuPanel extends StatelessWidget {
  const _SubMenuPanel({
    required this.panelKey,
    required this.tabs,
    required this.hoveredIndex,
    required this.showHoverGuide,
    required this.defaultSelectedIndex,
    required this.newIndicesStream,
  });

  final GlobalKey panelKey;
  final List<SubTab> tabs;
  final int hoveredIndex;
  final bool showHoverGuide;

  /// "지금 손 떼면 갈 곳" 표시용 인덱스. hover 가 없을 때만 보임 (-1 = 없음).
  final int defaultSelectedIndex;

  /// 상위 State 가 보관해 주는 안정적인 스트림 인스턴스.
  /// setState 반복에도 동일 인스턴스가 들어와 StreamBuilder 재구독이 없음.
  final Stream<Set<int>> newIndicesStream;

  @override
  Widget build(BuildContext context) {
    // 좌측(작은 인덱스) 메뉴일수록 화면 아래쪽에 보이도록 역순 렌더링.
    // 호버 좌표 계산도 동일한 역순 매핑을 사용한다.
    final displayedTabs = tabs.reversed.toList(growable: false);

    return Container(
      key: panelKey,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.creamWhite,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: StreamBuilder<Set<int>>(
        stream: newIndicesStream,
        initialData: const {},
        builder: (context, snapshot) {
          final newIndices = snapshot.data ?? const {};
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final t in displayedTabs)
                () {
                  // 우선순위: hover > selected. hover 가 있으면 selected 표시는 숨김.
                  final isHovered = showHoverGuide && hoveredIndex == t.index;
                  final isSelected =
                      !isHovered && t.index == defaultSelectedIndex;
                  return _SubMenuItem(
                    tab: t,
                    hovered: isHovered,
                    selected: isSelected,
                    showNew: newIndices.contains(t.index),
                  );
                }(),
            ],
          );
        },
      ),
    );
  }
}

class _SubMenuItem extends StatelessWidget {
  const _SubMenuItem({
    required this.tab,
    required this.hovered,
    required this.selected,
    required this.showNew,
  });

  final SubTab tab;

  /// 손가락이 지금 이 항목 위에 있음 — 진한 파랑 필.
  final bool hovered;

  /// "지금 떼면 갈 곳" — 옅은 음영(selected). hover 와 동시에 true 일 일은 없음
  /// (상위 [_SubMenuPanel] 에서 우선순위 처리).
  final bool selected;

  final bool showNew;

  @override
  Widget build(BuildContext context) {
    // 시각 단계:
    //   기본 : 투명 bg / w700 / textPrimary
    //   selected : surfaceMuted bg / w800 / textPrimary  (옅은 음영)
    //   hovered  : cardPrimary bg / w800 / onCardPrimary (진한 파랑)
    final Color bg;
    final Color fg;
    final FontWeight weight;
    if (hovered) {
      bg = AppColors.cardPrimary;
      fg = AppColors.onCardPrimary;
      weight = FontWeight.w800;
    } else if (selected) {
      bg = AppColors.surfaceMuted;
      fg = AppColors.textPrimary;
      weight = FontWeight.w800;
    } else {
      bg = Colors.transparent;
      fg = AppColors.textPrimary;
      weight = FontWeight.w700;
    }

    return AnimatedScale(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      // 세로 배치에서는 위/아래 아이템이 흔들려 보일 수 있어 호버 확대 비율을 살짝 줄임.
      // selected 상태는 크기 변화 없이 음영만 줘서 시각 잡음을 최소화한다.
      scale: hovered ? 1.03 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        // 텍스트는 항상 가운데 정렬. NEW 뱃지는 우상단 코너에 절대 위치로 띄움.
        // (Row 안에 같이 두면 뱃지 폭만큼 텍스트가 좌측으로 밀려 가운데 정렬이 깨짐)
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: weight,
                color: fg,
                letterSpacing: -0.1,
              ),
            ),
            if (showNew)
              const Positioned(
                top: -10,
                right: -6,
                child: _SubMenuNewBadge(),
              ),
          ],
        ),
      ),
    );
  }
}

class _SubMenuNewBadge extends StatefulWidget {
  const _SubMenuNewBadge();

  @override
  State<_SubMenuNewBadge> createState() => _SubMenuNewBadgeState();
}

class _SubMenuNewBadgeState extends State<_SubMenuNewBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD84D),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: const Text(
          'NEW',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: AppColors.blue,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
