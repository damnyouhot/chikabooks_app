// "방금 로그인했음" 1회용 플래그.
//
// 웹: sessionStorage 사용 → 탭/창을 닫으면 사라짐.
// 모바일: no-op (해당 플래그는 웹 라우팅 분기 전용).
//
// `dart:html`은 웹 전용이라 모바일 빌드에서 컴파일 에러가 난다.
// 따라서 조건부 import로 stub/web 구현을 분리한다.
export 'just_logged_in_flag_stub.dart'
    if (dart.library.html) 'just_logged_in_flag_web.dart';
