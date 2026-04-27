import 'package:cloud_firestore/cloud_firestore.dart';

enum DailyWordStatus {
  known('known'),
  reviewLater('reviewLater');

  const DailyWordStatus(this.value);

  final String value;

  static DailyWordStatus? fromValue(String? value) {
    return switch (value) {
      'known' => DailyWordStatus.known,
      'reviewLater' => DailyWordStatus.reviewLater,
      _ => null,
    };
  }
}

class DailyWord {
  const DailyWord({
    required this.id,
    required this.order,
    required this.english,
    required this.pronunciationKo,
    required this.meaning,
    required this.category,
    required this.sourceFileName,
    required this.sourceBatchId,
    required this.isActive,
  });

  final String id;
  final int order;
  final String english;
  final String pronunciationKo;
  final String meaning;
  final String category;
  final String sourceFileName;
  final String sourceBatchId;
  final bool isActive;

  factory DailyWord.fromMap(Map<String, dynamic> map) {
    return DailyWord(
      id: map['id'] as String? ?? '',
      order: (map['order'] as num?)?.toInt() ?? 0,
      english: map['english'] as String? ?? '',
      pronunciationKo: map['pronunciationKo'] as String? ?? '',
      meaning: map['meaning'] as String? ?? '',
      category: map['category'] as String? ?? '기타',
      sourceFileName: map['sourceFileName'] as String? ?? '',
      sourceBatchId: map['sourceBatchId'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toSnapshotMap() {
    return {
      'id': id,
      'order': order,
      'english': english,
      'pronunciationKo': pronunciationKo,
      'meaning': meaning,
      'category': category,
      'sourceFileName': sourceFileName,
      'sourceBatchId': sourceBatchId,
      'isActive': isActive,
    };
  }
}

class DailyWordDeck {
  const DailyWordDeck({
    required this.dateKey,
    required this.words,
    required this.actions,
    required this.savedWordIds,
    required this.knownCount,
    required this.reviewLaterCount,
    required this.savedCount,
    required this.totalActiveCount,
  });

  final String dateKey;
  final List<DailyWord> words;
  final Map<String, DailyWordStatus> actions;
  final Set<String> savedWordIds;
  final int knownCount;
  final int reviewLaterCount;
  final int savedCount;
  final int totalActiveCount;

  int get completedTodayCount {
    return words.where((word) => actions.containsKey(word.id)).length;
  }
}

class SavedDailyWord {
  const SavedDailyWord({required this.word, required this.savedAt});

  final DailyWord word;
  final DateTime? savedAt;

  factory SavedDailyWord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SavedDailyWord(
      word: DailyWord.fromMap({...data, 'id': data['id'] as String? ?? doc.id}),
      savedAt: (data['savedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class DailyWordOpsSummary {
  const DailyWordOpsSummary({
    required this.totalActiveCount,
    required this.skippedCount,
    required this.remainingCount,
    required this.currentWords,
    required this.skippedWordIds,
    required this.updatedAt,
  });

  final int totalActiveCount;
  final int skippedCount;
  final int remainingCount;
  final List<DailyWord> currentWords;
  final Set<String> skippedWordIds;
  final DateTime? updatedAt;
}
