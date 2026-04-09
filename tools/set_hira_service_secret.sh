#!/usr/bin/env bash
# 공공데이터포털 인증키로 Firebase Secret `HIRA_SERVICE_KEY` 를 등록한 뒤
# 사업자 검증 관련 Functions 만 재배포합니다.
#
# 사용:
#   HIRA_SERVICE_KEY='발급받은_키_전체' ./tools/set_hira_service_secret.sh
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -z "${HIRA_SERVICE_KEY:-}" ]]; then
  echo "환경변수 HIRA_SERVICE_KEY 에 공공데이터 인증키를 넣은 뒤 실행하세요."
  echo "예: HIRA_SERVICE_KEY='...' ./tools/set_hira_service_secret.sh"
  exit 1
fi

echo -n "$HIRA_SERVICE_KEY" | firebase functions:secrets:set HIRA_SERVICE_KEY --data-file=- --force
firebase deploy --only functions:verifyBusinessLicense,functions:checkBusinessStatus
