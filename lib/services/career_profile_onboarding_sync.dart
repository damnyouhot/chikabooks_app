import 'package:flutter/foundation.dart';

import 'career_profile_service.dart';

/// 온보딩 `careerGroup` → 커리어 카드 총 경력(개월) 표시값.
///
/// [UserPublicProfile.careerGroups]와 동일한 문자열만 처리한다.
class CareerGroupOnboardingMonths {
  CareerGroupOnboardingMonths._();

  /// 구간 라벨을 대표 개월 수로 매핑 (상단 카드·override용).
  static int totalMonthsForCareerGroup(String careerGroup) {
    switch (careerGroup.trim()) {
      case '학생':
        return 0;
      case '1년차':
        return 12;
      case '2년차':
        return 24;
      case '3년차':
        return 36;
      case '4년차':
        return 48;
      case '5년차':
        return 60;
      case '6~10년차':
        return 96; // 8년 중간
      case '11~15년차':
        return 156; // 13년
      case '15년차 이상':
        return 180; // 15년
      default:
        debugPrint(
          '⚠️ CareerGroupOnboardingMonths: 알 수 없는 careerGroup="$careerGroup"',
        );
        return 0;
    }
  }
}

/// 온보딩·캐릭터 설정 저장 직후 `careerProfile.identity`에 총 경력 override를 반영한다.
///
/// [previousCareerGroupFromUserDoc]: 저장 **직전** `users.careerGroup` (같은 연차로만 저장하고
/// [careerOverrideLocked]가 켜져 있으면 스킵 — 커리어 카드에서 수동 입력 유지).
class CareerProfileOnboardingSync {
  CareerProfileOnboardingSync._();

  static Future<void> applyAfterOnboarding(
    String careerGroup, {
    String? previousCareerGroupFromUserDoc,
  }) async {
    final profile = await CareerProfileService.getMyCareerProfile();
    final identity = profile?['identity'] as Map<String, dynamic>?;

    final locked = identity?['careerOverrideLocked'] == true;
    final prev = previousCareerGroupFromUserDoc?.trim();
    final next = careerGroup.trim();
    final groupChanged =
        prev == null || prev.isEmpty ? true : (prev != next);

    if (locked && !groupChanged) {
      debugPrint(
        'CareerProfileOnboardingSync: skip (careerOverrideLocked, same careerGroup)',
      );
      return;
    }

    final months =
        CareerGroupOnboardingMonths.totalMonthsForCareerGroup(careerGroup);

    var status = 'employed';
    var clinicName = '';
    DateTime? currentStartDate;
    var specialtyTags = <String>[];

    if (identity != null) {
      status = (identity['status'] as String?) ?? 'employed';
      clinicName = (identity['clinicName'] as String?) ?? '';
      specialtyTags =
          (identity['specialtyTags'] as List?)?.cast<String>() ?? [];
      try {
        final ts = identity['currentStartDate'];
        if (ts != null) {
          currentStartDate = (ts as dynamic).toDate() as DateTime;
        }
      } catch (_) {}
    }

    await CareerProfileService.updateCareerIdentity(
      status: status,
      clinicName: clinicName,
      currentStartDate: currentStartDate,
      specialtyTags: specialtyTags,
      useTotalCareerMonthsOverride: true,
      totalCareerMonthsOverride: months,
      careerOverrideLocked: false,
    );
  }
}
