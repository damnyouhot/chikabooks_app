/// /me/* 영역의 데이터/상태를 한 곳에서 정의하는 Riverpod provider 묶음.
///
/// 도입 이유:
/// - 기존 패턴(`StreamBuilder(stream: Service.watchX())`)은 위젯 build 마다
///   새로운 Stream 인스턴스를 만들어 재구독 루프 → 무한 로딩을 일으킴.
/// - Riverpod 의 [StreamProvider] 는 stream 인스턴스를 provider 라이프사이클에
///   묶기 때문에, 위젯 리빌드와 무관하게 단일 구독이 유지된다.
/// - 헤더 / 본문 / 사이드 메뉴가 같은 provider 를 watch 하면 Firestore read 도
///   1회로 합쳐진다 (StreamProvider 의 스트림은 broadcast 로 동작).
///
/// 호환 레이어 정책:
/// - 본 PR 에서는 [MeSession] (ValueNotifier) 을 그대로 두고, [_MeSessionMirror]
///   가 양방향 mirror 를 담당한다 — 점진 마이그레이션을 위해.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/applicant_pool_entry.dart';
import '../../../models/clinic_profile.dart';
import '../../../models/notification_prefs.dart';
import '../../../models/wallet.dart';
import '../../../services/applicant_pool_service.dart';
import '../../../services/notification_prefs_service.dart';
import '../../../services/wallet_service.dart';
import '../../publisher/services/clinic_profile_service.dart';
import '../services/me_overview_service.dart';
import '../services/me_session.dart';

// ──────────────────────────────────────────────────────────────────────
// 1) 단순 상태 — MeSession (ValueNotifier) 과 양방향 mirror
// ──────────────────────────────────────────────────────────────────────
//
// Riverpod 3 에서 StateProvider 는 legacy.dart 로 이동되었으므로 NotifierProvider
// 패턴을 사용한다.

/// 활성 지점 ID. `MeSession.activeBranchId` 와 양방향 mirror.
final meActiveBranchProvider =
    NotifierProvider<_MirroredNotifier<String?>, String?>(
  () => _MirroredNotifier<String?>(MeSession.activeBranchId),
);

/// 청구 정책 모드. `MeSession.billingMode` 와 양방향 mirror.
final meBillingModeProvider =
    NotifierProvider<_MirroredNotifier<BillingMode>, BillingMode>(
  () => _MirroredNotifier<BillingMode>(MeSession.billingMode),
);

/// 청구 정책 상세 (패키지/만료 등). `MeSession.billingPolicy` 와 양방향 mirror.
final meBillingPolicyProvider = NotifierProvider<
    _MirroredNotifier<BillingPolicyConfig>, BillingPolicyConfig>(
  () => _MirroredNotifier<BillingPolicyConfig>(MeSession.billingPolicy),
);

/// `ValueNotifier` ↔ Riverpod state 양방향 동기화.
///
/// - notifier → ref: ValueListener 로 `state` 갱신
/// - ref → notifier: [set] 호출 시 `notifier.value` 도 갱신
///
/// ⚠️ 이전 버전 버그:
///  1. build() 안에서 매번 새 클로저로 addListener → 같은 source 에 listener 가
///     중복 등록 → set 1회당 listener N회 호출 → state 변경 → 또 build → 무한 누적.
///  2. onChange 가 microtask 로 state 를 또 set → state setter 가 ==비교 후
///     알림하므로 값이 같아도 객체 identity 가 다르면 continue → 무한 루프.
///  3. set() 의 if(state == value) 가 객체 타입(BillingPolicyConfig 등) 에서
///     == override 미작성이면 항상 false → 매번 통과 → 무한 ping-pong.
///
/// 수정:
///  - listener 를 인스턴스 필드에 보존 → dispose 시 정확히 제거.
///  - identical() 비교로 ping-pong 차단 (같은 인스턴스면 무시).
///  - microtask 제거 → 동기 처리 (Notifier.state setter 가 이미 안전).
class _MirroredNotifier<T> extends Notifier<T> {
  _MirroredNotifier(this._source);

  final ValueNotifier<T> _source;
  VoidCallback? _listener;

  @override
  T build() {
    _listener = () {
      if (!identical(state, _source.value)) {
        state = _source.value;
      }
    };
    _source.addListener(_listener!);
    ref.onDispose(() {
      if (_listener != null) {
        _source.removeListener(_listener!);
        _listener = null;
      }
    });
    return _source.value;
  }

  /// provider 측에서 값을 변경하는 공식 진입점.
  /// 외부 코드는 `ref.read(provider.notifier).set(value)` 로 호출.
  void set(T value) {
    if (identical(state, value)) return;
    state = value;
    if (!identical(_source.value, value)) {
      _source.value = value;
    }
  }
}

// ──────────────────────────────────────────────────────────────────────
// 1.5) 인증 상태 — 모든 데이터 provider 의 키
// ──────────────────────────────────────────────────────────────────────

/// FirebaseAuth 의 `authStateChanges()` 를 그대로 노출.
///
/// 로그인/로그아웃/계정 전환 시 자동으로 새 값을 emit 한다.
/// 모든 `me_*` stream provider 는 이걸 watch 하므로, **사용자 변경 즉시**
/// 옛 사용자에 묶인 stream 이 폐기되고 새 사용자 stream 이 생성된다.
///
/// ⚠️ 이 provider 가 없을 때의 버그:
///   - `static _uid` 를 호출 시점에 캡처해 stream 안에 박아두기 때문에
///     로그인 후 로그아웃 → 다른 계정 로그인 시에도 옛 stream 이 살아있어
///     이전 사용자의 데이터를 그대로 화면에 그렸음.
final firebaseAuthStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// 현재 로그인된 사용자의 uid (없으면 null).
///
/// 모든 `me_*` data provider 가 이걸 watch 하므로, uid 가 바뀌면
/// 의존하는 provider 들이 자동으로 재구성된다(Riverpod dependency invalidation).
final currentUidProvider = Provider<String?>((ref) {
  final asyncUser = ref.watch(firebaseAuthStateProvider);
  return asyncUser.maybeWhen(
    data: (user) => user?.uid,
    orElse: () => null,
  );
});

// ──────────────────────────────────────────────────────────────────────
// 2) Stream provider — 핵심 데이터 소스
//
// ⚠️ 모든 provider 는 `currentUidProvider` 를 watch 해서 uid 를 stream 생성
// 시점이 아닌 provider 빌드 시점에 잡는다. uid 가 바뀌면 provider 자체가
// 재실행되어 옛 stream 은 폐기되고 새 stream 이 만들어진다.
// ──────────────────────────────────────────────────────────────────────

/// 운영자(치과 계정)의 모든 지점(`clinic_profiles/*`) 스트림.
final clinicProfilesProvider = StreamProvider<List<ClinicProfile>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ClinicProfileService.watchProfiles(uid: uid);
});

/// 현재 사용자의 wallet (잔액 + 보유 공고권)
final walletProvider = StreamProvider<Wallet>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(Wallet.empty(''));
  return WalletService.watchWallet(uid: uid);
});

/// 최근 ledger N건 (기본 30).
final walletLedgerProvider =
    StreamProvider.family<List<WalletLedgerEntry>, int>((ref, limit) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return WalletService.watchLedger(limit: limit, uid: uid);
});

/// 현재 사용자의 알림 수신 설정.
final notificationPrefsProvider = StreamProvider<NotificationPrefs>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(NotificationPrefs.defaults());
  return NotificationPrefsService.watchPrefs(uid: uid);
});

/// 인재풀 — 지점별 지원자 합본 (지원이력 + 풀 엔트리 + 캐시 프로필).
final applicantPoolProvider =
    StreamProvider.family<List<JoinedApplicant>, String?>((ref, branchId) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ApplicantPoolService.watchJoinedApplicants(
    branchId: branchId,
    ownerUid: uid,
  );
});

/// /me 오버뷰 스냅샷 — 지점별 KPI/To-Do 묶음.
final meOverviewProvider =
    FutureProvider.autoDispose.family<MeOverviewSnapshot, String?>(
  (ref, branchId) {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return Future.value(MeOverviewSnapshot.empty);
    return MeOverviewService.fetch(branchId: branchId, ownerUid: uid);
  },
);
