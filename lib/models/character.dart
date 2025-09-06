// lib/models/character.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore 'users/{uid}' 문서에 저장되는 캐릭터 상태 모델
class Character {
  String id;
  int level;
  double experience;
  int studyMinutes;
  int stepCount;
  double sleepHours;
  int quizCount;
  double affection;
  int emotionPoints;
  int tenureYears;
  List<String> inventory; // 구매한 아이템 ID 목록
  String? equippedItemId; // 착용 중인 아이템 ID

  Character({
    required this.id,
    this.level = 1,
    this.experience = 0.0,
    this.studyMinutes = 0,
    this.stepCount = 0,
    this.sleepHours = 0.0,
    this.quizCount = 0,
    this.affection = 0.0,
    this.emotionPoints = 0,
    this.tenureYears = 0,
    this.inventory = const [],
    this.equippedItemId,
  });

  factory Character.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Character(
      id: doc.id,
      level: data['level'] ?? 1,
      experience: (data['experience'] ?? 0).toDouble(),
      studyMinutes: data['studyMinutes'] ?? 0,
      stepCount: data['stepCount'] ?? 0,
      sleepHours: (data['sleepHours'] ?? 0).toDouble(),
      quizCount: data['quizCount'] ?? 0,
      affection: (data['affection'] ?? 0).toDouble(),
      emotionPoints: data['emotionPoints'] ?? 0,
      tenureYears: data['tenureYears'] ?? 0,
      inventory: List<String>.from(data['inventory'] ?? []),
      equippedItemId: data['equippedItemId'],
    );
  }

  Map<String, dynamic> toJson() => {
    'level': level,
    'experience': experience,
    'studyMinutes': studyMinutes,
    'stepCount': stepCount,
    'sleepHours': sleepHours,
    'quizCount': quizCount,
    'affection': affection,
    'emotionPoints': emotionPoints,
    'tenureYears': tenureYears,
    'inventory': inventory,
    'equippedItemId': equippedItemId,
  };

  /// 경험치를 획득하고 레벨업이 가능하면 자동으로 처리합니다.
  void gainExperience(double amount) {
    experience += amount;
    double needed = level * level * 100;
    while (experience >= needed) {
      experience -= needed;
      level += 1;
      needed = level * level * 100;
    }
  }
}
