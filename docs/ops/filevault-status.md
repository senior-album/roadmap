# FileVault 상태 — 맥미니 운영 호스트

> 연결: [#169](https://github.com/senior-album/roadmap/issues/169) (T-004a) · spec §3 Phase 1 · spec §1 위협 경로 2 (물리 탈취)

## 결과 요약

| 항목 | 값 |
|---|---|
| 적용 머신 | Mac mini, Apple Silicon (M4) |
| FileVault | **ON** (2026-04-27 적용) |
| Personal Recovery Key | 발급 완료, 운영자 본인 password manager 에 보관 |
| 재부팅 검증 (잠금화면 → 비번 → unlock) | 다음 정기 점검 시 graceful stop 후 검증 예정 |

## 보호 대상 — 데이터가 사는 경로

```
macOS boot disk (APFS)                            ← FileVault 보호 경계
   └─ ~/.colima/_lima/{profile}/diffdisk          (colima VM 디스크 이미지)
        └─ Linux VM (lima)
             └─ /var/lib/docker/volumes/<id>/_data
                  └─ k3d-senior-album-server-0:/var/lib/rancher/k3s
                       └─ /var/lib/rancher/k3s/storage/pvc-<uuid>_senior-album_<name>
                            └─ k8s PV (애플리케이션 데이터)
```

핵심: **모든 PV 데이터는 macOS 사용자 홈 (`~`) 아래 colima VM 디스크 이미지 안에 저장**. boot disk = FileVault 보호 대상이므로 ON 상태에서 디스크 평문 노출 차단.

> 운영자가 본인 환경의 정확한 colima 디스크 경로 확인: `colima list` 또는 `ls -lah ~/.colima/_lima/*/diffdisk`.

## PVC 목록 (보호 대상)

| PVC | 용도 | 크기 | spec §1 의미 |
|---|---|---|---|
| `opensearch-pvc` | 얼굴 임베딩 인덱스 (T-004 핵심) | 5Gi | §1 "얼굴 → 신원 식별" 차단 |
| `postgres-pvc` | PII 포함 RDB | 5Gi | §1 PII 평문 노출 차단 |
| `minio-pvc` | 사진 원본 | 10Gi | §1 사진 원본 노출 차단 |
| `loki-pvc` | 운영 로그 | 5Gi | 로그에 식별자 잔여 시 차단 |
| `grafana-pvc` | 대시보드 | 1Gi | (대시보드 설정만) |
| `uptime-kuma-pvc` | 헬스 모니터링 | 1Gi | (모니터 설정만) |

StorageClass: `local-path` (rancher.io/local-path, default).

## spec §1 위협 모델 효과

| 위협 경로 | 커버 여부 | 비고 |
|---|---|---|
| (1) 네트워크 침투 | ❌ | T-004b (OpenSearch Security 플러그인 + TLS) 영역 |
| **(2) 물리 탈취** | ✅ **a 로 차단** | 비번/recovery key 없이 디스크 unlock 불가 |
| (3) 백업 매체 (R2 등) | ❌ | T-004f (R2 SSE 확인) 영역 |
| (4) 메모리 덤프 (운영 중) | ❌ | 운영 중에는 SEP 가 키 unlock 상태 — 별도 통제 영역 |

## 한계

- **M-시리즈 FileVault 의 본질은 SEP 키에 사용자 비번 봉인 추가**. 사용자 비번이 약하면 brute force 에 취약 → 강한 비번 유지 전제.
- **recovery key 분실 + 비번 분실 = 데이터 영구 손실**. 두 경로 중 하나는 항상 회수 가능 상태로 유지.
- FileVault 는 **운영 중 메모리 보호와 무관**. Pod 메모리 덤프, 코어 덤프 등은 별도 통제.

## 재부팅 시 절차 (OpenSearch 인덱스 손상 방지)

이후 어떤 이유로든 호스트 재부팅이 필요할 때:

```bash
k3d cluster stop senior-album   # pod graceful shutdown
colima stop                     # VM sync + 정지
sudo shutdown -r now
# 부팅 후
colima start && k3d cluster start senior-album
kubectl -n senior-album get pods   # 전부 Running 확인
```

OpenSearch 가 정상 graceful 종료되지 않으면 인덱스 segments 손상 → 재시작 시 자동 복구 시도하지만 시간 지연 발생.

## 점검 체크리스트

분기 1회:

- [ ] `fdesetup status` → "FileVault is On." 유지 확인
- [ ] `sudo fdesetup haspersonalrecoverykey` → `true` 유지 확인
- [ ] recovery key 매체 접근 가능성 확인 (운영자 본인)

## 후속 작업

- [#170](https://github.com/senior-album/roadmap/issues/170) (T-004b): OpenSearch Security 플러그인 + TLS — 위협 경로 1
- [#174](https://github.com/senior-album/roadmap/issues/174) (T-004f): R2 SSE 확인 — 위협 경로 3
