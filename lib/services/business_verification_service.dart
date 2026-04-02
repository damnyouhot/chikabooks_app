import 'package:cloud_functions/cloud_functions.dart';

/// 사업자 검증 Callable 래퍼 (`checkBusinessStatus`)
///
/// OCR 이후 국세청(Mock)·재시도용. 서버: [runCheckBusinessStatus].
class BusinessVerificationService {
  BusinessVerificationService._();

  /// 국세청/모의 검증만 재실행. 결과는 Firestore `businessVerification`에 반영됨.
  static Future<Map<String, dynamic>> checkBusinessStatus({
    required String profileId,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'checkBusinessStatus',
    );
    final result = await callable.call({'profileId': profileId});
    final data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }
}
