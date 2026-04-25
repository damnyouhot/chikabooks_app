// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// 웹 SPA 를 `/login` 으로 강제 이동 + 전체 리로드.
///
/// `assign` 이 아니라 `replace` 를 쓰면 뒤로 가기로 이전 사용자 화면이
/// 잠깐이라도 다시 노출되는 것을 막을 수 있다.
void reloadToLogin() {
  final origin = html.window.location.origin;
  html.window.location.replace('$origin/login');
}
