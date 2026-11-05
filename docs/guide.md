# 실습 진행 가이드 (콘솔 클릭 순서)

> 리전은 처음부터 끝까지 **아시아 태평양(서울) ap-northeast-2** — 콘솔 우측 상단 확인.
> 만드는 모든 리소스에 태그 `Project = codyssey-b3-1` 을 붙인다 → 나중에 정리할 때 이 태그로 한 번에 찾는다.

예상 소요: 생성 40분 + 검증·스크린샷 20분 + 정리 10분

---

## 0. IAM 사용자 준비 (루트로는 이 단계만)

루트 계정은 "IAM 사용자 만들기"까지만 쓰고 로그아웃한다. 이후 모든 작업은 IAM 사용자로.

1. IAM → 정책 → **정책 생성** → JSON 탭 → `iam/codyssey-b3-1-least-privilege.json` 내용 붙여넣기
   - 이름: `Codyssey-B3-1-EC2VPC-LeastPrivilege`
2. IAM → 사용자 → **사용자 생성**
   - 이름: `codyssey-b3-1` / AWS Management Console 액세스 체크
   - 권한: **직접 정책 연결** → 위 정책 1개만 (`AdministratorAccess` 절대 X)
   - 콘솔 첫 로그인 시 비밀번호 변경을 강제하면 `IAMUserChangePassword` 도 같이 붙여야 함
3. 📸 **스크린샷**: 사용자 → 권한 탭 (붙은 정책이 1~2개뿐인 화면)
4. 루트 로그아웃 → IAM 사용자 로그인 URL(`https://<계정ID>.signin.aws.amazon.com/console`)로 재로그인

> 💡 S3 콘솔에 들어가 보면 "권한 없음"이 뜬다 → 이게 최소권한이 먹힌 증거. 스크린샷 찍어두면 README에 좋음.

---

## 1. VPC

VPC → **VPC 생성** → "VPC만" 선택

| 항목 | 값 |
|---|---|
| 이름 | `b3-1-vpc` |
| IPv4 CIDR | `10.0.0.0/16` |

생성 후: 작업 → VPC 설정 편집 → **DNS 호스트 이름 활성화** 체크

## 2. Public Subnet

서브넷 → **서브넷 생성**

| 항목 | 값 |
|---|---|
| VPC | `b3-1-vpc` |
| 이름 | `b3-1-public-subnet` |
| 가용 영역 | `ap-northeast-2a` |
| CIDR | `10.0.1.0/24` |

생성 후: 작업 → 서브넷 설정 편집 → **퍼블릭 IPv4 주소 자동 할당 활성화** ✅
(이걸 빼먹으면 EC2에 퍼블릭 IP가 안 붙는다 — 단골 트러블슈팅 소재)

## 3. Internet Gateway

인터넷 게이트웨이 → 생성(`b3-1-igw`) → 작업 → **VPC에 연결** → `b3-1-vpc`

## 4. Route Table

라우팅 테이블 → **라우팅 테이블 생성** (`b3-1-public-rt`, VPC: `b3-1-vpc`)

1. 라우팅 탭 → 라우팅 편집 → 라우팅 추가: `0.0.0.0/0` → 대상 `인터넷 게이트웨이` → `b3-1-igw`
2. 서브넷 연결 탭 → 명시적 서브넷 연결 → `b3-1-public-subnet`

📸 **스크린샷**: 라우팅 탭 (`10.0.0.0/16 local` + `0.0.0.0/0 igw-...` 두 줄)

## 5. Security Group

EC2 → 보안 그룹 → **보안 그룹 생성** (`b3-1-web-sg`, VPC: `b3-1-vpc`)

인바운드 규칙 — **딱 2개**:

| 유형 | 포트 | 소스 | 설명 |
|---|---|---|---|
| HTTP | 80 | `0.0.0.0/0` | public web |
| SSH | 22 | **내 IP** (드롭다운에서 "내 IP" 선택 → `x.x.x.x/32`) | admin only |

아웃바운드: 기본값(모두 허용) 유지 — 그래야 `apt install`, `curl example.com`이 된다.

📸 **스크린샷**: 인바운드 규칙 탭

