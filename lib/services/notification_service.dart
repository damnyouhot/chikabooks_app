import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    // 권한 요청 (iOS, Android 13+)
    await _messaging.requestPermission();

    // FCM 토큰 가져오기
    final fcmToken = await _messaging.getToken();
    debugPrint('🔥 FCM Token: $fcmToken');

    // TODO: 이 토큰을 Firestore의 users/{uid} 문서에 저장하여 특정 사용자에게 알림을 보낼 수 있음

    // 포그라운드 상태에서 메시지 수신 처리
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔥 Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint(
            'Message also contained a notification: ${message.notification}');
      }
    });
  }
}
