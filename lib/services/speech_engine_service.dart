import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 상태 카테고리
enum SpeechCategory {
  tired,        // A. 새벽/피곤
  stressed,     // B. 스트레스/힘듦
  motivated,    // C. 의욕/좋은 흐름
  returning,    // D. 오랜만 복귀
  studying,     // E. 학습 많이 함
  neutral,      // F. 기본 멘트
}

/// 유저 상태 기반 멘트 선택 엔진
/// 
/// 디자인 큐:
/// - 유저 상태를 분석하여 적절한 카테고리 선택
/// - 우선순위: 시간대 → 복귀 → 감정 기록 → 학습 활동 → 기본
/// - 같은 멘트 반복 방지 (향후 lastSpeechId 저장)
class SpeechEngineService {
  static final _db = FirebaseFirestore.instance;

  /// 카테고리별 멘트 풀 (테스트용 20개)
  static final Map<SpeechCategory, List<String>> _speechPool = {
    SpeechCategory.tired: [
      "오늘 표정이 조금 무거워 보여… 숨 한 번만 같이 쉬자.",
      "어제 잠을 설쳤지? 그럴 땐 오늘은 '버티는 것'만으로도 충분해.",
      "지금 마음이 조용히 지쳐있는 느낌이야. 내가 옆에 있을게.",
      "아침 공기 차가웠지? 너도 마음이 살짝 얼었을까 봐 걱정돼.",
    ],
    SpeechCategory.stressed: [
      "오늘은 속도를 늦춰도 돼. 계속 달리는 사람만 강한 게 아니거든.",
      "오늘은 잘해야 한다는 생각이 너를 누르는 날이구나.",
      "괜찮아. 오늘의 목표는 '무너지지 않기'로 하자.",
      "지금 힘든 이유가 너의 탓은 아니야. 상황이 좀 거칠었을 뿐.",
      "오늘은 마음이 예민한 날이지? 그럼 자극 적은 하루로 가자.",
    ],
    SpeechCategory.motivated: [
      "기분이 살짝 올라온다! 그 흐름, 내가 더 크게 만들어줄까?",
      "오늘 공부한 흔적이 보이는 것 같아. 작은 성장이 쌓이고 있어.",
      "너, 생각보다 많이 버텼어. 그거 진짜 대단한 거야.",
    ],
    SpeechCategory.returning: [
      "오랜만이다… 돌아와줘서 고마워. 여기 그대로 있었어.",
    ],
    SpeechCategory.studying: [
      "너 요즘 많이 애썼지. '수고했다'는 말, 꼭 해주고 싶었어.",
      "오늘은 스스로를 다그치지 말자. 넌 이미 충분히 성실해.",
    ],
    SpeechCategory.neutral: [
      "오늘은 작은 칭찬이 필요한 날 같아. 내가 해줄게: 잘하고 있어.",
      "지금은 멈춰도 돼. 멈추는 건 포기가 아니라 정비야.",
      "오늘 하루, 꼭 멋지지 않아도 돼. 무사히 지나가면 돼.",
      "괜히 마음이 허전한 날 있지… 그럴 땐 따뜻한 것부터 찾자.",
      "너랑 이야기하면, 나도 안심돼. 우리 같이 천천히 가자.",
    ],
  };

  /// 유저 상태 분석 → 멘트 선택
  static Future<String> pickSpeechForUser() async {
    final category = await _analyzeUserState();
    return _getRandomSpeech(category);
  }

  /// 유저 상태 분석 (우선순위 순서대로)
  static Future<SpeechCategory> _analyzeUserState() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return SpeechCategory.neutral;

    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      if (!userDoc.exists) return SpeechCategory.neutral;

      final data = userDoc.data()!;
      final now = DateTime.now();
      
      // 1. 시간대 체크 (새벽이면 피곤)
      if (now.hour >= 0 && now.hour < 6) {
        return SpeechCategory.tired;
      }

      // 2. 오랜만 복귀 체크 (마지막 활동 7일 이상)
      if (data['lastActiveAt'] != null) {
        try {
          final lastActive = (data['lastActiveAt'] as Timestamp).toDate();
          if (now.difference(lastActive).inDays >= 7) {
            return SpeechCategory.returning;
          }
        } catch (e) {
          // lastActiveAt 파싱 실패 시 무시
        }
      }

      // 3. 오늘 감정 기록 체크 (향후 구현)
      // final emotionToday = await _checkEmotionToday(uid, now);
      // if (emotionToday != null && emotionToday <= 2) {
      //   return SpeechCategory.stressed;
      // }

      // 4. 최근 학습 활동 체크 (향후 구현)
      // final studyMinutes = await _checkRecentStudy(uid);
      // if (studyMinutes > 60) {
      //   return SpeechCategory.studying;
      // }

      // 기본
      return SpeechCategory.neutral;
    } catch (e) {
      // 오류 시 기본 멘트
      return SpeechCategory.neutral;
    }
  }

  /// 카테고리에서 랜덤 멘트 선택
  static String _getRandomSpeech(SpeechCategory category) {
    final pool = _speechPool[category] ?? _speechPool[SpeechCategory.neutral]!;
    return pool[Random().nextInt(pool.length)];
  }

  // 향후 구현 예정: 감정 체크
  // static Future<int?> _checkEmotionToday(String uid, DateTime today) async {
  //   final snapshot = await _db
  //       .collection('users')
  //       .doc(uid)
  //       .collection('emotionLogs')
  //       .where('date', isGreaterThanOrEqualTo: DateTime(today.year, today.month, today.day))
  //       .limit(1)
  //       .get();
  //   
  //   if (snapshot.docs.isEmpty) return null;
  //   return snapshot.docs.first.data()['score'] as int?;
  // }

  // 향후 구현 예정: 학습 시간 체크
  // static Future<int> _checkRecentStudy(String uid) async {
  //   final weekAgo = DateTime.now().subtract(const Duration(days: 7));
  //   final snapshot = await _db
  //       .collection('users')
  //       .doc(uid)
  //       .collection('growthEvents')
  //       .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
  //       .get();
  //   
  //   int totalMinutes = 0;
  //   for (var doc in snapshot.docs) {
  //     totalMinutes += (doc.data()['durationMinutes'] as int?) ?? 0;
  //   }
  //   return totalMinutes;
  // }
}

