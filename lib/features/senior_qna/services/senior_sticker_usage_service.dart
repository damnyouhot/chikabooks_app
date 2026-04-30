import 'package:shared_preferences/shared_preferences.dart';

class SeniorStickerUsageService {
  static const _recentStickerIdsKey = 'senior_recent_sticker_ids';
  static const _maxRecentStickers = 24;

  static Future<List<String>> loadRecentStickerIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentStickerIdsKey) ?? const [];
  }

  static Future<void> recordSticker(String stickerId) async {
    final trimmedId = stickerId.trim();
    if (trimmedId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_recentStickerIdsKey) ?? const [];
    final nextIds = <String>[
      trimmedId,
      ...ids.where((id) => id != trimmedId),
    ].take(_maxRecentStickers).toList(growable: false);

    await prefs.setStringList(_recentStickerIdsKey, nextIds);
  }
}
