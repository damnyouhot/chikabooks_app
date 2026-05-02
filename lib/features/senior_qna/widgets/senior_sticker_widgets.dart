import 'package:animated_emoji/animated_emoji.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../data/senior_stickers.dart';
import '../services/senior_sticker_usage_service.dart';

class SeniorStickerView extends StatelessWidget {
  final String stickerId;
  final double size;

  const SeniorStickerView({super.key, required this.stickerId, this.size = 30});

  @override
  Widget build(BuildContext context) {
    final sticker = seniorStickerById(stickerId);
    if (sticker == null) return const SizedBox.shrink();
    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: Center(child: _StickerArt(sticker: sticker, size: size)),
    );
  }
}

class SeniorStickerStrip extends StatelessWidget {
  final List<String> stickerIds;
  final double size;

  const SeniorStickerStrip({
    super.key,
    required this.stickerIds,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    final validIds =
        stickerIds.where((id) => seniorStickerById(id) != null).toList();
    if (validIds.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children:
          validIds
              .map((id) => SeniorStickerView(stickerId: id, size: size))
              .toList(),
    );
  }
}

class SeniorStickerChip extends StatelessWidget {
  final String stickerId;
  final VoidCallback? onRemove;

  const SeniorStickerChip({
    super.key,
    required this.stickerId,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final sticker = seniorStickerById(stickerId);
    if (sticker == null) return const SizedBox.shrink();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SeniorStickerView(stickerId: sticker.id, size: 24),
        if (onRemove != null)
          Positioned(
            top: -2,
            right: -2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 10),
              ),
            ),
          ),
      ],
    );
  }
}

class SeniorStickerChipList extends StatelessWidget {
  final List<String> stickerIds;
  final ValueChanged<int>? onRemoveAt;

  const SeniorStickerChipList({
    super.key,
    required this.stickerIds,
    required this.onRemoveAt,
  });

  @override
  Widget build(BuildContext context) {
    if (stickerIds.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (var i = 0; i < stickerIds.length; i++)
            SeniorStickerChip(
              stickerId: stickerIds[i],
              onRemove: onRemoveAt == null ? null : () => onRemoveAt!(i),
            ),
        ],
      ),
    );
  }
}

Future<String?> showSeniorStickerPicker(
  BuildContext context, {
  String? selectedId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) => _SeniorStickerPickerSheet(selectedId: selectedId),
  );
}

class _SeniorStickerPickerSheet extends StatefulWidget {
  final String? selectedId;

  const _SeniorStickerPickerSheet({required this.selectedId});

  @override
  State<_SeniorStickerPickerSheet> createState() =>
      _SeniorStickerPickerSheetState();
}

class _SeniorStickerPickerSheetState extends State<_SeniorStickerPickerSheet> {
  late final Future<List<String>> _recentStickerIdsFuture =
      SeniorStickerUsageService.loadRecentStickerIds();

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.7;
    return FutureBuilder<List<String>>(
      future: _recentStickerIdsFuture,
      builder: (context, snapshot) {
        final recentStickers = (snapshot.data ?? const <String>[])
            .map(seniorStickerById)
            .whereType<SeniorSticker>()
            .toList(growable: false);
        final tabLabels = <String>[
          '최근',
          ...seniorStickerPickerGroups.map((group) => group.label),
        ];
        final stickerGroups = <List<SeniorSticker>>[
          recentStickers,
          ...seniorStickerPickerGroups.map(seniorStickersForPickerGroup),
        ];

        return SafeArea(
          top: false,
          child: SizedBox(
            height: height,
            child: DefaultTabController(
              length: tabLabels.length,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '움직이는 스티커',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: AppColors.cardEmphasis,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.cardEmphasis,
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                      tabs: tabLabels.map((label) => Tab(text: label)).toList(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: TabBarView(
                        children:
                            stickerGroups
                                .asMap()
                                .entries
                                .map(
                                  (entry) => _StickerGrid(
                                    stickers: entry.value,
                                    selectedId: widget.selectedId,
                                    emptyMessage:
                                        entry.key == 0
                                            ? '아직 사용한 스티커가 없어요.'
                                            : null,
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      '사용한 스티커와 상업 이용 가능한 외부/앱 내 스티커를 반복 재생해요.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StickerGrid extends StatelessWidget {
  final List<SeniorSticker> stickers;
  final String? selectedId;
  final String? emptyMessage;

  const _StickerGrid({
    required this.stickers,
    required this.selectedId,
    this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    final sortedStickers = [...stickers];
    if (selectedId != null) {
      sortedStickers.sort((a, b) {
        if (a.id == selectedId) return -1;
        if (b.id == selectedId) return 1;
        return 0;
      });
    }

    if (sortedStickers.isEmpty) {
      return Center(
        child: Text(
          emptyMessage ?? '표시할 스티커가 없어요.',
          style: const TextStyle(fontSize: 13, color: AppColors.textDisabled),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      itemCount: sortedStickers.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: AppSpacing.xs,
        crossAxisSpacing: AppSpacing.xs,
        childAspectRatio: 1,
      ),
      itemBuilder: (_, i) {
        final sticker = sortedStickers[i];
        final selected = sticker.id == selectedId;
        return InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () async {
            await SeniorStickerUsageService.recordSticker(sticker.id);
            if (context.mounted) Navigator.pop(context, sticker.id);
          },
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color:
                  selected
                      ? AppColors.cardEmphasis.withValues(alpha: 0.12)
                      : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color:
                    selected
                        ? AppColors.cardEmphasis
                        : AppColors.divider.withValues(alpha: 0.35),
              ),
            ),
            child: Center(child: _StickerArt(sticker: sticker, size: 24)),
          ),
        );
      },
    );
  }
}

class _StickerArt extends StatelessWidget {
  final SeniorSticker sticker;
  final double size;

  const _StickerArt({required this.sticker, required this.size});

  @override
  Widget build(BuildContext context) {
    switch (sticker.source) {
      case SeniorStickerSource.notoAnimatedEmoji:
        final emoji = sticker.emoji;
        if (emoji == null) {
          return _FallbackSticker(label: sticker.label, size: size);
        }
        return AnimatedEmoji(
          emoji,
          size: size,
          repeat: true,
          animate: true,
          source: AnimatedEmojiSource.asset,
          errorWidget: Text(
            emoji.toUnicodeEmoji(),
            style: TextStyle(fontSize: size * 0.62),
          ),
        );
      case SeniorStickerSource.assetSvg:
        final assetPath = sticker.assetPath;
        if (assetPath == null) {
          return _FallbackSticker(label: sticker.label, size: size);
        }
        return _AnimatedSvgSticker(assetPath: assetPath, size: size);
    }
  }
}

class _AnimatedSvgSticker extends StatefulWidget {
  final String assetPath;
  final double size;

  const _AnimatedSvgSticker({required this.assetPath, required this.size});

  @override
  State<_AnimatedSvgSticker> createState() => _AnimatedSvgStickerState();
}

class _AnimatedSvgStickerState extends State<_AnimatedSvgSticker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _turns;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.96,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _turns = Tween<double>(
      begin: -0.015,
      end: 0.015,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: RotationTransition(
        turns: _turns,
        child: SvgPicture.asset(
          widget.assetPath,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _FallbackSticker extends StatelessWidget {
  final String label;
  final double size;

  const _FallbackSticker({required this.label, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          label.characters.take(2).toString(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: size * 0.24,
            fontWeight: FontWeight.w900,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
