// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

abstract final class JustLoggedInFlag {
  static const _key = 'web_login_just_logged_in';

  static void mark() {
    try {
      html.window.sessionStorage[_key] = '1';
    } catch (_) {}
  }

  static bool consume() {
    try {
      final v = html.window.sessionStorage[_key];
      if (v == '1') {
        html.window.sessionStorage.remove(_key);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
