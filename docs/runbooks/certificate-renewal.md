# 인증서 만료 대응 런북

**대상**: senior-album 이 사용하는 TLS 인증서 전반
**관련**: T-045
**예상 소요**: 인증서 종류별로 5분 ~ 1시간

---

## 0. 인증서 인벤토리 (현 시점)

| 대상                        | 발급 주체                 | 위치                                | 만료 주기 | 운영 개입 |
|-----------------------------|---------------------------|-------------------------------------|-----------|-----------|
| 외부 도메인 (thekim123.info) | Cloudflare                | Cloudflare edge                     | 자동 회전 | 無 (Cloudflare 가 관리) |
| Cloudflare Tunnel credential | Cloudflare Zero Trust     | `cloudflared-token` SealedSecret    | 영구      | 재발급은 수동 |
| Kakao OAuth                 | 카카오 서버 측 TLS        | 외부                                | 해당 없음 | 無 |
| SealedSecrets controller 키 | 클러스터 내 자체 생성     | `sealed-secrets-controller` secret  | 30~90일 (자동 갱신) | 주기 확인 |
| OpenSearch Security (T-004 이후) | self-signed 내부 CA  | SealedSecret                        | 365일 (설정) | 수동 갱신 |
| Redis / Postgres / MinIO TLS | 비활성 (클러스터 내 plain) | -                              | 해당 없음 | 현재 범위 外 |

**지금 현재 수동 갱신 대상은 사실상 OpenSearch (T-004 활성화 후) 만. 나머지는 자동 or 사용하지 않음.**

---

## 1. 외부 도메인 (Cloudflare 관리)

Cloudflare 가 Universal SSL / Let's Encrypt 를 자동 회전. **맥미니 쪽 조치 불필요.**

점검:
```bash
curl -vI https://thekim123.info/ 2>&1 | grep -iE "expire|subject|issuer"
# 또는 브라우저에서 자물쇠 클릭
```

만약 만료된 것으로 보이면:
- Cloudflare 대시보드 → SSL/TLS → Edge Certificates 에서 상태 확인
- 만료 상태면 "재발급" 또는 SSL/TLS 모드 (Full/Strict) 재확인

---

## 2. Cloudflare Tunnel (cloudflared token)

Tunnel credential 은 장기 유효 (명시적 revoke 전까지). 회전 사유:
- 노출 의심
- 정기 로테이션 정책 (선택)

### 재발급 절차

```bash
# 1) Cloudflare Zero Trust 대시보드 → Access → Tunnels
# 2) senior-album 터널 → "Configure" → Credentials → "Regenerate token"
# 3) 새 token 복사 (이 시점부터 구 token 은 48시간 내 만료)

# 4) SealedSecret 갱신
NEW_TOKEN="<from dashboard>"
cd ~/workspace/senior-album/album-deploy
kubectl -n senior-album create secret generic cloudflared-token \
  --from-literal=token="${NEW_TOKEN}" \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system --format yaml \
           > k8s/sealed/cloudflared-token.yaml

git add k8s/sealed/cloudflared-token.yaml
git commit -m "ops: rotate cloudflared tunnel token"
git push

# 5) 적용 + 재시작
kubectl apply -f k8s/sealed/cloudflared-token.yaml
kubectl -n senior-album rollout restart deploy/cloudflared

# 6) 검증 — tunnel 로그
kubectl -n senior-album logs deploy/cloudflared --tail=30
# → "Registered tunnel connection" 재확인

unset NEW_TOKEN
```

---

## 3. SealedSecrets Controller Key (자동 회전)

- Controller 는 자체 RSA 키쌍을 보유. 기본 30일마다 새 키를 추가 (구 키 보관 → decrypt 가능).
- 운영 개입 불필요. 단 **controller pod / secret 소실 시 모든 SealedSecret 이 복호화 불가** → 키 export 백업 필요.

### 키 백업 (정기)

```bash
# 모든 활성 키 export
kubectl -n kube-system get secret -l sealedsecrets.bitnami.com/sealed-secrets-key \
  -o yaml > /path/to/secure/storage/sealed-secrets-keys-$(date +%Y%m%d).yaml

# 권한 제한
chmod 600 /path/to/secure/storage/sealed-secrets-keys-*.yaml
```

### 키 손실 복구

- 백업이 있으면: `kubectl apply -f <backup>.yaml` 후 controller 재시작
- 백업이 없으면: **SealedSecret 전부 재생성 필요** (구 암호문 전부 폐기, 값 재입력 + 재봉인)

---

## 4. OpenSearch Security 인증서 (T-004 활성화 후)

T-004 구현 후 이 섹션 구체화. 개략:

- self-signed CA → admin/node/client cert 발급 (유효기간 365일)
- 만료 1주 전 알림 체계 필요 (현재 알림 없음, T-041 Telegram 봇 이후 고려)
- 갱신 = 새 cert 발급 → SealedSecret 갱신 → OpenSearch rolling restart → backend rollout

### 만료 임박 시

```bash
# 만료일 확인
kubectl -n senior-album get secret opensearch-certs -o jsonpath='{.data.node\.pem}' | \
  base64 -d | openssl x509 -noout -enddate
```

상세 절차는 T-004 구현 후 append.

---

## 5. 인증서 모니터링 (선결 이슈)

현재 인증서 만료를 사전 감지하는 수단 없음. 개선 후보:

- **T-040 Uptime Kuma**: HTTP(S) 모니터로 endpoint cert 만료일 감시 가능
- **cron + openssl**: 자체 스크립트로 SealedSecret 내 cert 파싱 후 Slack/Telegram 통보

이 런북이 "만료 후 대응" 위주인 이유는 현재 "만료 전 감지" 가 없기 때문. T-040 완료되면 이 런북 §5 를 감지 기반 예방 절차로 업데이트.

---

## 6. 완료 처리

- [ ] 교체 대상 인증서 endpoint 정상 (external curl + internal health)
- [ ] 다음 만료일 캘린더 등록 (자동 회전 아닌 경우)
- [ ] SealedSecret 백업 (controller key 포함) 최신화
- [ ] 모니터링 대시보드에 새 만료일 반영 (Uptime Kuma 도입 후)