> ⚠️ 학원 와이파이 ↔ 집 와이파이로 옮기면 내 IP가 바뀐다 → SSH가 갑자기 timeout. 그때 SG의 22번 소스만 새 IP로 바꾸면 됨. (실제로 겪으면 트러블슈팅 보고서 감)

## 6. EC2

EC2 → **인스턴스 시작**

| 항목 | 값 |
|---|---|
| 이름 | `b3-1-web` |
| AMI | Ubuntu Server 24.04 LTS (프리 티어 사용 가능 표시) |
| 인스턴스 유형 | `t3.micro` (또는 t2.micro) |
| 키 페어 | 새로 생성 → `b3-1-key` / RSA / `.pem` → 다운로드 (재발급 불가!) |
| 네트워크 설정 → 편집 | VPC `b3-1-vpc` / 서브넷 `b3-1-public-subnet` / 퍼블릭 IP 자동 할당 **활성화** |
| 방화벽 | **기존 보안 그룹 선택** → `b3-1-web-sg` |
| 스토리지 | 8 GiB gp3 |
| 고급 세부 정보 → 사용자 데이터 | `scripts/user-data.sh` 내용 전체 붙여넣기 |

시작 → 상태 검사 `2/2 통과`까지 2~3분 대기. 퍼블릭 IPv4 주소 복사.

---

## 7. 검증

### 7-1. SSH 접속 (맥 터미널)

```bash
chmod 400 ~/Downloads/b3-1-key.pem
ssh -i ~/Downloads/b3-1-key.pem ubuntu@<퍼블릭IP>
```

### 7-2. 인스턴스 내부 검증

인스턴스 안에서:

```bash
curl -O https://raw.githubusercontent.com/SJendministrator/codysseyB3_1/main/scripts/verify-instance.sh
bash verify-instance.sh
```

(레포가 private이면 위 curl은 404 → `nano verify-instance.sh` 로 파일 만들고 내용 복붙)

기대 결과: nginx `active`, localhost `HTTP 200`, /health `OK`, example.com `HTTP 200`
📸 **스크린샷**: 이 출력 전체

user-data가 안 돌았으면: `sudo cat /var/log/user-data.log` 로 원인 확인

### 7-3. 외부 접속 (맥에서, SSH 말고 새 터미널 탭)

```bash
curl -i http://<퍼블릭IP>/health
# 또는
bash scripts/verify-external.sh <퍼블릭IP>
```

브라우저로 `http://<퍼블릭IP>` 도 열어보기 (Hello Cloud 페이지).
📸 **스크린샷**: curl 결과 + 브라우저 화면

> ⚠️ 브라우저가 자꾸 `https://`로 바꾸면 안 열린다(443은 안 열었으니까). 주소창에 `http://` 를 직접 쳐야 함.

### 7-4. README 채우기

`README.md` 의 `<퍼블릭IP>` 부분을 실제 IP로 바꾸고 스크린샷을 `screenshots/`에 넣는다.

---

## 8. 정리

`docs/cleanup-checklist.md` 순서대로. **스크린샷 다 찍은 다음에!**

---

## (보너스 2) Docker로 띄우기

Nginx를 컨테이너로 대체하는 버전. 인스턴스 안에서:

```bash
sudo systemctl stop nginx && sudo systemctl disable nginx   # 80 포트 비우기
sudo apt-get install -y docker.io
sudo systemctl enable --now docker

mkdir -p ~/web && cd ~/web
cp /var/www/html/index.html .
cat > default.conf <<'EOF'
server {
    listen 80;
    root /usr/share/nginx/html;
    location = /health { default_type text/plain; return 200 "OK from container\n"; }
    location / { try_files $uri $uri/ =404; }
}
EOF

sudo docker run -d --name web --restart unless-stopped -p 80:80 \
  -v ~/web/index.html:/usr/share/nginx/html/index.html:ro \
  -v ~/web/default.conf:/etc/nginx/conf.d/default.conf:ro \
  nginx:alpine

sudo docker ps
curl -i http://localhost/health
```

📸 `docker ps` (Up 상태) + 외부 `/health` 결과 (응답이 `OK from container`로 바뀐 걸로 컨테이너 응답임을 증명)
