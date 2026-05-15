#!/usr/bin/env bash
# ── [CHIKA_WEB_AUTO_LOGIN: BEGIN] ─────────────────────────────────────
# 임시 기능 — 웹 호스팅 빌드에 자동 이메일 로그인을 끼워 넣는다.
# 원복 시: 이 파일과 tools/chika_web_login.env.example,
# .chika_web_login.env(로컬), .gitignore 의 ".chika_web_login.env" 항목,
# lib/core/config/app_initializer.dart 의 [CHIKA_WEB_AUTO_LOGIN] 블록을
# 함께 제거하면 됨. (검색 키워드: CHIKA_WEB_AUTO_LOGIN)
#
# 동작:
#   1) 프로젝트 루트의 .chika_web_login.env 에서 이메일/비밀번호 로드
#   2) flutter build web --release + dart-define 으로 자동 로그인 활성화
#   3) (옵션) --deploy 가 붙으면 firebase deploy --only hosting 실행
#
# 사용:
#   cp tools/chika_web_login.env.example .chika_web_login.env
#   # .chika_web_login.env 편집 후
#   tools/build_web_hosting_with_auto_login.sh           # 빌드만
#   tools/build_web_hosting_with_auto_login.sh --deploy  # 빌드 + 호스팅 배포
#
# 주의: 자격 증명이 main.dart.js 에 포함된다. 공개 프로덕션 금지, 내부/스테이징만.
# ──────────────────────────────────────────────────────────────────────
set -euo pipefail

DEPLOY=0
for arg in "$@"; do
  case "$arg" in
    --deploy|-d) DEPLOY=1 ;;
    *) echo "알 수 없는 인자: $arg" >&2; exit 2 ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ENV_FILE="$ROOT/.chika_web_login.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

: "${CHIKA_WEB_AUTO_EMAIL:?루트에 .chika_web_login.env 를 두거나 환경변수 CHIKA_WEB_AUTO_EMAIL 을 설정하세요 (예시: tools/chika_web_login.env.example)}"
: "${CHIKA_WEB_AUTO_PASSWORD:?CHIKA_WEB_AUTO_PASSWORD 를 설정하세요}"

OPTS=(
  --release
  --dart-define=CHIKA_WEB_AUTO_LOGIN=true
  --dart-define=CHIKA_WEB_AUTO_EMAIL="$CHIKA_WEB_AUTO_EMAIL"
  --dart-define=CHIKA_WEB_AUTO_PASSWORD="$CHIKA_WEB_AUTO_PASSWORD"
)

# 치과(공고자) 테스트 계정 — .env 에 둘 다 채워져 있을 때만 dart-define 으로 주입.
if [[ -n "${CHIKA_WEB_AUTO_CLINIC_EMAIL:-}" && -n "${CHIKA_WEB_AUTO_CLINIC_PASSWORD:-}" ]]; then
  OPTS+=(--dart-define=CHIKA_WEB_AUTO_CLINIC_EMAIL="$CHIKA_WEB_AUTO_CLINIC_EMAIL")
  OPTS+=(--dart-define=CHIKA_WEB_AUTO_CLINIC_PASSWORD="$CHIKA_WEB_AUTO_CLINIC_PASSWORD")
fi
if [[ "${CHIKA_WEB_AUTO_REPLACE_SESSION:-}" == "1" || "${CHIKA_WEB_AUTO_REPLACE_SESSION:-}" == "true" ]]; then
  OPTS+=(--dart-define=CHIKA_WEB_AUTO_REPLACE_SESSION=true)
fi

# 부팅 시 자동 sign-in 여부 (기본 true → 기존 동작 유지).
# .env 에 CHIKA_WEB_AUTO_LOGIN_ON_BOOT=0|false 로 두면 부팅 sign-in 건너뜀.
ON_BOOT_RAW="${CHIKA_WEB_AUTO_LOGIN_ON_BOOT:-true}"
case "$ON_BOOT_RAW" in
  0|false|FALSE|no|NO) ON_BOOT_VAL="false" ;;
  *)                   ON_BOOT_VAL="true"  ;;
esac
OPTS+=(--dart-define=CHIKA_WEB_AUTO_LOGIN_ON_BOOT="$ON_BOOT_VAL")

if [[ -n "${CHIKA_WEB_AUTO_CLINIC_EMAIL:-}" ]]; then
  echo "▶ flutter build web (자동 로그인: $CHIKA_WEB_AUTO_EMAIL · 치과 테스트: $CHIKA_WEB_AUTO_CLINIC_EMAIL)"
else
  echo "▶ flutter build web (자동 로그인: $CHIKA_WEB_AUTO_EMAIL)"
fi
flutter build web "${OPTS[@]}"

if [[ "$DEPLOY" == "1" ]]; then
  echo "▶ firebase deploy --only hosting"
  firebase deploy --only hosting
fi
# ── [CHIKA_WEB_AUTO_LOGIN: END] ───────────────────────────────────────
