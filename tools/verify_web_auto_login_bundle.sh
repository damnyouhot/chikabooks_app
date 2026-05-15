#!/usr/bin/env bash
# ── [CHIKA_WEB_AUTO_LOGIN: BEGIN] ─────────────────────────────────────
# Firebase Hosting predeploy 가드 (임시 기능).
#
# 목적: `.chika_web_login.env` 를 두고 자동 로그인 기능을 켜둔 환경에서
#       누군가(나 자신/타 대화창의 같은 모델 포함)가 wrapper 스크립트
#       (tools/build_web_hosting_with_auto_login.sh) 를 거치지 않고
#       그냥 `flutter build web --release && firebase deploy` 로 올려서
#       자동 로그인 dart-define 이 빠진 번들이 chikabooks3rd 에 올라가
#       chikabooks3rd.web.app 가 다시 로그인 화면으로 빠지는 사고를 막는다.
#
# 동작:
#   - 루트에 .chika_web_login.env 가 없으면 → 가드 통과 (기능 미사용 환경)
#   - 있으면 → build/web/main.dart.js 안에 EMAIL/PASSWORD 값이
#              둘 다 박혀 있는지 검사. 하나라도 없으면 배포 차단.
#
# 원복:
#   기능 종료 시 이 파일 삭제 + firebase.json 의 hosting.predeploy
#   안의 본 스크립트 호출 라인을 함께 제거. (검색 키워드: CHIKA_WEB_AUTO_LOGIN)
# ──────────────────────────────────────────────────────────────────────
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/.chika_web_login.env"
BUNDLE="$ROOT/build/web/main.dart.js"

# 기능 미사용 환경(.env 없음) → 통과
if [[ ! -f "$ENV_FILE" ]]; then
  exit 0
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

EMAIL="${CHIKA_WEB_AUTO_EMAIL:-}"
PW="${CHIKA_WEB_AUTO_PASSWORD:-}"
CLINIC_EMAIL="${CHIKA_WEB_AUTO_CLINIC_EMAIL:-}"
CLINIC_PW="${CHIKA_WEB_AUTO_CLINIC_PASSWORD:-}"

if [[ -z "$EMAIL" || -z "$PW" ]]; then
  cat >&2 <<EOF
✋ [CHIKA_WEB_AUTO_LOGIN] $ENV_FILE 가 있지만 CHIKA_WEB_AUTO_EMAIL/CHIKA_WEB_AUTO_PASSWORD 가 비어 있음.
   값을 채우거나, 자동 로그인을 끝낼 거면 .chika_web_login.env 를 먼저 삭제하세요.
EOF
  exit 1
fi

# clinic 한쪽만 채운 비대칭 상태 차단 (둘 다 비우거나 둘 다 채우거나)
if [[ ( -n "$CLINIC_EMAIL" && -z "$CLINIC_PW" ) || ( -z "$CLINIC_EMAIL" && -n "$CLINIC_PW" ) ]]; then
  cat >&2 <<EOF
✋ [CHIKA_WEB_AUTO_LOGIN] CHIKA_WEB_AUTO_CLINIC_EMAIL 과 CHIKA_WEB_AUTO_CLINIC_PASSWORD 는 둘 다 채우거나 둘 다 비워야 합니다.
EOF
  exit 1
fi

if [[ ! -f "$BUNDLE" ]]; then
  cat >&2 <<EOF
✋ [CHIKA_WEB_AUTO_LOGIN] build/web/main.dart.js 가 없습니다. 먼저 빌드해야 합니다.
   반드시 아래 스크립트만 사용하세요:
     ./tools/build_web_hosting_with_auto_login.sh --deploy
EOF
  exit 1
fi

MISSING=()
if ! grep -q -F -- "$EMAIL" "$BUNDLE"; then
  MISSING+=("CHIKA_WEB_AUTO_EMAIL")
fi
if ! grep -q -F -- "$PW" "$BUNDLE"; then
  MISSING+=("CHIKA_WEB_AUTO_PASSWORD")
fi
# clinic 자격 증명이 .env 에 채워져 있으면 번들에도 박혀 있어야 함.
if [[ -n "$CLINIC_EMAIL" && -n "$CLINIC_PW" ]]; then
  if ! grep -q -F -- "$CLINIC_EMAIL" "$BUNDLE"; then
    MISSING+=("CHIKA_WEB_AUTO_CLINIC_EMAIL")
  fi
  if ! grep -q -F -- "$CLINIC_PW" "$BUNDLE"; then
    MISSING+=("CHIKA_WEB_AUTO_CLINIC_PASSWORD")
  fi
fi

if (( ${#MISSING[@]} > 0 )); then
  cat >&2 <<EOF
✋ [CHIKA_WEB_AUTO_LOGIN] 배포 차단됨.
   build/web/main.dart.js 에 다음 dart-define 이 빠져 있습니다:
     ${MISSING[*]}

   → 이 번들은 자동 로그인이 꺼진 상태이며, 그대로 배포하면
     chikabooks3rd.web.app 에서 메뉴 클릭 시 로그인 화면으로 다시 빠집니다.

   해결:  반드시 wrapper 스크립트로 빌드 + 배포하세요.
            ./tools/build_web_hosting_with_auto_login.sh --deploy

   (자동 로그인 기능을 의도적으로 끝내려면 .chika_web_login.env 를 먼저 삭제한 뒤 재배포)
EOF
  exit 1
fi

echo "✓ [CHIKA_WEB_AUTO_LOGIN] build/web/main.dart.js 에 자동 로그인 dart-define 확인됨."
# ── [CHIKA_WEB_AUTO_LOGIN: END] ───────────────────────────────────────
