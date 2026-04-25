// 로그아웃/계정 삭제 직후 SPA 를 강제 리로드하는 헬퍼.
//
// 웹: window.location 을 `/login` 으로 교체 + reload.
//     이렇게 하면 메모리에 남은 옛 사용자 stream/위젯 상태가 0% 잔존하지
//     않으므로 계정 간 데이터 누수가 원천 차단된다.
// 모바일: no-op (모바일은 GoRouter `/login` 이동만으로 충분).
//
// `dart:html` 은 웹 전용이라 모바일 빌드에서 컴파일 에러를 내므로
// 조건부 import 로 stub/web 구현을 분리한다.
export 'logout_reload_stub.dart'
    if (dart.library.html) 'logout_reload_web.dart';
