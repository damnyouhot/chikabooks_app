import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// 토스페이먼츠 웹 SDK 연동 서비스
///
/// 운영 연동 시 필요한 작업:
/// 1. web/index.html에 토스 SDK 스크립트 추가:
///    `<script src="https://js.tosspayments.com/v2/standard"></script>`
/// 2. Cloud Functions에 secretKey 환경변수 설정
/// 3. [_clientKey]를 실제 클라이언트 키로 교체
/// 4. [_successUrl] / [_failUrl]을 실제 도메인으로 교체
class TossPaymentService {
  static const _clientKey = 'test_ck_PLACEHOLDER';
  static const _successUrl = 'https://yourdomain.com/post-job/payment/success';
  static const _failUrl = 'https://yourdomain.com/post-job/payment/fail';

  /// 결제 위젯을 호출하여 카드 결제를 시작합니다.
  ///
  /// [orderId] — 서버에서 생성한 주문 ID
  /// [orderName] — 표시할 상품명 (예: "공고 게시 30일")
  /// [amount] — 결제 금액 (원)
  /// [customerEmail] — 구매자 이메일
  /// [customerName] — 구매자 이름 (본인인증 이름)
  static Future<void> requestPayment({
    required String orderId,
    required String orderName,
    required int amount,
    required String customerEmail,
    String? customerName,
  }) async {
    if (!kIsWeb) {
      throw UnsupportedError('TossPaymentService is web-only');
    }

    // TODO: 실제 토스 SDK 연동 시 아래 JS interop 코드 활성화
    // 현재는 스켈레톤으로, SDK 스크립트 로드 후 동작합니다.
    debugPrint('💳 TossPaymentService.requestPayment: '
        'orderId=$orderId, amount=$amount');

    _callTossPaymentWidget(
      clientKey: _clientKey,
      orderId: orderId,
      orderName: orderName,
      amount: amount,
      customerEmail: customerEmail,
      customerName: customerName ?? '',
      successUrl: _successUrl,
      failUrl: _failUrl,
    );
  }

  static void _callTossPaymentWidget({
    required String clientKey,
    required String orderId,
    required String orderName,
    required int amount,
    required String customerEmail,
    required String customerName,
    required String successUrl,
    required String failUrl,
  }) {
    // JS interop으로 토스 SDK 호출
    // 실제 연동 시 web/index.html에 SDK 스크립트가 로드되어 있어야 합니다.
    final script = '''
      (async function() {
        if (typeof TossPayments === 'undefined') {
          console.error('TossPayments SDK not loaded');
          return;
        }
        const tossPayments = TossPayments('$clientKey');
        const payment = tossPayments.payment({ customerKey: '$customerEmail' });
        await payment.requestPayment({
          method: 'CARD',
          amount: { currency: 'KRW', value: $amount },
          orderId: '$orderId',
          orderName: '$orderName',
          customerEmail: '$customerEmail',
          customerName: '$customerName',
          successUrl: '$successUrl',
          failUrl: '$failUrl',
        });
      })();
    ''';

    final scriptEl = web.document.createElement('script') as web.HTMLScriptElement;
    scriptEl.text = script;
    web.document.body?.appendChild(scriptEl);
    scriptEl.remove();
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
