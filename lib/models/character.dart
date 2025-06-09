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
