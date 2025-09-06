// lib/services/character_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/character.dart';

class CharacterService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // 내부 헬퍼: 기본 캐릭터 문서 보장
  static Future<void> _ensureUserDoc(String uid) async {
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();
    if (!snap.exists) {
      final ch = Character(id: uid);
      await ref.set(ch.toJson(), SetOptions(merge: true));
    }
  }

  /// 실시간 캐릭터 구독: caring_page, character_widget, dashboard_tab에서 사용
  static Stream<Character> watchCharacter(String uid) async* {
    await _ensureUserDoc(uid);
    yield* _db.collection('users').doc(uid).snapshots().map((doc) {
      // models/character.dart에 있는 fromDoc 사용
      return Character.fromDoc(doc);
    });
  }

  /// 캐릭터 간식/돌보기 액션: 애정도/경험치 소폭 증가
  static Future<void> feedCharacter() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final ref = _db.collection('users').doc(uid);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      Character ch = snap.exists ? Character.fromDoc(snap) : Character(id: uid);

      // 취향껏 조절 가능: affection +2, exp +5
      ch.affection = (ch.affection ?? 0) + 2;
      ch.gainExperience(5);

      // stats도 함께 적립(대시보드용)
      final data = ch.toJson();
      final stats = Map<String, dynamic>.from(data['stats'] ?? {});
      stats['emotionPoints'] = (stats['emotionPoints'] ?? 0) + 1;
      data['stats'] = stats;

      tx.set(ref, data, SetOptions(merge: true));
    });
  }

  /// 아이템 장착/해제 (null이면 해제)
  static Future<void> equipItem(String? itemId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final ref = _db.collection('users').doc(uid);

    await ref.set({
      'equippedItemId': itemId, // null 허용 → 해제
    }, SetOptions(merge: true));

    // 선택: 인벤토리 자동 추가
    if (itemId != null) {
      await ref.set({
        'inventory': FieldValue.arrayUnion([itemId]),
      }, SetOptions(merge: true));
    }
  }

  /// 출석 체크(하루 1회): 이미 했으면 안내 메시지 반환
  static Future<String> dailyCheckIn() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return '로그인이 필요합니다.';

    final now = DateTime.now();
    final ymd =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    final checkRef = _db
        .collection('users')
        .doc(uid)
        .collection('daily')
        .doc(ymd);
    final exists = (await checkRef.get()).exists;

    if (exists) {
      return '오늘은 이미 체크인 했어요!';
    }

    // 체크인 기록 생성 + 포인트 적립
    await _db.runTransaction((tx) async {
      tx.set(checkRef, {'createdAt': FieldValue.serverTimestamp()});

      final userRef = _db.collection('users').doc(uid);
      final snap = await tx.get(userRef);
      Character ch = snap.exists ? Character.fromDoc(snap) : Character(id: uid);

      // 체크인 보상: affection +1, exp +3, emotionPoints +10
      ch.affection = (ch.affection ?? 0) + 1;
      ch.gainExperience(3);

      final data = ch.toJson();
      final stats = Map<String, dynamic>.from(data['stats'] ?? {});
      stats['emotionPoints'] = (stats['emotionPoints'] ?? 0) + 10;
      data['stats'] = stats;

      tx.set(userRef, data, SetOptions(merge: true));
    });

    return '체크인 완료! 보상을 받았어요 😊';
  }

  /// (옵션) 수동 경험치/스탯 적립이 필요할 때 사용할 수 있는 유틸
  static Future<void> addExperience(double amount) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final ref = _db.collection('users').doc(uid);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      Character ch = snap.exists ? Character.fromDoc(snap) : Character(id: uid);
      ch.gainExperience(amount);
      tx.set(ref, ch.toJson(), SetOptions(merge: true));
    });
  }
}
