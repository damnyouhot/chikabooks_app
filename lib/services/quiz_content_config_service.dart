import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/quiz_content_config.dart';

/// 퀴즈 콘텐츠 설정·패크 메타 읽기
class QuizContentConfigService {
  static final _db = FirebaseFirestore.instance;

  static const _configPath = 'config/quiz_content';

  static Future<QuizContentConfig> getConfig() async {
    try {
      final doc = await _db.doc(_configPath).get();
      if (!doc.exists) return QuizContentConfig.defaultLegacy();
      return QuizContentConfig.fromFirestore(doc);
    } catch (e) {
      debugPrint('⚠️ QuizContentConfigService.getConfig: $e');
      return QuizContentConfig.defaultLegacy();
    }
  }

  static Stream<QuizContentConfig> watchConfig() {
    return _db.doc(_configPath).snapshots().map((doc) {
      if (!doc.exists) return QuizContentConfig.defaultLegacy();
      return QuizContentConfig.fromFirestore(doc);
    });
  }

  static Future<QuizPackMeta?> getPackMeta(String packId) async {
    if (packId.isEmpty) return null;
    try {
      final doc = await _db.collection('quiz_packs').doc(packId).get();
      if (!doc.exists) return null;
      return QuizPackMeta.fromFirestore(doc);
    } catch (e) {
      debugPrint('⚠️ QuizContentConfigService.getPackMeta: $e');
      return null;
    }
  }
}
