import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/daily_word.dart';

class DailyWordService {
  DailyWordService._();

  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static const int dailyCount = 3;
  static const String _assetPath = 'assets/data/daily_words.json';
  static const String _dailyWordsCollection = 'daily_words';
  static const String _progressCollection = 'word_progress';
  static const String _savedWordsCollection = 'saved_words';
  static const String _metaPath = 'daily_word_meta/state';
  static const String _turnsCollection = 'daily_word_turns';
  static const String _selectionVersion = 'stable_random_v1';

  static Future<List<DailyWord>>? _assetWordsFuture;

  static String? get _uid => _auth.currentUser?.uid;

  static String _dateKey(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  static DateTime get _todayKst =>
      DateTime.now().toUtc().add(const Duration(hours: 9));

  static String get todayKey => _dateKey(_todayKst);

  static DocumentReference<Map<String, dynamic>>? get _userRef {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  static int _stableSeed(String input) {
    var hash = 0x811c9dc5;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  static Future<List<DailyWord>> loadWordPool() {
    return _assetWordsFuture ??= _loadWordPoolFromAsset();
  }

  static Future<List<DailyWord>> _loadWordPoolFromAsset() async {
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final rawWords = decoded['words'] as List<dynamic>? ?? [];
      final words =
          rawWords
              .map(
                (e) => DailyWord.fromMap(Map<String, dynamic>.from(e as Map)),
              )
              .where((word) => word.id.isNotEmpty && word.english.isNotEmpty)
              .toList()
            ..sort((a, b) => a.order.compareTo(b.order));
      return words;
    } catch (e) {
      debugPrint('⚠️ DailyWordService._loadWordPoolFromAsset: $e');
      return const [];
    }
  }

  static Future<DailyWordDeck> loadTodayDeck() async {
    final dateKey = todayKey;
    final allWords = await loadWordPool();
    final globallySkippedIds = await _loadGloballySkippedWordIds();
    final activeWords =
        allWords
            .where(
              (word) => word.isActive && !globallySkippedIds.contains(word.id),
            )
            .toList();
    final wordById = {for (final word in activeWords) word.id: word};
    final userRef = _userRef;

    if (userRef == null) {
      final words = _pickWordsForToday(
        activeWords,
        const {},
        seedScope: 'anonymous',
      );
      return DailyWordDeck(
        dateKey: dateKey,
        words: words,
        actions: const {},
        savedWordIds: const {},
        knownCount: 0,
        reviewLaterCount: 0,
        savedCount: 0,
        totalActiveCount: activeWords.length,
      );
    }

    try {
      final progressSnap = await userRef.collection(_progressCollection).get();
      final progress = <String, DailyWordStatus>{};
      for (final doc in progressSnap.docs) {
        final status = DailyWordStatus.fromValue(
          doc.data()['status'] as String?,
        );
        if (status != null) progress[doc.id] = status;
      }

      final savedSnap = await userRef.collection(_savedWordsCollection).get();
      final savedIds = savedSnap.docs.map((doc) => doc.id).toSet();
      final dailyRef = userRef.collection(_dailyWordsCollection).doc(dateKey);
      final dailyDoc = await dailyRef.get();

      List<String> wordIds = [];
      var selectionVersion = '';
      if (dailyDoc.exists) {
        final data = dailyDoc.data() ?? {};
        wordIds = List<String>.from(data['wordIds'] as List? ?? []);
        selectionVersion = data['selectionVersion'] as String? ?? '';
      }

      var todayWords = wordIds
          .map((id) => wordById[id])
          .whereType<DailyWord>()
          .toList(growable: false);

      final hasGloballySkippedTodayWords = wordIds.any(
        (id) => globallySkippedIds.contains(id),
      );
      if (todayWords.length != wordIds.length ||
          todayWords.isEmpty ||
          hasGloballySkippedTodayWords ||
          selectionVersion != _selectionVersion) {
        todayWords = _pickWordsForToday(
          activeWords,
          progress,
          seedScope: userRef.id,
        );
        await dailyRef.set({
          'dateKey': dateKey,
          'wordIds': todayWords.map((word) => word.id).toList(),
          'startOrder': todayWords.isEmpty ? 0 : todayWords.first.order,
          'endOrder': todayWords.isEmpty ? 0 : todayWords.last.order,
          'poolSize': activeWords.length,
          'selectionVersion': _selectionVersion,
          'selectionMode': 'stableRandom',
          'generatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      final knownCount =
          progress.values
              .where((status) => status == DailyWordStatus.known)
              .length;
      final reviewLaterCount =
          progress.values
              .where((status) => status == DailyWordStatus.reviewLater)
              .length;

      return DailyWordDeck(
        dateKey: dateKey,
        words: todayWords,
        actions: progress,
        savedWordIds: savedIds,
        knownCount: knownCount,
        reviewLaterCount: reviewLaterCount,
        savedCount: savedIds.length,
        totalActiveCount: activeWords.length,
      );
    } catch (e) {
      debugPrint('⚠️ DailyWordService.loadTodayDeck: $e');
      final fallbackWords = _pickWordsForToday(
        activeWords,
        const {},
        seedScope: userRef.id,
      );
      return DailyWordDeck(
        dateKey: dateKey,
        words: fallbackWords,
        actions: const {},
        savedWordIds: const {},
        knownCount: 0,
        reviewLaterCount: 0,
        savedCount: 0,
        totalActiveCount: activeWords.length,
      );
    }
  }

  static List<DailyWord> _pickWordsForToday(
    List<DailyWord> activeWords,
    Map<String, DailyWordStatus> progress, {
    String seedScope = 'global',
  }) {
    final candidates =
        activeWords
            .where((word) => progress[word.id] != DailyWordStatus.known)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    if (candidates.isEmpty) return const [];

    final seed = _stableSeed('$todayKey|$seedScope|${candidates.length}');
    candidates.shuffle(Random(seed));
    return candidates.take(dailyCount).toList(growable: false);
  }

  static Future<Set<String>> _loadGloballySkippedWordIds() async {
    try {
      final doc = await _db.doc(_metaPath).get();
      final data = doc.data();
      if (data == null) return const {};
      return List<String>.from(data['skippedWordIds'] as List? ?? []).toSet();
    } catch (e) {
      debugPrint('⚠️ DailyWordService._loadGloballySkippedWordIds: $e');
      return const {};
    }
  }

  static Future<DailyWordOpsSummary> loadOpsSummary() async {
    final allWords = await loadWordPool();
    final activeWords = allWords.where((word) => word.isActive).toList();
    final wordById = {for (final word in activeWords) word.id: word};

    try {
      final doc = await _db.doc(_metaPath).get();
      final data = doc.data() ?? {};
      final skippedIds =
          List<String>.from(
            data['skippedWordIds'] as List? ?? [],
          ).where(wordById.containsKey).toSet();
      final availableWords = activeWords
          .where((word) => !skippedIds.contains(word.id))
          .toList(growable: false);
      final currentWords = _pickWordsForToday(availableWords, const {});
      final consumedIds = {
        ...skippedIds,
        ...currentWords.map((word) => word.id),
      };
      final remainingCount = activeWords.length - consumedIds.length;

      return DailyWordOpsSummary(
        totalActiveCount: activeWords.length,
        skippedCount: consumedIds.length,
        remainingCount:
            remainingCount < 0
                ? 0
                : remainingCount > activeWords.length
                ? activeWords.length
                : remainingCount,
        currentWords: currentWords,
        skippedWordIds: skippedIds,
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      );
    } catch (e) {
      debugPrint('⚠️ DailyWordService.loadOpsSummary: $e');
      final currentWords = _pickWordsForToday(activeWords, const {});
      final consumedCount = currentWords.map((word) => word.id).toSet().length;
      final remainingCount = activeWords.length - consumedCount;
      return DailyWordOpsSummary(
        totalActiveCount: activeWords.length,
        skippedCount: consumedCount,
        remainingCount:
            remainingCount < 0
                ? 0
                : remainingCount > activeWords.length
                ? activeWords.length
                : remainingCount,
        currentWords: currentWords,
        skippedWordIds: const {},
        updatedAt: null,
      );
    }
  }

  static Future<DailyWordOpsSummary> skipCurrentTurn() async {
    final summary = await loadOpsSummary();
    final currentIds = summary.currentWords.map((word) => word.id).toList();
    if (currentIds.isEmpty) return summary;

    final metaRef = _db.doc(_metaPath);
    await metaRef.set({
      'skippedWordIds': FieldValue.arrayUnion(currentIds),
      'lastSkippedWordIds': currentIds,
      'lastSkippedWords': summary.currentWords
          .map((word) => word.toSnapshotMap())
          .toList(growable: false),
      'lastSkippedDateKey': todayKey,
      'lastSkippedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // If a global turn document is introduced later, this keeps the admin action
    // idempotent and ensures the current turn is not reused.
    await _db.collection(_turnsCollection).doc(todayKey).delete().catchError((
      Object e,
    ) {
      debugPrint('⚠️ DailyWordService.skipCurrentTurn delete turn: $e');
    });
    await _deleteTodayUserDecksContaining(currentIds).catchError((Object e) {
      debugPrint('⚠️ DailyWordService.skipCurrentTurn delete user decks: $e');
    });

    return loadOpsSummary();
  }

  static Future<void> _deleteTodayUserDecksContaining(
    List<String> wordIds,
  ) async {
    if (wordIds.isEmpty) return;

    final snap =
        await _db
            .collectionGroup(_dailyWordsCollection)
            .where('dateKey', isEqualTo: todayKey)
            .get();
    final docsToDelete = snap.docs
        .where((doc) {
          final ids = List<String>.from(doc.data()['wordIds'] as List? ?? []);
          return ids.any(wordIds.contains);
        })
        .toList(growable: false);

    for (var i = 0; i < docsToDelete.length; i += 450) {
      final batch = _db.batch();
      for (final doc in docsToDelete.skip(i).take(450)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  static Future<void> setWordStatus({
    required DailyWord word,
    required DailyWordStatus? status,
  }) async {
    final userRef = _userRef;
    if (userRef == null) return;

    final ref = userRef.collection(_progressCollection).doc(word.id);
    if (status == null) {
      await ref.delete();
      return;
    }

    await ref.set({
      ...word.toSnapshotMap(),
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
      'knownAt':
          status == DailyWordStatus.known
              ? FieldValue.serverTimestamp()
              : FieldValue.delete(),
      'reviewLaterAt':
          status == DailyWordStatus.reviewLater
              ? FieldValue.serverTimestamp()
              : FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  static Future<void> setSavedWord({
    required DailyWord word,
    required bool isSaved,
  }) async {
    final userRef = _userRef;
    if (userRef == null) return;

    final ref = userRef.collection(_savedWordsCollection).doc(word.id);
    if (!isSaved) {
      await ref.delete();
      return;
    }

    await ref.set({
      ...word.toSnapshotMap(),
      'savedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Stream<List<SavedDailyWord>> watchSavedWords() {
    final userRef = _userRef;
    if (userRef == null) return Stream.value(const []);

    return userRef
        .collection(_savedWordsCollection)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
          final pool = await loadWordPool();
          final wordById = {for (final word in pool) word.id: word};
          return snap.docs
              .map((doc) {
                final data = doc.data();
                final assetWord = wordById[doc.id];
                final merged = <String, dynamic>{};
                if (assetWord != null) merged.addAll(assetWord.toSnapshotMap());
                merged.addAll(data);
                merged['id'] = data['id'] as String? ?? doc.id;
                if ((merged['category'] as String? ?? '').trim().isEmpty &&
                    assetWord != null) {
                  merged['category'] = assetWord.category;
                }
                return SavedDailyWord(
                  word: DailyWord.fromMap(merged),
                  savedAt: (data['savedAt'] as Timestamp?)?.toDate(),
                );
              })
              .toList(growable: false);
        });
  }

  static Future<void> resetAllUserRecords() async {
    final userRef = _userRef;
    if (userRef == null) return;

    await _deleteCollectionInChunks(userRef.collection(_progressCollection));
    await _deleteCollectionInChunks(userRef.collection(_savedWordsCollection));
    await _deleteCollectionInChunks(userRef.collection(_dailyWordsCollection));
  }

  static Future<void> _deleteCollectionInChunks(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final snap = await collection.limit(300).get();
      if (snap.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
