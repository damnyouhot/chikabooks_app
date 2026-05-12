import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// 토스페이먼츠 **빌링 인증(카드 등록)** 웹 SDK 어댑터.
///
/// 전체 흐름:
///   1) 사용자가 [requestBillingAuth] 호출 → 토스 결제창 OPEN.
///   2) 카드 정보 입력 후 토스가 [_successUrl] 로 redirect (authKey, customerKey 쿼리).
///   3) 클라이언트가 success 페이지에서 `BillingKeyService.registerBillingKey` 호출.
///   4) 서버가 영구 billingKey 발급 + `billingKeys/{uid}` + `billingMeta/profile` 저장.
///
/// 운영 연동 시 필요한 작업:
///   - web/index.html 에 `<script src="https://js.tosspayments.com/v2/standard"></script>` 추가
///     (이미 결제 위젯에서 로드됨 — 동일 SDK).
///   - [_clientKey] 를 운영 client key 로 교체.
///   - [_successUrl] / [_failUrl] 을 운영 도메인으로 교체.
class TossBillingAuthService {
  // ⚠️ 결제 위젯과 동일한 client key 를 사용 (Toss 콘솔 기준).
  static const _clientKey = 'test_ck_GjLJoQ1aVZXLDYY7DlyP8w6KYe2R';
  static const _successUrl =
      'https://hygienelab.kr/post-job/payment/billing/success';
  static const _failUrl =
      'https://hygienelab.kr/post-job/payment/billing/fail';

  /// 카드(빌링키) 등록 인증을 시작한다.
  ///
  /// [customerKey] — 반드시 본인 Firebase UID (서버에서 검증).
  /// [customerEmail] — 영수증/결제 식별용 (필수, 토스 SDK 요구).
  /// [customerName] — 표시용 (선택).
  static Future<void> requestBillingAuth({
    required String customerKey,
    required String customerEmail,
    String? customerName,
  }) async {
    if (customerKey.isEmpty) {
      throw ArgumentError('customerKey is required');
    }
    debugPrint(
      '💳 TossBillingAuth.requestBillingAuth: customerKey=$customerKey',
    );
    _callTossBillingAuth(
      clientKey: _clientKey,
      customerKey: customerKey,
      customerEmail: customerEmail,
      customerName: customerName ?? '',
      successUrl: _successUrl,
      failUrl: _failUrl,
    );
  }

  static void _callTossBillingAuth({
    required String clientKey,
    required String customerKey,
    required String customerEmail,
    required String customerName,
    required String successUrl,
    required String failUrl,
  }) {
    // JS interop — Toss SDK v2 standard.
    // 실제 연동 시 web/index.html 에 SDK 스크립트가 로드돼 있어야 함.
    final script =
        '''
      (async function() {
        if (typeof TossPayments === 'undefined') {
          console.error('TossPayments SDK not loaded');
          window.location.href = '$failUrl?code=SDK_NOT_LOADED&message=' +
            encodeURIComponent('결제 모듈을 불러오지 못했어요. 페이지를 새로고침해 주세요.');
          return;
        }
        try {
          const tossPayments = TossPayments('$clientKey');
          const billing = tossPayments.billing({ customerKey: '$customerKey' });
          await billing.requestBillingAuth({
            method: 'CARD',
            successUrl: '$successUrl',
            failUrl: '$failUrl',
            customerEmail: '$customerEmail',
            customerName: '$customerName',
          });
        } catch (e) {
          console.error('billingAuth error', e);
          var msg = (e && e.message) ? e.message : '카드 인증 중 오류가 발생했어요.';
          window.location.href = '$failUrl?code=BILLING_AUTH_ERROR&message=' +
            encodeURIComponent(msg);
        }
      })();
    ''';

    final scriptEl =
        web.document.createElement('script') as web.HTMLScriptElement;
    scriptEl.text = script;
    web.document.body?.appendChild(scriptEl);
    scriptEl.remove();
  }

  /// successUrl 콜백 query 파싱.
  /// Toss 응답: ?authKey=...&customerKey=...
  static Map<String, String> parseSuccessParams(Uri uri) {
    return {
      'authKey': uri.queryParameters['authKey'] ?? '',
      'customerKey': uri.queryParameters['customerKey'] ?? '',
    };
  }

  /// failUrl 콜백 query 파싱.
  static Map<String, String> parseFailParams(Uri uri) {
    return {
      'code': uri.queryParameters['code'] ?? '',
      'message': uri.queryParameters['message'] ?? '',
      'orderId': uri.queryParameters['orderId'] ?? '',
    };
  }

  // ── 등록 후 복귀 경로 보존 (sessionStorage) ──────────────
  // Toss 가 successUrl 을 고정으로 받기 때문에, 페이지 별로 복귀할 곳을
  // 저장해 둔 뒤 success 페이지에서 읽어 사용한다.
  static const _nextKey = 'cb_billing_next';

  static void setNextRedirect(String? next) {
    if (next == null || next.isEmpty) {
      try {
        web.window.sessionStorage.removeItem(_nextKey);
      } catch (_) {}
      return;
    }
    try {
      web.window.sessionStorage.setItem(_nextKey, next);
    } catch (e) {
      debugPrint('⚠️ setNextRedirect failed: $e');
    }
  }

  static String? readNextRedirect({bool consume = true}) {
    try {
      final v = web.window.sessionStorage.getItem(_nextKey);
      if (consume) {
        try {
          web.window.sessionStorage.removeItem(_nextKey);
        } catch (_) {}
      }
      if (v == null || v.isEmpty) return null;
      return v;
    } catch (_) {
      return null;
    }
  }
}
