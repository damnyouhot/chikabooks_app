// 모바일/네이티브용 no-op 구현.
abstract final class JustLoggedInFlag {
  static void mark() {}
  static bool consume() => false;
}
