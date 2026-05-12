/// 비웹(iOS/Android) 폴백 — 빌링 인증은 웹 전용 흐름.
class TossBillingAuthService {
  static Future<void> requestBillingAuth({
    required String customerKey,
    required String customerEmail,
    String? customerName,
  }) async {
    throw UnsupportedError('TossBillingAuthService is web-only');
  }

  static Map<String, String> parseSuccessParams(Uri uri) {
    return {
      'authKey': uri.queryParameters['authKey'] ?? '',
      'customerKey': uri.queryParameters['customerKey'] ?? '',
    };
  }

  static Map<String, String> parseFailParams(Uri uri) {
    return {
      'code': uri.queryParameters['code'] ?? '',
      'message': uri.queryParameters['message'] ?? '',
      'orderId': uri.queryParameters['orderId'] ?? '',
    };
  }

  static String? _next;

  static void setNextRedirect(String? next) {
    _next = (next == null || next.isEmpty) ? null : next;
  }

  static String? readNextRedirect({bool consume = true}) {
    final v = _next;
    if (consume) _next = null;
    return v;
  }
}
