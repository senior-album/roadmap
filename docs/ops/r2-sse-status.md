# Cloudflare R2 SSE 상태 — 백업 버킷 저장 시 암호화

> 연결: [#174](https://github.com/senior-album/roadmap/issues/174) (T-004f) · spec §3 Phase 3 · spec §1 위협 경로 3 (백업 매체 유출)

## 결과 요약

| 항목 | 값 |
|---|---|
| 적용 버킷 | `senior-album-photos-backup` (사진 mirror + postgres dump 동거) |
| Provider | Cloudflare R2 (S3 호환) |
| 저장 시 암호화 | **자동 ON** (Cloudflare default, AES-256-GCM, 사용자 토글 없음) |
| 클라이언트 SSE-C | 미사용 (`mc` 호출에 `--encrypt-key` 없음) |
| 검증 일자 | 2026-05-06 |
| 검증 산출물 | 본 문서 (Cloudflare 공식 docs 인용 + backup yaml grep 결과) |

## 보호 대상 — 백업 데이터 흐름

```
postgres pod (PII)              MinIO (사진 원본)
   └─ pg_dump (T-043)              └─ mc mirror (T-044)
         │                              │
         └──────────────┬───────────────┘
                        ▼
        Cloudflare R2 bucket: senior-album-photos-backup
            ├─ postgres/senior_album_<TS>.dump   (PII envelope-encrypted, T-003)
            └─ <photo paths…>                    (사진 원본)
```

핵심: **PII 평문은 dump 안에 없음** — T-003 envelope encryption 으로 `name_ct`, `birth_date_ct`, `medical_notes_ct` 만 dump 에 들어가고 평문 컬럼은 5b 단계에서 DROP. R2 SSE 는 그 위 2 차 방어선.

## 검증 1 — Cloudflare 공식 docs (default encryption)

출처: <https://developers.cloudflare.com/r2/reference/data-security/> (확인일 2026-05-06)

> "Encryption and decryption are automatic, do not require user configuration to
> enable, and do not impact the effective performance of R2."

> "Objects are encrypted using AES-256, a widely tested, highly performant and
> industry-standard encryption algorithm. R2 uses GCM (Galois/Counter Mode) as
> its preferred mode."

핵심: **운영자가 켜고 끌 수 있는 토글이 아니다**. R2 의 default contract — 모든 객체가 AES-256-GCM 으로 자동 암호화. 따라서 "확인" 의 의미는 "Cloudflare 가 이 default 를 변경하지 않았는지" 점검 (분기 1회 docs 페이지 재확인).

## 검증 2 — 클라이언트 측 SSE-C 미주입 확인

`album-deploy/k8s/postgres-backup.yaml` (T-043) 의 mc 호출:

```
mc pipe "r2/$R2_BUCKET/$KEY"
```

`album-deploy/k8s/minio-backup.yaml` (T-044) 의 mc 호출:

```
mc mirror --overwrite "src/senior-album-photos" "r2/$R2_BUCKET"
```

`mc` 는 `--encrypt-key` / `--enc-c-key` 옵션 없이는 SSE-C 헤더를 보내지 않는다. 두 yaml 어디에도 해당 옵션이 없음 → **R2 측 default (Cloudflare-managed key) 가 적용됨**.

이 의미: 키는 Cloudflare 가 보유. 우리 운영자는 키를 보유하지 않고, 따라서 분실 위험도 없음 (대신 Cloudflare 직원의 권한 escalation 시 잠재 노출은 한계 절에 명시).

## spec §1 위협 경로 3 (백업 매체) 효과

| 항목 | 상태 | 비고 |
|---|---|---|
| R2 디스크 평문 노출 (Cloudflare 인프라 측) | ✅ 차단 | AES-256-GCM 자동 암호화, 사용자 토글 없음 |
| R2 access/secret 유출 시 | ❌ 본 항목 범위 밖 | SealedSecret + Cloudflare API token 회전으로 대응 (별도 운영 항목) |
| 한국 → 미국 국외 이전 (개인정보보호법) | ❌ 본 항목 범위 밖 | T-022 / T-023 (약관 고지 / DPA) 영역 |
| dump 안 PII 평문 | ✅ T-003 으로 별도 차단 | `*_ct` 만 dump 에 포함, 평문 컬럼 DROP 완료 |

## 한계

- **Cloudflare-managed key**: 운영자가 키를 보유하지 않음. Cloudflare 측 권한
  escalation 시 잠재 노출 가능. 더 강한 보장이 필요하면 SSE-C 로 전환 — 단 키
  분실 시 백업 영구 손실 위험 동반. 현 단계에서는 채택 안 함 (운영 인력 1명,
  키 분실 위험 > Cloudflare 내부자 위험).
- **검증의 한계**: R2 는 `GetBucketEncryption` S3 API 의 정식 지원이 명시돼
  있지 않다. 따라서 "런타임에 SSE 가 켜져 있는지" 를 API 로 확인할 표준 경로가
  없음. 본 문서의 검증은 **Cloudflare default contract 신뢰** + **클라이언트
  코드 grep** 두 축에 의존.
- **R2 default 변경 가능성**: docs 페이지의 default 정책이 향후 변경될 수
  있음. 점검 체크리스트에서 분기 1회 재확인.

## 점검 체크리스트

분기 1회:

- [ ] <https://developers.cloudflare.com/r2/reference/data-security/> 페이지에서
      "Encryption and decryption are automatic" 문구 유지 확인
- [ ] `album-deploy/k8s/postgres-backup.yaml`, `minio-backup.yaml` 에
      `--encrypt-key` / `--enc-c-key` 등 SSE-C 옵션이 추가되지 않았는지 grep
- [ ] R2 access/secret SealedSecret 마지막 회전 일자 확인 (별도 운영 항목)

## 후속 작업

T-004f scope 종료. T-004 잔여 서브이슈:

- [#170](https://github.com/senior-album/roadmap/issues/170) **T-004b**: OpenSearch Security 플러그인 + TLS — 위협 경로 1
- **T-004c**: backend `opensearch_service.py` SSL/auth + SealedSecret (b 와 한 PR 묶음 권장 — 평문 ↔ TLS 전환 사이 backend 다운 회피)
- **T-004d**: 기존 인덱스 smoke test (b+c PR 의 acceptance 단계로 흡수)
- **T-004e**: `hashed_resident_id` HMAC + reindex + `opensearch_link_key` SealedSecret
