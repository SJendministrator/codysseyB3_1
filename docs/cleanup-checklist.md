# 리소스 정리 체크리스트

- 리전: 서울 `ap-northeast-2`
- 정리 일시: `YYYY-MM-DD HH:MM` (KST)
- 정리 수행 계정: IAM 사용자 `codyssey-b3-1`

## 왜 이 순서인가

AWS 리소스는 서로 의존한다. **의존하는 쪽(자식)부터 지워야** 부모가 지워진다.

```
EC2 ─┬─ EBS 볼륨 (종료 시 자동 삭제되지만 "미사용 볼륨"이 남을 수 있음)
     ├─ ENI / 퍼블릭 IP
     └─ Elastic IP (연결 해제 후에도 Release 안 하면 과금!)
          ↓ 다 비워야
Security Group → Subnet / Route Table → IGW(Detach→Delete) → VPC
```

- VPC를 먼저 지우려 하면 "has dependencies" 에러 → EC2가 아직 살아있다는 뜻
- **과금 위험이 큰 것**: 실행 중인 EC2, 미연결 Elastic IP, 남은 EBS 볼륨, (만들었다면) NAT Gateway·ALB·RDS
- 2024년 2월부터 퍼블릭 IPv4 주소는 사용 중이어도 시간당 과금되므로, EC2를 켜둔 채로 방치하지 않는다

## 체크리스트

| # | 항목 | 방법 | 확인 기준 | 완료 | 증빙 |
|---|---|---|---|---|---|
| 1 | EC2 인스턴스 `b3-1-web` | 인스턴스 상태 → 종료(삭제) | 상태 `Terminated` | ☐ | `screenshots/cleanup-01-ec2.png` |
| 2 | EBS 볼륨 | EC2 → 볼륨 → 필터 `상태: available` | 목록 0개 (남았으면 삭제) | ☐ | `screenshots/cleanup-02-ebs.png` |
| 3 | Elastic IP | EC2 → 탄력적 IP | 목록 0개 (할당했었다면 연결 해제 → **릴리스**) | ☐ / 해당 없음 | |
| 4 | 키 페어 `b3-1-key` | EC2 → 키 페어 → 삭제 | 목록에서 사라짐 (과금은 없지만 정리) | ☐ | |
| 5 | 보안 그룹 `b3-1-web-sg` | EC2 → 보안 그룹 → 삭제 | default SG만 남음 | ☐ | |
| 6 | Internet Gateway `b3-1-igw` | 작업 → **VPC에서 분리** → 삭제 | 목록에서 사라짐 | ☐ | |
| 7 | VPC `b3-1-vpc` | VPC 삭제 (서브넷·라우팅 테이블 함께 삭제됨) | 기본 VPC만 남음 | ☐ | `screenshots/cleanup-03-vpc.png` |
| 8 | Subnet / Route Table | 7번에서 함께 삭제됐는지 확인 | `b3-1-*` 이름 없음 | ☐ | |
| 9 | NAT Gateway | VPC → NAT 게이트웨이 | 만들지 않음 / 0개 | ☐ 해당 없음 | |
| 10 | ELB/ALB | EC2 → 로드 밸런서 | 만들지 않음 / 0개 | ☐ 해당 없음 | |
| 11 | RDS | RDS → 데이터베이스 | 만들지 않음 / 0개 | ☐ 해당 없음 | |
| 12 | (권장) Billing | 결제 및 비용 관리 → 대시보드 | 이번 달 예상 요금 $0.00 / 프리 티어 내 | ☐ | `screenshots/cleanup-04-billing.png` |

> 💡 빠른 최종 확인: 콘솔 상단 검색 → **Tag Editor** → 리전 `ap-northeast-2`, 리소스 유형 `All`, 태그 `Project=codyssey-b3-1` 검색 → **결과 0개**면 깔끔.
> (Billing·Tag Editor는 최소권한 정책에 없는 권한이라, 이 확인만 루트/관리자로 하거나 "해당 없음"으로 남긴다)

## 정리 결과 요약

- 남은 리소스: 없음
- 비고:
