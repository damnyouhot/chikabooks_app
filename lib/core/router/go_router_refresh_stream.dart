import 'dart:async';

import 'package:flutter/foundation.dart';

/// [GoRouter.redirect]가 Firebase Auth 세션 복원(웹 IndexedDB 등, 비동기) 이후에도
/// 다시 평가되도록 [ChangeNotifier]로 스트림을 연결한다.
///
/// 웹 초기 로드 시 [FirebaseAuth.instance.currentUser]는 잠시 `null`일 수 있어,
/// 동기 가드만 쓰면 `/login`으로 잘못 보내지는 레이스가 난다. [refreshListenable]으로
/// [authStateChanges] 이후 redirect가 재실행되게 한다.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
