# 트러블슈팅 보고서

> 실습 중 **실제로 겪은 오류**를 우선 기록한다. 겪은 게 없으면 아래 "의도적 재현" 방식으로 직접 장애를 만들고 → 원인 찾고 → 고친다.
> `[ ]` 로 표시된 곳은 실제 실행 결과·로그로 채운다.

## 진단 원칙: 바깥에서 안쪽으로

외부 요청이 Nginx까지 가는 경로를 한 칸씩 의심한다.

```
내 PC → 인터넷 → IGW → Route Table → Subnet → Security Group → EC2(OS) → Nginx(:80)
```

| 증상 | 의심 구간 | 빠른 확인 |
|---|---|---|
| `curl` **timeout** (응답 자체가 없음) | 라우팅 / SG / 퍼블릭 IP | SG 인바운드, 라우트 `0.0.0.0/0 → igw`, 인스턴스에 퍼블릭 IP 있는지 |
| `Connection refused` (즉시 거절) | 패킷은 도착, 80에서 듣는 프로세스 없음 | `systemctl status nginx`, `ss -tlnp` |
| `404` / `502` | 네트워크 정상, 웹 서버 설정 문제 | `nginx -t`, `/var/log/nginx/error.log` |
| SSH만 안 됨, HTTP는 됨 | SG 22번 소스 IP | 내 현재 IP(`curl ifconfig.me`) vs SG 소스 |

> **timeout vs refused 구분이 핵심.** SG는 막을 때 응답 없이 버리므로(drop) timeout, OS까지 왔는데 포트가 닫혀 있으면 RST가 와서 refused.

---

## 사례 1. 외부에서 웹 접속 timeout — 라우팅 테이블에 IGW 경로 누락

| 항목 | 내용 |
|---|---|
| **증상** | 맥에서 `curl http://<퍼블릭IP>/health` 가 응답 없이 timeout. 인스턴스 안에서 `curl https://example.com` 도 timeout. SSH도 접속 불가. |
| **원인 가설** | ① SG가 80을 막고 있다 ② 서브넷이 IGW로 가는 경로가 없다 ③ Nginx가 죽었다 → SSH까지 같이 죽었고 **아웃바운드도 안 됨** = 인스턴스 하나가 아니라 서브넷 전체의 인터넷 출입이 끊김 → ②가 가장 유력 |
| **검증 방법** | 1) SG 인바운드 확인: 80(0.0.0.0/0), 22(내 IP) 정상 → ① 기각<br>2) VPC → 라우팅 테이블 → 서브넷에 연결된 테이블의 라우팅 탭 확인: `10.0.0.0/16 local` 한 줄만 있고 `0.0.0.0/0` 없음 → ② 확인<br>3) (SSH 불가하므로) EC2 → 작업 → 모니터링 → **시스템 로그 가져오기**로 user-data 실행 결과 확인: `[ ]` |
| **조치 내용** | 라우팅 편집 → `0.0.0.0/0 → igw-xxxx` 추가 |
| **결과** | `curl -i http://<퍼블릭IP>/health` → `HTTP/1.1 200 OK` / `OK`. SSH 접속 성공. `[스크린샷: screenshots/ts-01-after.png]` |
| **재발 방지** | 배포 전 체크리스트에 "퍼블릭 서브넷 라우팅 테이블에 `0.0.0.0/0 → igw` 존재 + 서브넷 명시적 연결" 추가. VPC를 "VPC만"으로 만들면 라우트가 자동으로 안 생긴다는 점을 README에 기록. |

**재현 방법 (의도적으로 만들기)**: 정상 동작 확인 후 → 라우팅 테이블에서 `0.0.0.0/0` 경로 삭제 → 맥에서 `curl --max-time 5 http://<IP>/health` → timeout 확인 `[스크린샷: ts-01-before.png]` → 경로 다시 추가 → 정상 확인

---

## 사례 2. (선택) Connection refused — Nginx 중지

| 항목 | 내용 |
|---|---|
| **증상** | 외부 `curl http://<IP>/health` → `curl: (7) Failed to connect ... Connection refused` (timeout이 아니라 즉시 실패) |
| **원인 가설** | 즉시 거절 = 패킷이 SG·라우팅을 통과해 OS까지 왔다 → 네트워크 문제 아님. 80 포트를 듣는 프로세스가 없다. |
| **검증 방법** | SSH 접속 → `systemctl is-active nginx` → `[ ]`<br>`sudo ss -tlnp \| grep :80` → `[ ]` (출력 없음)<br>`sudo journalctl -u nginx -n 20` → `[ ]` |
| **조치 내용** | `sudo systemctl start nginx` (원인이 설정 오류라면 `sudo nginx -t` 로 문법 오류 위치 확인 후 수정) |
| **결과** | `[ ]` |
| **재발 방지** | `systemctl enable nginx` 로 재부팅 시 자동 기동 보장. 설정 변경 후엔 반드시 `nginx -t` → `reload` 순서. |

**재현 방법**: `sudo systemctl stop nginx` → 외부에서 curl → refused 확인 → start

---

## 사례 3. (실제 발생 시 기록) `[ ]`

| 항목 | 내용 |
|---|---|
| **증상** | |
| **원인 가설** | |
| **검증 방법** | |
| **조치 내용** | |
| **결과** | |
| **재발 방지** | |

<!-- 실제로 잘 터지는 것들: SSH timeout(와이파이 바뀌어 내 IP 변경), "UnauthorizedOperation"(최소권한 정책에 없는 액션 — 에러 메시지의 Action 이름을 보고 정책에 추가), 퍼블릭 IP 미할당(서브넷 자동 할당 off), 브라우저가 https로 자동 전환 -->
