#!/bin/bash
# EC2 인스턴스 "안에서" 실행하는 검증 스크립트
# 사용: bash verify-instance.sh   (결과 화면을 스크린샷으로 남기기)
set -u

line(){ printf '\n==== %s ====\n' "$1"; }

line "1. Nginx 서비스 상태"
systemctl is-active nginx && systemctl status nginx --no-pager | head -5

line "2. 80 포트 리스닝"
sudo ss -tlnp | grep ':80 ' || echo "!! 80 포트 리스닝 없음"

line "3. curl http://localhost (200 기대)"
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost

line "4. curl http://localhost/health (200 + OK 기대)"
curl -s -i http://localhost/health | head -1
curl -s http://localhost/health

line "5. 아웃바운드 인터넷 (IGW 경유) — curl https://example.com"
curl -s -o /dev/null -w "HTTP %{http_code}\n" --max-time 10 https://example.com \
  || echo "!! 아웃바운드 실패: 라우트 테이블 0.0.0.0/0 → IGW 확인"

line "6. 인스턴스 메타데이터 (퍼블릭 IP / 서브넷)"
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
md(){ curl -s -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/$1"; }
echo "public-ipv4 : $(md public-ipv4)"
echo "local-ipv4  : $(md local-ipv4)"
echo "az          : $(md placement/availability-zone)"
