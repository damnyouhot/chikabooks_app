import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// 토스 본인확인(Toss Identity) 웹 SDK 연동 서비스
///
/// 운영 연동 시 필요한 작업:
/// 1. 토스 본인확인 서비스 가입 및 API 키 발급
/// 2. Cloud Functions에 시크릿 키 환경변수 설정
/// 3. [_clientKey]를 실제 클라이언트 키로 교체
/// 4. `verifyIdentityResult` Callable 구현 (서버에서 txId로 인증 결과 조회)
class TossIdentityService {
  static const _clientKey = 'test_ck_IDENTITY_PLACEHOLDER';

  /// 본인인증 팝업을 호출합니다.
  ///
  /// 성공 시 [txId]를 반환하며, 서버에서 이 txId로 인증 결과를 조회합니다.
  /// 실패 시 null을 반환합니다.
  static Future<String?> requestIdentityVerification({
    required String customerEmail,
  }) async {
    if (!kIsWeb) {
      throw UnsupportedError('TossIdentityService is web-only');
    }

    debugPrint('🪪 TossIdentityService.requestIdentityVerification: '
        'email=$customerEmail');

    // TODO: 실제 토스 본인확인 SDK 연동
    // 현재는 스켈레톤 — SDK가 로드되면 팝업을 띄우고 txId를 반환합니다.
    final completer = Completer<String?>();

    _callTossIdentityWidget(
      clientKey: _clientKey,
      customerEmail: customerEmail,
      onSuccess: (txId) => completer.complete(txId),
      onError: () => completer.complete(null),
    );

    return completer.future;
  }

  static void _callTossIdentityWidget({
    required String clientKey,
    required String customerEmail,
    required void Function(String txId) onSuccess,
    required void Function() onError,
  }) {
    // TODO: JS interop으로 토스 본인확인 SDK 호출
    // 실제 연동 시 아래 코드를 활성화
    debugPrint('🪪 TossIdentity SDK call (skeleton) — '
        'clientKey=$clientKey');

    // 스켈레톤: 즉시 실패 반환 (SDK 미연동 상태)
    onError();
  }

  /// 서버에서 txId로 본인인증 결과를 조회하고 clinics_accounts에 저장합니다.
  ///
  /// Cloud Function `verifyIdentityResult`를 호출합니다.
  /// 반환값: 인증된 이름 (성공 시) 또는 null (실패 시)
  static Future<String?> confirmIdentityOnServer({
    required String txId,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('verifyIdentityResult');
      final result = await callable.call(<String, dynamic>{
        'txId': txId,
      });

      final data = result.data as Map<dynamic, dynamic>?;
      if (data == null) return null;

      final success = data['success'] as bool? ?? false;
      if (!success) return null;

      return data['verifiedName'] as String?;
    } catch (e) {
      debugPrint('⚠️ confirmIdentityOnServer: $e');
      return null;
    }
  }

  /// Firebase Phone Auth 폴백 — 토스 본인확인이 실패했을 때 사용
  ///
  /// 이 메서드는 기존 Firebase Phone Auth 로직을 래핑합니다.
  /// 실제 구현은 기존 `PublisherVerifyPhonePage`의 로직을 재사용합니다.
  static Future<bool> fallbackPhoneAuth({
    required String phoneNumber,
    required Future<String?> Function() getSmsCode,
  }) async {
    // TODO: 기존 Firebase Phone Auth 로직 연동
    debugPrint('📱 fallbackPhoneAuth: phone=$phoneNumber (skeleton)');
    return false;
  }
}
