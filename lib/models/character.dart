import 'package:cloud_firestore/cloud_firestore.dart';

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
  List<String> inventory;
  String? equippedItemId;
  // 새로 추가된 필드들
  double hunger; // 배고픔 지수 (0.0 ~ 1.0, 1.0이 배부름)
  double fatigue; // 피로도 (0.0 ~ 1.0, 0.0이 피곤하지 않음)
  List<String> foodInventory; // 보유 음식 ID 목록

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
    this.hunger = 0.5, // 기본값: 중간
    this.fatigue = 0.0, // 기본값: 피곤하지 않음
    this.foodInventory = const [],
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
      hunger: (data['hunger'] ?? 0.5).toDouble(),
      fatigue: (data['fatigue'] ?? 0.0).toDouble(),
      foodInventory: List<String>.from(data['foodInventory'] ?? []),
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
    'hunger': hunger,
    'fatigue': fatigue,
    'foodInventory': foodInventory,
  };

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
