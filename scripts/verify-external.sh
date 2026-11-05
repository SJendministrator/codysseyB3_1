#!/bin/bash
# 내 맥(외부)에서 실행하는 검증 스크립트 — 설치 필요 없음(macOS 기본 curl/nc)
# 사용: bash verify-external.sh <퍼블릭IP>
set -u
IP="${1:?사용법: bash verify-external.sh <퍼블릭IP>}"

echo "==== GET http://$IP/health ===="
curl -s -i --max-time 5 "http://$IP/health"
echo

echo "==== GET http://$IP/ (상태코드) ===="
curl -s -o /dev/null -w "HTTP %{http_code}\n" --max-time 5 "http://$IP/"

echo "==== 보안 그룹 확인: 열려 있으면 안 되는 포트 ===="
for p in 3306 8080; do
  if nc -z -G 3 "$IP" "$p" 2>/dev/null; then
    echo "!! $p 포트가 열려 있음 — 보안 그룹 점검"
  else
    echo "OK  $p 포트 차단됨"
  fi
done
