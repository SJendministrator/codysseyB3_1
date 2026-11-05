#!/bin/bash
# EC2 User data — 인스턴스 최초 부팅 시 1회 자동 실행 (root 권한)
# 대상 OS: Ubuntu 24.04 LTS
# 하는 일: Nginx 설치 → 메인 페이지 교체 → /health 엔드포인트 추가 → 서비스 기동
set -euxo pipefail
exec > >(tee /var/log/user-data.log) 2>&1   # 로그: /var/log/user-data.log

apt-get update -y
apt-get install -y nginx curl

# 1) 메인 페이지 (방식 A 증빙용)
cat > /var/www/html/index.html <<'HTML'
<!doctype html>
<html lang="ko">
<head><meta charset="utf-8"><title>Hello Cloud</title>
<style>
  body{font-family:system-ui,sans-serif;background:#0f172a;color:#e2e8f0;
       display:grid;place-items:center;height:100vh;margin:0}
  .card{text-align:center} h1{font-size:3rem;margin:0 0 .5rem}
  code{background:#1e293b;padding:.2rem .5rem;border-radius:6px}
</style></head>
<body><div class="card">
  <h1>Hello Cloud ☁️</h1>
  <p>codysseyB3_1 · VPC → Public Subnet → EC2(Nginx)</p>
  <p>헬스체크: <code>GET /health</code></p>
</div></body></html>
HTML

# 2) /health 엔드포인트 (방식 B 증빙용) — 고정 응답 "OK", 200
cat > /etc/nginx/sites-available/default <<'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /var/www/html;
    index index.html;

    location = /health {
        access_log off;
        default_type text/plain;
        return 200 "OK\n";
    }

    location / {
        try_files $uri $uri/ =404;
    }
}
NGINX

nginx -t
systemctl enable nginx
systemctl restart nginx

echo "user-data done: $(date -Is)"
