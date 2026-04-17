/// iOS/Android 등 비웹 — 웹 전용 결제는 [TossPaymentService] 웹 구현 참고.
class TossPaymentService {
  static Future<void> requestPayment({
    required String orderId,
    required String orderName,
    required int amount,
    required String customerEmail,
    String? customerName,
  }) async {
    throw UnsupportedError('TossPaymentService is web-only');
  }

  /// 결제 성공 콜백에서 paymentKey 추출 (success URL의 쿼리 파라미터)
  static Map<String, String> parseSuccessParams(Uri uri) {
    return {
      'paymentKey': uri.queryParameters['paymentKey'] ?? '',
      'orderId': uri.queryParameters['orderId'] ?? '',
      'amount': uri.queryParameters['amount'] ?? '',
    };
  }
}
