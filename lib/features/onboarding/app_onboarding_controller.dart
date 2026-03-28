import 'package:flutter/material.dart';

/// 온보딩 단계 정의
///
/// 탭 구조 (인덱스 → 이름):
///   탭1 (index 0) : 나      (CaringPage)
///   탭2 (index 1) : 같이    (BondPage)   ← 온보딩 중 잠금
///   탭3 (index 2) : 성장하기 (GrowthPage)
///   탭4 (index 3) : 커리어  (JobPage → 소탭: 채용 / 커리어 카드)
enum AppOnboardingStepId {
  step1a, // 탭1(나)  "안녕 난 저니라고 해."
  step1b, // 탭1(나)  "넌 이름이 뭐야?"
  step2,  // 탭1(나)  닉네임 입력 팝업
  step3,  // 탭1(나)  "나는 멍멍 치과에서 1년차로 일하고 있어. 넌?"
  step4,  // 탭1(나)  근무상태 + 치과/학교 입력 팝업
  step5,  // 탭1(나)  스팟라이트 → 탭4(커리어) 터치 유도
  step6a, // 탭4(커리어 > 커리어카드)  커리어 소개 통합 대사 (6b·6c는 advance에서 건너뜀)
  step6b, // (enum 순서 유지용, 플로우 미사용)
  step6c, // (enum 순서 유지용, 플로우 미사용)
  step5b, // 탭4→탭3  스팟라이트 → 탭3(성장하기) 터치 유도
  step7a, // 탭3(성장하기)  성장 소개 통합 대사 (7b는 advance에서 건너뜀)
  step7b, // (enum 순서 유지용, 플로우 미사용)
  step8,  // 탭3(성장하기)  "이제 첫 번째 탭으로 가볼까?"
  step9a, // 탭1(나)  "난 항상 여기 있을건데..."
  step9b, // 탭1(나)  "하루 몇번이면 충분해."
  step9c, // 탭1(나)  "앞으로 잘 지내자." → 온보딩 완료
}

/// 각 step이 속한 탭 인덱스
///   0 = 탭1(나)  /  2 = 탭3(성장하기)  /  3 = 탭4(커리어)
const Map<AppOnboardingStepId, int> kStepTabIndex = {
  AppOnboardingStepId.step1a: 0, // 탭1: 나
  AppOnboardingStepId.step1b: 0, // 탭1: 나
  AppOnboardingStepId.step2:  0, // 탭1: 나
  AppOnboardingStepId.step3:  0, // 탭1: 나
  AppOnboardingStepId.step4:  0, // 탭1: 나
  AppOnboardingStepId.step5:  3, // 탭4: 커리어 (spotlight → 탭4 유도)
  AppOnboardingStepId.step6a: 3, // 탭4: 커리어 > 커리어카드
  AppOnboardingStepId.step6b: 3, // 탭4: 커리어 > 커리어카드
  AppOnboardingStepId.step6c: 3, // 탭4: 커리어 > 커리어카드
  AppOnboardingStepId.step5b: 3, // 탭4→탭3 (spotlight → 성장하기 유도, 탭4 유지로 중복이동 방지)
  AppOnboardingStepId.step7a: 2, // 탭3: 성장하기
  AppOnboardingStepId.step7b: 2, // 탭3: 성장하기
  AppOnboardingStepId.step8:  3, // 탭3→탭1 spotlight (탭3 유지로 자동이동 방지, 탭1 클릭으로 진행)
  AppOnboardingStepId.step9a: 0, // 탭1: 나
  AppOnboardingStepId.step9b: 0, // 탭1: 나
  AppOnboardingStepId.step9c: 0, // 탭1: 나
};

/// 터치로 진행하는 step인지 (false면 팝업이나 탭 이동으로 진행)
const Set<AppOnboardingStepId> kTouchAdvanceSteps = {
  AppOnboardingStepId.step1a,
  AppOnboardingStepId.step1b,
  AppOnboardingStepId.step3,
  AppOnboardingStepId.step6a,
  AppOnboardingStepId.step7a,
  // step8은 spotlight → 탭1 클릭으로만 진행 (터치 불가)
  AppOnboardingStepId.step9a,
  AppOnboardingStepId.step9b,
  AppOnboardingStepId.step9c,
};

/// 핀조명(spotlight) step
const Set<AppOnboardingStepId> kSpotlightSteps = {
  AppOnboardingStepId.step5,  // 탭4(커리어) 유도
  AppOnboardingStepId.step5b, // 탭3(성장하기) 유도
  AppOnboardingStepId.step8,  // 탭1(나) 유도
};

/// AppOnboardingController — 온보딩 진행 상태 관리
class AppOnboardingController extends ChangeNotifier {
  AppOnboardingStepId _current = AppOnboardingStepId.step1a;
  bool _active = false;

  /// 온보딩 진행 중 여부
  bool get isActive => _active;

  /// 현재 step
  AppOnboardingStepId get current => _current;

  /// 현재 step이 속한 탭 인덱스
  int get currentTabIndex => kStepTabIndex[_current] ?? 0;

  /// 터치로 진행 가능한 step인지
  bool get canTouchAdvance => kTouchAdvanceSteps.contains(_current);

  /// 핀조명 step인지
  bool get isSpotlight => kSpotlightSteps.contains(_current);

  /// 팝업 step인지
  bool get isPopup =>
      _current == AppOnboardingStepId.step2 ||
      _current == AppOnboardingStepId.step4;

  /// 온보딩 시작
  void start() {
    _current = AppOnboardingStepId.step1a;
    _active = true;
    notifyListeners();
  }

  /// 다음 step으로 진행
  void advance() {
    final AppOnboardingStepId? next = switch (_current) {
      AppOnboardingStepId.step6a => AppOnboardingStepId.step5b,
      AppOnboardingStepId.step7a => AppOnboardingStepId.step8,
      _ => _nextStep(_current),
    };
    if (next == null) {
      _active = false;
      notifyListeners();
      return;
    }
    _current = next;
    notifyListeners();
  }

  /// step 완료 후 특정 step으로 강제 이동 (탭 이동 후 재개)
  void jumpTo(AppOnboardingStepId step) {
    _current = step;
    notifyListeners();
  }

  AppOnboardingStepId? _nextStep(AppOnboardingStepId step) {
    final values = AppOnboardingStepId.values;
    final idx = values.indexOf(step);
    if (idx < 0 || idx >= values.length - 1) return null;
    return values[idx + 1];
  }

  /// 현재 step이 탭0(CaringPage)에 속하는지
  bool get isTab0Step => (kStepTabIndex[_current] ?? 0) == 0;
}

