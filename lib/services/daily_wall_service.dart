import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/daily_wall_post.dart';
import 'user_profile_service.dart';
import 'weekly_stamp_service.dart';

/// "오늘의 한 문장" Firestore 서비스
class DailyWallService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static final _rng = Random();

  static CollectionReference<Map<String, dynamic>> get _postsRef =>
      _db.collection('dailyWallPosts');

  // ───────────────────────── 조합 선택지 ─────────────────────────

  /// Step 1: 상황 태그
  static const List<String> situationTags = [
    '환자응대',
    '동료',
    '원장·상사',
    '업무량',
    '실수',
    '배움',
    '체력',
    '이직·커리어',
    '기타',
  ];

  /// Step 2: 감정 톤 이모지
  static const List<String> toneEmojis = [
    '😮‍💨',
    '🫧',
    '🌙',
    '🔥',
    '💛',
    '🧊',
  ];

  /// Step 3: 마침 문구 (key → 표시 텍스트)
  static const Map<String, String> endings = {
    'short_breath': '숨이 짧았어.',
    'words_left': '말이 남았어.',
    'hands_first': '손이 먼저 움직였어.',
    'high_bar': '기준이 높았어.',
    'passed_quietly': '조용히 넘겼어.',
    'tomorrow_diff': '내일은 좀 다를 거야.',
    'still_here': '그래도 여기 있어.',
    'grew_a_bit': '조금은 자란 것 같아.',
  };

  /// 리액션 후보 (key → emoji + 멘트)
  static const Map<String, ReactionOption> reactionOptions = {
    'HEART_SEEING': ReactionOption('💛', '보고 있어'),
    'BUBBLE_OK': ReactionOption('🫧', '괜찮아'),
    'SPARKLE_GOOD': ReactionOption('✨', '잘했어'),
    'MOON_DAY': ReactionOption('🌙', '오늘은 이런 날'),
    'ICE_BREATHE': ReactionOption('🧊', '숨 고르자'),
    'FIRE_ENDURED': ReactionOption('🔥', '버텼다'),
  };

  // ───────────────────────── 문장 조합 ─────────────────────────

  /// 3단 선택 → 완성 문장
  static String renderText(
    String situationTag,
    String toneEmoji,
    String endingKey,
  ) {
    final ending = endings[endingKey] ?? endingKey;
    return '오늘은 ${situationTag}이 $toneEmoji $ending';
  }

  // ───────────────────────── CRUD ─────────────────────────

  /// 오늘 이미 게시했는지 확인
  /// (복합 인덱스 불필요 — dateKey 1필드 쿼리 + 클라이언트 필터)
  static Future<bool> hasPostedToday(String uid, String dateKey) async {
    try {
      final snap = await _postsRef
          .where('dateKey', isEqualTo: dateKey)
          .get();
      return snap.docs.any(
        (doc) => (doc.data())['authorUid'] == uid,
      );
    } catch (e) {
      debugPrint('⚠️ hasPostedToday error: $e');
      return false; // 에러 시 게시 허용 (서버 중복은 createPost에서 재검증)
    }
  }

  /// 게시물 생성 (유저당 하루 1개 — 서버 측 검증)
  static Future<void> createPost({
    required String situationTag,
    required String toneEmoji,
    required String endingKey,
    required String dateKey,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');

    // 중복 방지
    if (await hasPostedToday(uid, dateKey)) {
      throw Exception('오늘은 이미 남겼어요.');
    }

    // 교감 프로필에서 경력·지역 가져오기 (캐시 우선)
    final profile = await UserProfileService.getMyProfile();
    final careerBucket = profile?.careerBucket ?? '';
    final region = profile?.region ?? '';

    final renderedText = renderText(situationTag, toneEmoji, endingKey);

    final post = DailyWallPost(
      id: '', // Firestore 자동 생성
      createdAt: DateTime.now(),
      dateKey: dateKey,
      authorUid: uid,
      authorMeta: AuthorMeta(careerBucket: careerBucket, region: region),
      situationTag: situationTag,
      toneEmoji: toneEmoji,
      endingKey: endingKey,
      renderedText: renderedText,
    );

    await _postsRef.add(post.toMap());

    // 스탬프 트리거 (D. 문장 작성)
    _reportStampActivity('sentence_write');
  }

  /// 오늘 게시물 스트림
  /// (복합 인덱스 불필요 — dateKey 1필드 쿼리 + 클라이언트 필터/셔플)
  static Stream<List<DailyWallPost>> streamTodayPosts(
    String dateKey, {
    int limit = 20,
  }) {
    return _postsRef
        .where('dateKey', isEqualTo: dateKey)
        .snapshots()
        .map((snap) {
      final posts = snap.docs
          .map(DailyWallPost.fromDoc)
          .where((p) => !p.isHidden) // 클라이언트 필터
          .take(limit)
          .toList();
      // 여론 쏠림 방지: 셔플
      posts.shuffle(_rng);
      return posts;
    });
  }

  // ───────────────────────── 리액션 ─────────────────────────

  /// 리액션 저장 (overwrite 허용)
  static Future<void> setReaction(
    String postId,
    String reactionKey,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _postsRef.doc(postId).collection('reactions').doc(uid).set(
          WallReaction(
            uid: uid,
            reactionKey: reactionKey,
            createdAt: DateTime.now(),
          ).toMap(),
        );

    // 스탬프 트리거 (B. 한 문장 리액션)
    _reportStampActivity('sentence_reaction');
  }

  /// 내가 이 게시물에 남긴 리액션 키 (없으면 null)
  static Future<String?> getMyReaction(String postId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc =
        await _postsRef.doc(postId).collection('reactions').doc(uid).get();
    if (!doc.exists) return null;
    return (doc.data() ?? {})['reactionKey'] as String?;
  }

  /// 게시물의 리액션 요약 (key → 개수)
  static Future<Map<String, int>> getReactionSummary(String postId) async {
    final snap = await _postsRef.doc(postId).collection('reactions').get();
    final summary = <String, int>{};
    for (final doc in snap.docs) {
      final key = (doc.data())['reactionKey'] as String? ?? '';
      summary[key] = (summary[key] ?? 0) + 1;
    }
    return summary;
  }

  // ───────────────────────── 유틸 ─────────────────────────

  /// KST 기준 오늘 dateKey
  static String todayDateKey() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    return '${kst.year}-${kst.month.toString().padLeft(2, '0')}-${kst.day.toString().padLeft(2, '0')}';
  }

  // ───────────────────────── 스탬프 보조 ─────────────────────────

  /// 파트너 그룹이 있으면 스탬프 활동 보고 (실패해도 무시)
  static Future<void> _reportStampActivity(String activityType) async {
    try {
      final groupId = await UserProfileService.getPartnerGroupId();
      if (groupId == null || groupId.isEmpty) return;
      await WeeklyStampService.reportActivity(
        groupId: groupId,
        activityType: activityType,
      );
    } catch (_) {
      // 스탬프는 보조 기능 — 실패해도 UX 차단 안 함
    }
  }
}

/// 리액션 옵션 (이모지 + 멘트)
class ReactionOption {
  final String emoji;
  final String label;
  const ReactionOption(this.emoji, this.label);
}

