import 'package:animated_emoji/animated_emoji.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../data/senior_stickers.dart';

class SeniorStickerView extends StatelessWidget {
  final String stickerId;
  final double size;

  const SeniorStickerView({super.key, required this.stickerId, this.size = 67});

  @override
  Widget build(BuildContext context) {
    final sticker = seniorStickerById(stickerId);
    if (sticker == null) return const SizedBox.shrink();
    return Container(
      width: size + 20,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StickerArt(sticker: sticker, size: size),
          const SizedBox(height: 4),
          Text(
            sticker.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Stack(
        children: [
          SeniorStickerView(stickerId: sticker.id, size: 50),
          if (onRemove != null)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 13),
                ),
              ),
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

class _SeniorStickerPickerSheet extends StatelessWidget {
  final String? selectedId;

  const _SeniorStickerPickerSheet({required this.selectedId});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.7;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: height,
        child: DefaultTabController(
          length: seniorStickerPickerCategories.length,
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
                  tabs:
                      seniorStickerPickerCategories
                          .map((category) => Tab(text: category.label))
                          .toList(),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: TabBarView(
                    children:
                        seniorStickerPickerCategories
                            .map(
                              (category) => _StickerGrid(
                                stickers: seniorStickersForCategory(category),
                                selectedId: selectedId,
                              ),
                            )
                            .toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Noto Animated Emoji와 ChikaBooks 자체 제작 스티커를 앱 내에서 반복 재생해요.',
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
  }
}

class _StickerGrid extends StatelessWidget {
  final List<SeniorSticker> stickers;
  final String? selectedId;

  const _StickerGrid({required this.stickers, required this.selectedId});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      itemCount: stickers.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.02,
      ),
      itemBuilder: (_, i) {
        final sticker = stickers[i];
        final selected = sticker.id == selectedId;
        return InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => Navigator.pop(context, sticker.id),
          child: Container(
            padding: const EdgeInsets.all(5),
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StickerArt(sticker: sticker, size: 36),
                const SizedBox(height: 3),
                Text(
                  sticker.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
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
